import XCTest

@testable import EvoControl

final class StoveBLEManagerWriteFragmentsTests: XCTestCase {
    func testPayloadWithinLimitIsNotSplit() {
        let payload = Data(repeating: 0xAB, count: 20)
        let fragments = StoveBLEManager.writeFragments(for: payload, maxLength: 20)
        XCTAssertEqual(fragments, [payload])
    }

    func testPayloadOverLimitIsSplitIntoSeveralFragments() {
        // The real-world case this fix addresses: the ~128-byte encrypted Chrono
        // schedule write against a typical 20-byte unnegotiated ATT MTU.
        let payload = Data((0..<128).map { UInt8($0 % 256) })
        let fragments = StoveBLEManager.writeFragments(for: payload, maxLength: 20)
        XCTAssertEqual(fragments.count, 7)
        XCTAssertEqual(fragments.map(\.count), [20, 20, 20, 20, 20, 20, 8])
        XCTAssertEqual(fragments.reduce(Data(), +), payload)
    }

    func testPayloadExactlyAMultipleOfTheLimitSplitsEvenly() {
        let payload = Data(repeating: 0x11, count: 40)
        let fragments = StoveBLEManager.writeFragments(for: payload, maxLength: 20)
        XCTAssertEqual(fragments.count, 2)
        XCTAssertEqual(fragments.map(\.count), [20, 20])
        XCTAssertEqual(fragments.reduce(Data(), +), payload)
    }

    func testEmptyPayloadReturnsASingleEmptyFragment() {
        let fragments = StoveBLEManager.writeFragments(for: Data(), maxLength: 20)
        XCTAssertEqual(fragments, [Data()])
    }

    func testNonPositiveMaxLengthIsTreatedAsNoLimit() {
        let payload = Data(repeating: 0x42, count: 10)
        XCTAssertEqual(StoveBLEManager.writeFragments(for: payload, maxLength: 0), [payload])
        XCTAssertEqual(StoveBLEManager.writeFragments(for: payload, maxLength: -1), [payload])
    }
}
