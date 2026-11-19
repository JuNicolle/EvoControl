import Foundation

/// Modbus register map for the stove's local BLE control, as documented by the
/// open-source project https://github.com/netmb/Edilkamin_BT (see EdilkaminFrame.swift).
///
/// Register *addresses* below are well established (read commands are unambiguous:
/// address, function 3 "read holding registers", register, count). The *value
/// encoding* of some write commands is flagged "uncertain" where noted — verify
/// empirically: set, then re-read the register and compare, before trusting it blindly.
enum EdilkaminRegisters {
    /// A 6-byte Modbus-RTU command, CRC appended later by `EdilkaminFrame`.
    struct Command {
        let bytes: [UInt8]
        init(function: UInt8, register: UInt16, valueOrCount: UInt16, address: UInt8 = 1) {
            bytes = [
                address, function,
                UInt8(register >> 8), UInt8(register & 0xFF),
                UInt8(valueOrCount >> 8), UInt8(valueOrCount & 0xFF),
            ]
        }
    }

    private static func read(_ register: UInt16, count: UInt16 = 1) -> Command {
        Command(function: 3, register: register, valueOrCount: count)
    }

    private static func write(_ register: UInt16, value: UInt16) -> Command {
        Command(function: 6, register: register, valueOrCount: value)
    }

    // MARK: - Reads (unambiguous)

    static let readOnOffRegister = read(0x031C)  // bit 0 = power state, bit 1 = alarm reset; preserve the rest
    static let readMainAmbientTemperature = read(0x02E9)  // measured room temperature, tenths of °C
    static let readTargetTemperature = read(0x0525)  // target / setpoint register, tenths of °C
    /// Packed register: high byte = Fan 1 speed (1–5, 6 = Auto), low byte = manual power
    /// level (1–5). Confirmed on a real stove: writing 0x0003 read back as 0x0603 (fan
    /// byte unrelated to what we sent, power byte exactly as written).
    static let readPowerLevel = read(0x0529)
    static let readAutomaticMode = read(0x0523)  // 0x0001 = automatic mode confirmed off (manual)
    /// Operating/status code. Alarm-reset is only accepted while this reads 7 ("alarm").
    static let readOperatingState = read(0x02E5)
    /// High byte = current alarm code (0 = none), once `readOperatingState` reports 7.
    static let readAlarmCode = read(0x02E6)
    /// Two registers (4 data bytes): pellet reserve is bit 2 of the second data byte.
    static let readWarningFlags = read(0x02F4, count: 2)
    /// Low byte decodes which fan controls the stove actually has — see
    /// `FanConfiguration`. Not every Edilkamin model has Fan 2/3.
    static let readFanConfiguration = read(0x0548)
    /// Packed register: high byte = Fan 3 speed, low byte = Fan 2 speed. Only meaningful
    /// when `readFanConfiguration` reports those fans exist.
    static let readFan23 = read(0x052A)
    /// "Relax" (quiet/night) mode: lowers fan noise. A separate register from the fans —
    /// confirmed distinct from 0x052A. Manual power/fan commands are documented as
    /// blocked while this is active.
    static let readRelaxMode = read(0x052B)
    /// Chrono (weekly schedule) on/off, bit 0 — by analogy with `readOnOffRegister`.
    /// The rest of the register is understood to select which of the two stored
    /// programs (0x04CE/0x04F8) is active; this task only reads/preserves it, it
    /// doesn't interpret or change it. Unverified on a real stove.
    static let readChronoOnOff = read(0x0522)
    /// Chrono "Économie" preset temperature.
    static let readChronoEconomyPreset = read(0x04CC)
    /// Chrono "Confort" preset temperature.
    static let readChronoComfortPreset = read(0x04CD)

    enum FanConfiguration {
        case none, fan1Only, fan1And2, fan1And2And3, fan2And3Only, unknown

        init(rawLowByte: UInt8) {
            switch rawLowByte {
            case 0: self = .none
            case 1: self = .fan1Only
            case 2: self = .fan1And2
            case 3: self = .fan1And2And3
            case 4: self = .fan2And3Only
            default: self = .unknown
            }
        }

        var hasFan1: Bool { self == .fan1Only || self == .fan1And2 || self == .fan1And2And3 }
        var hasFan2: Bool { self == .fan1And2 || self == .fan1And2And3 || self == .fan2And3Only }
        var hasFan3: Bool { self == .fan1And2And3 || self == .fan2And3Only }
    }

    // MARK: - Writes

    /// Power on/off needs read-modify-write: read `readOnOffRegister` first, flip bit 0
    /// of the low byte, keep every other bit, then send this with that modified value.
    static func writeOnOffRegister(preservingOtherBitsAs currentValue: UInt16, on: Bool) -> Command {
        let newValue = on ? (currentValue | 0x0001) : (currentValue & ~0x0001)
        return write(0x031C, value: newValue)
    }

    /// Target temperature in °C, 0.5° steps, range 5–35 °C: confirmed encoding, register
    /// stores tenths of a degree (e.g. 24.0 °C → 240, 18.5 °C → 185). A value outside
    /// 5–35 °C or not a multiple of 0.5° is silently ignored by the stove (no write).
    static func writeTargetTemperature(celsius: Double) -> Command {
        let clamped = min(max(celsius, 5), 35)
        let tenths = (clamped * 10).rounded()
        return write(0x0525, value: UInt16(tenths))
    }

    /// Manual power level, range 1–5, written into the low byte of the packed register
    /// — pass the just-read current register value to preserve its high byte (Fan 1).
    static func writePowerLevel(_ level: Int, preservingFanByteOf currentValue: UInt16) -> Command {
        let clamped = UInt16(clamping: max(1, min(5, level)))
        let newValue = (currentValue & 0xFF00) | clamped
        return write(0x0529, value: newValue)
    }

    /// Fan 1 speed, range 1–6 (6 = Auto), written into the high byte of the packed
    /// register — pass the just-read current value to preserve its low byte (power level).
    static func writeFan1Speed(_ speed: Int, preservingPowerByteOf currentValue: UInt16) -> Command {
        let clamped = UInt16(clamping: max(1, min(6, speed)))
        let newValue = (currentValue & 0x00FF) | (clamped << 8)
        return write(0x0529, value: newValue)
    }

    /// Fan 2 speed (1–6, 6 = Auto) — pass the current 0x052A value to preserve Fan 3's byte.
    static func writeFan2Speed(_ speed: Int, preservingFan3ByteOf currentValue: UInt16) -> Command {
        let clamped = UInt16(clamping: max(1, min(6, speed)))
        let newValue = (currentValue & 0xFF00) | clamped
        return write(0x052A, value: newValue)
    }

    /// Fan 3 speed (1–6, 6 = Auto) — pass the current 0x052A value to preserve Fan 2's byte.
    static func writeFan3Speed(_ speed: Int, preservingFan2ByteOf currentValue: UInt16) -> Command {
        let clamped = UInt16(clamping: max(1, min(6, speed)))
        let newValue = (currentValue & 0x00FF) | (clamped << 8)
        return write(0x052A, value: newValue)
    }

    /// Switches "Relax" (quiet/night) mode. Both bytes are written together — 0x0101 for
    /// on, 0x0000 for off — per the app's own command template; a genuine read-modify-write
    /// wasn't needed since nothing else appears to share this register.
    static func writeRelaxMode(on: Bool) -> Command {
        write(0x052B, value: on ? 0x0101 : 0x0000)
    }

    /// Switches between automatic (the stove manages its own power) and manual mode.
    /// Only the "confirmed manual" value (0x0001) has been seen on a real stove; the
    /// "automatic" value (0x0000) is this codebase's best guess from the register's
    /// name and is unverified — check the stove's own display after using this.
    static func writeAutomaticMode(on: Bool) -> Command {
        write(0x0523, value: on ? 0x0000 : 0x0001)
    }

    /// Acknowledges the current alarm: read-modify-write of the shared command register,
    /// setting only bit 1 (reset) and preserving every other bit. The stove is documented
    /// to reject this while bit 0 (power) is set — turn the stove off first.
    static func writeAlarmReset(preservingOtherBitsAs currentValue: UInt16) -> Command {
        write(0x031C, value: currentValue | 0x0002)
    }

    /// Switches the Chrono (weekly schedule) feature on or off: read-modify-write like
    /// `writeOnOffRegister`/`writeAlarmReset`, flipping only bit 0 and preserving every
    /// other bit (the active-program selection — see `readChronoOnOff`) as read.
    static func writeChronoOnOff(preservingOtherBitsAs currentValue: UInt16, on: Bool) -> Command {
        let newValue = on ? (currentValue | 0x0001) : (currentValue & ~0x0001)
        return write(0x0522, value: newValue)
    }

    /// Chrono preset temperatures, range 5–35 °C. Encoding is assumed to be a whole
    /// number of degrees written directly (e.g. 18 °C → 0x0012), unlike the manual
    /// setpoint (`writeTargetTemperature`), which stores tenths of a degree: the
    /// official app's decompiled source writes these two registers without the ×10
    /// scaling used elsewhere. Not verified empirically on a real stove — read back
    /// after writing and compare against the stove's own Chrono settings screen.
    static func writeChronoEconomyPreset(celsius: Int) -> Command {
        write(0x04CC, value: UInt16(clamping: max(5, min(35, celsius))))
    }

    /// See `writeChronoEconomyPreset` for the (unverified) encoding assumption.
    static func writeChronoComfortPreset(celsius: Int) -> Command {
        write(0x04CD, value: UInt16(clamping: max(5, min(35, celsius))))
    }

    // MARK: - Response parsing

    /// Parses a function-3 (read holding registers) response and returns its raw data
    /// bytes: [addr, 0x03, byteCount, data...] → data (byteCount bytes).
    static func dataBytes(fromReadResponse response: [UInt8]) -> [UInt8]? {
        guard response.count >= 3, response[1] == 3 else { return nil }
        let byteCount = Int(response[2])
        guard response.count >= 3 + byteCount else { return nil }
        return Array(response[3..<(3 + byteCount)])
    }

    /// Convenience for a single-register (count: 1) read: its one 16-bit value, big-endian.
    static func firstRegisterValue(fromReadResponse response: [UInt8]) -> UInt16? {
        guard let data = dataBytes(fromReadResponse: response), data.count >= 2 else { return nil }
        return (UInt16(data[0]) << 8) | UInt16(data[1])
    }
}
