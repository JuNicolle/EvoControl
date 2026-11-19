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
}
