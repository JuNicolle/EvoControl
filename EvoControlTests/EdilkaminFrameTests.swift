import XCTest

@testable import EvoControl

final class EdilkaminFrameTests: XCTestCase {
    func testRoundTripPreservesSixByteCommand() throws {
        try assertRoundTrip(commandLength: 6)
    }

    func testRoundTripPreservesChronoScheduleWriteCommandLength() throws {
        // 7-byte function-0x10 header + 84-byte Chrono grid payload (see
        // ChronoSchedule): the real-world size this task introduces.
        try assertRoundTrip(commandLength: 7 + 84)
    }

    func testRoundTripPreservesCommandAtExactBlockBoundary() throws {
        // 22 (timestamp + fixed key) + 10 (command) + 2 (CRC) = 34, a case where the
        // pre-padding frame length is itself a multiple of 16: PKCS7 still adds a full
        // extra block of padding. This is the multi-block padding risk flagged in
        // plan.md.
        try assertRoundTrip(commandLength: 10)
    }

    func testRoundTripPreservesCommandAcrossSeveralBlockSizes() throws {
        for length in [1, 6, 7, 16, 32, 64, 84, 90, 91, 100] {
            try assertRoundTrip(commandLength: length)
        }
    }

    private func assertRoundTrip(commandLength: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let command = (0..<commandLength).map { UInt8($0 % 256) }
        let encrypted = try EdilkaminFrame.encryptedCommand(command)
        let decoded = try EdilkaminFrame.decodeResponse(encrypted)
        XCTAssertEqual(decoded, command, "length \(commandLength)", file: file, line: line)
    }
}
