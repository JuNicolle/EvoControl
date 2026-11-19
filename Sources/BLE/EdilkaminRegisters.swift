import Foundation

/// Modbus register map for the stove's local BLE control, as documented by the
/// open-source project https://github.com/netmb/Edilkamin_BT (see EdilkaminFrame.swift).
///
/// Register *addresses* below are well established (read commands are unambiguous:
/// address, function 3 "read holding registers", register, count). The *value
/// encoding* of a couple of write commands (temperature scale, on/off bit position)
/// is flagged "uncertain" by that same source project. Verify empirically: set, then
/// re-read the register and compare, before trusting a value blindly.
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

    static let readOnOffRegister = read(0x031C)  // bit 0 = power state; other bits must be preserved
    static let readMainAmbientTemperature = read(0x02E9)  // measured room temperature
    static let readTargetTemperature = read(0x0525)  // target / setpoint register, tenths of °C
    /// Packed register: high byte = Fan 1 speed, low byte = manual power level (1–5).
    /// Confirmed on a real stove: writing 0x0003 read back as 0x0603 (fan byte unrelated
    /// to what we sent, power byte exactly as written) — always mask to the low byte.
    static let readPowerLevel = read(0x0529)
    static let readAutomaticMode = read(0x0523)  // 0x0001 = automatic mode confirmed off
    static let readPelletReserve = read(0x02EC)
    static let readWarningFlags = read(0x02F4, count: 2)

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

    /// Parses a function-3 (read holding registers) response: [addr, 0x03, byteCount, data...].
    /// Returns the first 16-bit register value, big-endian.
    static func firstRegisterValue(fromReadResponse response: [UInt8]) -> UInt16? {
        guard response.count >= 5, response[1] == 3 else { return nil }
        return (UInt16(response[3]) << 8) | UInt16(response[4])
    }
}
