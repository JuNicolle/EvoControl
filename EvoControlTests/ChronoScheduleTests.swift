import XCTest

@testable import EvoControl

final class ChronoScheduleTests: XCTestCase {
    func testEncodedPayloadHasExpectedByteCount() {
        XCTAssertEqual(ChronoSchedule().encoded().count, 84)
    }

    func testRoundTripOfEmptySchedule() {
        assertRoundTrip(ChronoSchedule())
    }

    func testRoundTripOfFullComfortSchedule() {
        var schedule = ChronoSchedule()
        for day in ChronoDay.allCases {
            schedule.setSlots(Array(repeating: .comfort, count: ChronoSchedule.slotsPerDay), for: day)
        }
        assertRoundTrip(schedule)
    }

    func testRoundTripOfFullEconomySchedule() {
        var schedule = ChronoSchedule()
        for day in ChronoDay.allCases {
            schedule.setSlots(Array(repeating: .economy, count: ChronoSchedule.slotsPerDay), for: day)
        }
        assertRoundTrip(schedule)
    }

    func testRoundTripOfAlternatingSchedule() {
        var schedule = ChronoSchedule()
        for day in ChronoDay.allCases {
            let slots = (0..<ChronoSchedule.slotsPerDay).map { $0 % 2 == 0 ? ChronoSlot.economy : ChronoSlot.comfort }
            schedule.setSlots(slots, for: day)
        }
        assertRoundTrip(schedule)
    }

    func testRoundTripOfSingleNonOffSlot() {
        var schedule = ChronoSchedule()
        schedule[.monday, slot: 16] = .comfort  // 08:00

        assertRoundTrip(schedule)
        XCTAssertEqual(schedule[.monday, slot: 16], .comfort)
        XCTAssertEqual(schedule[.tuesday, slot: 16], .off)
        XCTAssertEqual(schedule[.monday, slot: 15], .off)
        XCTAssertEqual(schedule[.monday, slot: 17], .off)
    }

    func testEncodeThenDecodePreservesEverySlotIndependently() {
        var schedule = ChronoSchedule()
        var counter = 0
        for day in ChronoDay.allCases {
            var slots: [ChronoSlot] = []
            for _ in 0..<ChronoSchedule.slotsPerDay {
                slots.append(ChronoSlot(rawBits: UInt8(counter % 3)))
                counter += 1
            }
            schedule.setSlots(slots, for: day)
        }
        assertRoundTrip(schedule)
    }

    func testDecodingUnidentifiedRawValueDefaultsToOff() {
        XCTAssertEqual(ChronoSlot(rawBits: 3), .off)
        XCTAssertEqual(ChronoSlot(rawBits: 0), .off)
        XCTAssertEqual(ChronoSlot(rawBits: 1), .comfort)
        XCTAssertEqual(ChronoSlot(rawBits: 2), .economy)
    }

    private func assertRoundTrip(_ schedule: ChronoSchedule, file: StaticString = #filePath, line: UInt = #line) {
        let encoded = schedule.encoded()
        XCTAssertEqual(encoded.count, 84, file: file, line: line)
        let decoded = ChronoSchedule.decoded(fromPayload: encoded)
        XCTAssertEqual(decoded, schedule, file: file, line: line)
        XCTAssertEqual(decoded.encoded(), encoded, file: file, line: line)
    }
}
