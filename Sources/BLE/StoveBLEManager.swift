@preconcurrency import CoreBluetooth
import Foundation

enum StoveBLEError: LocalizedError {
    case bluetoothUnavailable
    case notFound
    case notConnected
    case timeout
    case unexpectedResponse
    case writeFailed(String)
    /// The stove answered with a Modbus exception (function byte's high bit set):
    /// it understood the command but rejected it. `code` is the exception code byte.
    case modbusException(UInt8)

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: "Bluetooth indisponible ou désactivé."
        case .notFound: "Poêle introuvable à proximité (nom Bluetooth attendu : EDILKAMIN_EP)."
        case .notConnected: "Non connecté au poêle."
        case .timeout: "Le poêle n'a pas répondu à temps."
        case .unexpectedResponse: "Réponse du poêle illisible."
        case .writeFailed(let reason): "Échec de l'envoi au poêle : \(reason)"
        case .modbusException(let code):
            "Le poêle a refusé la commande (code d'erreur Modbus \(code))."
        }
    }
}

/// CoreBluetooth client for the stove's local control service.
///
/// Service/characteristic UUIDs (0xABF0 service, 0xABF1 write, 0xABF2 notify) and the
/// device's advertised name "EDILKAMIN_EP" are documented publicly by
/// https://github.com/netmb/Edilkamin_BT — see EdilkaminFrame.swift for the source note
/// on the framing/crypto this builds on.
@MainActor
@Observable
final class StoveBLEManager: NSObject {
    enum ConnectionState: Equatable {
        case idle, scanning, connecting, ready, disconnected
        case failed(String)
    }

    // Not MainActor-isolated: CBCentralManagerDelegate/CBPeripheralDelegate callbacks
    // arrive off the main actor, so these constants must stay reachable from there.
    private enum BLE {
        // CBUUID isn't Sendable, but these are created once and never mutated.
        nonisolated(unsafe) static let serviceUUID = CBUUID(string: "ABF0")
        nonisolated(unsafe) static let writeCharUUID = CBUUID(string: "ABF1")
        nonisolated(unsafe) static let notifyCharUUID = CBUUID(string: "ABF2")
        static let advertisedName = "EDILKAMIN_EP"
    }

    private(set) var state: ConnectionState = .idle
    /// Hex dump of recent command/response pairs, most recent first, for on-device
    /// troubleshooting — a single command can trigger several reads (e.g. a
    /// read-modify-write, or the status refresh that follows it), so this keeps a short
    /// history rather than just the very last exchange, which could be unrelated to the
    /// command you actually care about.
    private(set) var exchangeLog: [String] = []
    private static let exchangeLogLimit = 8

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var pendingContinuation: CheckedContinuation<[UInt8], Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    /// Scans for the stove, connects, discovers the service and enables notifications.
    func connect() async throws {
        guard central.state == .poweredOn else { throw StoveBLEError.bluetoothUnavailable }
        state = .scanning
        central.scanForPeripherals(withServices: [Self.BLE.serviceUUID])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                guard let pending = self.connectContinuation else { return }
                self.connectContinuation = nil
                pending.resume(throwing: StoveBLEError.notFound)
            }
        }
    }

    func disconnect() {
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        state = .disconnected
    }

    /// Sends a 6-byte Modbus command and awaits the decrypted, CRC-checked response.
    /// Throws `.modbusException` if the stove understood but rejected the command.
    @discardableResult
    private func send(_ command: EdilkaminRegisters.Command) async throws -> [UInt8] {
        guard state == .ready, let peripheral, let writeChar else { throw StoveBLEError.notConnected }
        let payload = try EdilkaminFrame.encryptedCommand(command.bytes)
        let response: [UInt8]
        do {
            response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[UInt8], Error>) in
                self.pendingContinuation = continuation
                // The official app writes with WRITE_TYPE_NO_RESPONSE (Android), not
                // "write with response" — the characteristic rejects the latter with
                // ATT error "Write Not Permitted".
                peripheral.writeValue(payload, for: writeChar, type: .withoutResponse)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(10))
                    guard let pending = self.pendingContinuation else { return }
                    self.pendingContinuation = nil
                    pending.resume(throwing: StoveBLEError.timeout)
                }
            }
        } catch {
            logExchange("→ \(Self.hex(command.bytes))\n✗ \(error.localizedDescription)")
            throw error
        }
        // A Modbus exception echoes the function byte with its high bit set.
        if response.count >= 3, response[1] & 0x80 != 0 {
            let exception = StoveBLEError.modbusException(response[2])
            logExchange("→ \(Self.hex(command.bytes))\n← \(Self.hex(response))\n✗ \(exception.localizedDescription)")
            throw exception
        }
        logExchange("→ \(Self.hex(command.bytes))\n← \(Self.hex(response))")
        return response
    }

    private func logExchange(_ entry: String) {
        exchangeLog.insert(entry, at: 0)
        if exchangeLog.count > Self.exchangeLogLimit { exchangeLog.removeLast() }
    }

    private func readRegister(_ command: EdilkaminRegisters.Command) async throws -> UInt16 {
        let response = try await send(command)
        guard let value = EdilkaminRegisters.firstRegisterValue(fromReadResponse: response) else {
            throw StoveBLEError.unexpectedResponse
        }
        return value
    }

    private func readDataBytes(_ command: EdilkaminRegisters.Command) async throws -> [UInt8] {
        let response = try await send(command)
        guard let data = EdilkaminRegisters.dataBytes(fromReadResponse: response) else {
            throw StoveBLEError.unexpectedResponse
        }
        return data
    }

    // MARK: - Public stove operations

    func readState() async throws -> StoveState {
        let onOff = try await readRegister(EdilkaminRegisters.readOnOffRegister)
        let ambient = try await readRegister(EdilkaminRegisters.readMainAmbientTemperature)
        let target = try await readRegister(EdilkaminRegisters.readTargetTemperature)
        let power = try await readRegister(EdilkaminRegisters.readPowerLevel)
        let automatic = try await readRegister(EdilkaminRegisters.readAutomaticMode)
        let relax = try await readRegister(EdilkaminRegisters.readRelaxMode)
        let chronoOnOff = try await readRegister(EdilkaminRegisters.readChronoOnOff)
        let chronoEconomy = try await readRegister(EdilkaminRegisters.readChronoEconomyPreset)
        let chronoComfort = try await readRegister(EdilkaminRegisters.readChronoComfortPreset)
        let operatingState = try await readRegister(EdilkaminRegisters.readOperatingState)
        let alarm = try await readRegister(EdilkaminRegisters.readAlarmCode)
        let warnings = try await readDataBytes(EdilkaminRegisters.readWarningFlags)
        let fanConfig = EdilkaminRegisters.FanConfiguration(
            rawLowByte: UInt8((try await readRegister(EdilkaminRegisters.readFanConfiguration)) & 0xFF)
        )
        var fan2: Int?
        var fan3: Int?
        if fanConfig.hasFan2 || fanConfig.hasFan3 {
            let fan23 = try await readRegister(EdilkaminRegisters.readFan23)
            if fanConfig.hasFan2 { fan2 = Int(fan23 & 0x00FF) }
            if fanConfig.hasFan3 { fan3 = Int(fan23 >> 8) }
        }
        // Both temperatures are stored as tenths of a degree (confirmed: writing the
        // target as 185 reads back as the stove's real 18.5 °C setpoint). Pellet reserve
        // is bit 2 of the second warning data byte (community-documented, not personally
        // hardware-verified — cross-check against the stove's own reserve indicator).
        return StoveState(
            isOn: onOff & 0x0001 != 0,
            ambient: Double(ambient) / 10,
            target: Double(target) / 10,
            powerLevel: Int(power & 0x00FF),
            automaticMode: automatic != 0x0001,
            relaxMode: relax != 0,
            fan1Speed: Int(power >> 8),
            fan2Speed: fan2,
            fan3Speed: fan3,
            pelletReserve: warnings.count >= 2 && (warnings[1] >> 2) & 1 != 0,
            isChronoOn: chronoOnOff & 0x0001 != 0,
            chronoEconomyPreset: Int(chronoEconomy),
            chronoComfortPreset: Int(chronoComfort),
            operatingState: operatingState,
            alarmCode: UInt8(alarm >> 8)
        )
    }

    func setPower(on: Bool) async throws {
        let current = try await readRegister(EdilkaminRegisters.readOnOffRegister)
        try await send(EdilkaminRegisters.writeOnOffRegister(preservingOtherBitsAs: current, on: on))
    }

    func setTargetTemperature(celsius: Double) async throws {
        try await send(EdilkaminRegisters.writeTargetTemperature(celsius: celsius))
    }

    /// A manual power level write is documented as only taking effect when the stove's
    /// own "Automatic" mode is off (register 0x0523 == 0x0001 confirms it's off). If
    /// it isn't, the stove likely keeps managing power itself regardless of this write —
    /// switch the stove to manual mode on its own panel/display first.
    func setPowerLevel(_ level: Int) async throws {
        try await requireManualMode()
        let current = try await readRegister(EdilkaminRegisters.readPowerLevel)
        try await send(EdilkaminRegisters.writePowerLevel(level, preservingFanByteOf: current))
    }

    func setFan1Speed(_ speed: Int) async throws {
        try await requireManualMode()
        let current = try await readRegister(EdilkaminRegisters.readPowerLevel)
        try await send(EdilkaminRegisters.writeFan1Speed(speed, preservingPowerByteOf: current))
    }

    func setFan2Speed(_ speed: Int) async throws {
        try await requireManualMode()
        let current = try await readRegister(EdilkaminRegisters.readFan23)
        try await send(EdilkaminRegisters.writeFan2Speed(speed, preservingFan3ByteOf: current))
    }

    func setFan3Speed(_ speed: Int) async throws {
        try await requireManualMode()
        let current = try await readRegister(EdilkaminRegisters.readFan23)
        try await send(EdilkaminRegisters.writeFan3Speed(speed, preservingFan2ByteOf: current))
    }

    private func requireManualMode() async throws {
        let automatic = try await readRegister(EdilkaminRegisters.readAutomaticMode)
        guard automatic == 0x0001 else {
            throw StoveBLEError.writeFailed(
                "le poêle est en mode automatique : passez-le en mode manuel sur son propre écran avant de régler la puissance ou les ventilateurs."
            )
        }
        let relax = try await readRegister(EdilkaminRegisters.readRelaxMode)
        guard relax == 0 else {
            throw StoveBLEError.writeFailed(
                "le mode Relax est actif : désactivez-le avant de régler la puissance ou les ventilateurs."
            )
        }
    }

    /// Switches the stove between automatic and manual power management. The
    /// "automatic" direction is a best-effort guess — see `EdilkaminRegisters.writeAutomaticMode`.
    func setAutomaticMode(on: Bool) async throws {
        try await send(EdilkaminRegisters.writeAutomaticMode(on: on))
    }

    /// "Relax" (quiet/night) mode: lowers fan noise. Blocks manual power/fan writes
    /// while active (see `requireManualMode`).
    func setRelaxMode(on: Bool) async throws {
        try await send(EdilkaminRegisters.writeRelaxMode(on: on))
    }

    /// Switches the Chrono (weekly schedule) feature on or off.
    func setChronoOn(_ on: Bool) async throws {
        let current = try await readRegister(EdilkaminRegisters.readChronoOnOff)
        try await send(EdilkaminRegisters.writeChronoOnOff(preservingOtherBitsAs: current, on: on))
    }

    /// Sets the Chrono "Économie" preset temperature — see
    /// `EdilkaminRegisters.writeChronoEconomyPreset` for the unverified encoding
    /// assumption.
    func setChronoEconomyPreset(celsius: Int) async throws {
        try await send(EdilkaminRegisters.writeChronoEconomyPreset(celsius: celsius))
    }

    /// Sets the Chrono "Confort" preset temperature — see
    /// `EdilkaminRegisters.writeChronoComfortPreset` for the unverified encoding
    /// assumption.
    func setChronoComfortPreset(celsius: Int) async throws {
        try await send(EdilkaminRegisters.writeChronoComfortPreset(celsius: celsius))
    }

    /// Reads the full Chrono weekly schedule grid — see
    /// `EdilkaminRegisters.chronoScheduleRegister` for the unconfirmed choice between
    /// the two stored programs, and `ChronoSchedule.decoded(fromPayload:)` for the
    /// (unverified) byte layout.
    func readChronoSchedule() async throws -> ChronoSchedule {
        let data = try await readDataBytes(EdilkaminRegisters.readChronoSchedule)
        guard data.count == ChronoSchedule.payloadByteCount else { throw StoveBLEError.unexpectedResponse }
        return ChronoSchedule.decoded(fromPayload: data)
    }

    /// Writes the full Chrono weekly schedule grid — see `readChronoSchedule` for the
    /// program A/B caveat, and `ChronoSchedule.encoded()` for the (unverified) byte
    /// layout.
    func setChronoSchedule(_ schedule: ChronoSchedule) async throws {
        try await send(EdilkaminRegisters.writeChronoSchedule(payload: schedule.encoded()))
    }

    /// Acknowledges the current alarm, following the documented preconditions: the stove
    /// must actually be reporting an alarm (operating state 7), and must be off — it
    /// otherwise rejects the reset while the power bit is set.
    func acknowledgeAlarm() async throws {
        let operatingState = try await readRegister(EdilkaminRegisters.readOperatingState)
        guard operatingState == 7 else {
            throw StoveBLEError.writeFailed("aucune alarme active à acquitter.")
        }
        let current = try await readRegister(EdilkaminRegisters.readOnOffRegister)
        guard current & 0x0001 == 0 else {
            throw StoveBLEError.writeFailed("éteignez le poêle avant d'acquitter l'alarme.")
        }
        try await send(EdilkaminRegisters.writeAlarmReset(preservingOtherBitsAs: current))
    }
}

extension StoveBLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state != .poweredOn, self.state == .scanning {
                self.state = .failed("Bluetooth désactivé.")
                self.connectContinuation?.resume(throwing: StoveBLEError.bluetoothUnavailable)
                self.connectContinuation = nil
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard name == Self.BLE.advertisedName else { return }
        Task { @MainActor in
            central.stopScan()
            self.peripheral = peripheral
            self.state = .connecting
            peripheral.delegate = self
            central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.BLE.serviceUUID])
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        Task { @MainActor in
            self.state = .failed(error?.localizedDescription ?? "Connexion échouée.")
            self.connectContinuation?.resume(throwing: error ?? StoveBLEError.notFound)
            self.connectContinuation = nil
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        Task { @MainActor in
            self.state = .disconnected
            self.pendingContinuation?.resume(throwing: StoveBLEError.notConnected)
            self.pendingContinuation = nil
        }
    }
}

extension StoveBLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.BLE.serviceUUID }) else {
            Task { @MainActor in
                self.state = .failed("Service Bluetooth du poêle introuvable.")
                self.connectContinuation?.resume(throwing: StoveBLEError.notFound)
                self.connectContinuation = nil
            }
            return
        }
        peripheral.discoverCharacteristics([Self.BLE.writeCharUUID, Self.BLE.notifyCharUUID], for: service)
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        Task { @MainActor in
            self.writeChar = characteristics.first { $0.uuid == Self.BLE.writeCharUUID }
            self.notifyChar = characteristics.first { $0.uuid == Self.BLE.notifyCharUUID }
            guard let notifyChar = self.notifyChar, self.writeChar != nil else {
                self.state = .failed("Caractéristiques Bluetooth du poêle introuvables.")
                self.connectContinuation?.resume(throwing: StoveBLEError.notFound)
                self.connectContinuation = nil
                return
            }
            peripheral.setNotifyValue(true, for: notifyChar)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard characteristic.uuid == Self.BLE.notifyCharUUID else { return }
        Task { @MainActor in
            if let error {
                self.state = .failed("Impossible d'activer les notifications Bluetooth : \(error.localizedDescription)")
                self.connectContinuation?.resume(throwing: error)
            } else {
                self.state = .ready
                self.connectContinuation?.resume()
            }
            self.connectContinuation = nil
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard characteristic.uuid == Self.BLE.writeCharUUID, let error else { return }
        Task { @MainActor in
            guard let pending = self.pendingContinuation else { return }
            self.pendingContinuation = nil
            pending.resume(throwing: StoveBLEError.writeFailed(error.localizedDescription))
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard characteristic.uuid == Self.BLE.notifyCharUUID else { return }
        Task { @MainActor in
            guard let continuation = self.pendingContinuation else { return }
            self.pendingContinuation = nil
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let data = characteristic.value else {
                continuation.resume(throwing: StoveBLEError.unexpectedResponse)
                return
            }
            do {
                continuation.resume(returning: try EdilkaminFrame.decodeResponse(data))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
