import XCTest

@testable import EvoControl

final class ChronoRegistersTests: XCTestCase {
    func testReadChronoOnOffTargetsRegister0x0522() {
        XCTAssertEqual(
            EdilkaminRegisters.readChronoOnOff.bytes,
            [1, 3, 0x05, 0x22, 0x00, 0x01]
        )
    }

    func testReadChronoEconomyPresetTargetsRegister0x04CC() {
        XCTAssertEqual(
            EdilkaminRegisters.readChronoEconomyPreset.bytes,
            [1, 3, 0x04, 0xCC, 0x00, 0x01]
        )
    }

    func testReadChronoComfortPresetTargetsRegister0x04CD() {
        XCTAssertEqual(
            EdilkaminRegisters.readChronoComfortPreset.bytes,
            [1, 3, 0x04, 0xCD, 0x00, 0x01]
        )
    }

    func testWriteChronoOnOffSetsBit0WithoutTouchingOtherBits() {
        let command = EdilkaminRegisters.writeChronoOnOff(preservingOtherBitsAs: 0x0004, on: true)
        XCTAssertEqual(command.bytes, [1, 6, 0x05, 0x22, 0x00, 0x05])
    }

    func testWriteChronoOnOffClearsBit0WithoutTouchingOtherBits() {
        let command = EdilkaminRegisters.writeChronoOnOff(preservingOtherBitsAs: 0x0005, on: false)
        XCTAssertEqual(command.bytes, [1, 6, 0x05, 0x22, 0x00, 0x04])
    }

    func testWriteChronoOnOffPreservesHighBitsUntouched() {
        let command = EdilkaminRegisters.writeChronoOnOff(preservingOtherBitsAs: 0xFF00, on: true)
        XCTAssertEqual(command.bytes, [1, 6, 0x05, 0x22, 0xFF, 0x01])
    }

    func testWriteChronoEconomyPresetEncodesPlainValueWithinRange() {
        let command = EdilkaminRegisters.writeChronoEconomyPreset(celsius: 16)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCC, 0x00, 16])
    }

    func testWriteChronoEconomyPresetClampsBelowRange() {
        let command = EdilkaminRegisters.writeChronoEconomyPreset(celsius: 0)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCC, 0x00, 5])
    }

    func testWriteChronoEconomyPresetClampsAboveRange() {
        let command = EdilkaminRegisters.writeChronoEconomyPreset(celsius: 100)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCC, 0x00, 35])
    }

    func testWriteChronoComfortPresetEncodesPlainValueWithinRange() {
        let command = EdilkaminRegisters.writeChronoComfortPreset(celsius: 20)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCD, 0x00, 20])
    }

    func testWriteChronoComfortPresetClampsBelowRange() {
        let command = EdilkaminRegisters.writeChronoComfortPreset(celsius: -10)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCD, 0x00, 5])
    }

    func testWriteChronoComfortPresetClampsAboveRange() {
        let command = EdilkaminRegisters.writeChronoComfortPreset(celsius: 50)
        XCTAssertEqual(command.bytes, [1, 6, 0x04, 0xCD, 0x00, 35])
    }

    func testReadChronoScheduleTargetsRegister0x04CEFor42Registers() {
        XCTAssertEqual(
            EdilkaminRegisters.readChronoSchedule.bytes,
            [1, 3, 0x04, 0xCE, 0x00, 42]
        )
    }

    func testWriteChronoScheduleUsesFunction0x10WithRegisterCountAndByteCount() {
        let payload = [UInt8](repeating: 0, count: 84)
        let command = EdilkaminRegisters.writeChronoSchedule(payload: payload)
        XCTAssertEqual(
            Array(command.bytes.prefix(7)),
            [1, 0x10, 0x04, 0xCE, 0x00, 42, 84]
        )
        XCTAssertEqual(command.bytes.count, 7 + 84)
        XCTAssertEqual(Array(command.bytes.suffix(84)), payload)
    }

    func testWriteChronoScheduleCarriesThePayloadBytesVerbatim() {
        let payload = (0..<84).map { UInt8($0 % 256) }
        let command = EdilkaminRegisters.writeChronoSchedule(payload: payload)
        XCTAssertEqual(Array(command.bytes.suffix(84)), payload)
    }
}
