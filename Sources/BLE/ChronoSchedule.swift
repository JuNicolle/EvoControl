import Foundation

/// A day of the week, as indexed in the Chrono weekly schedule grid.
///
/// The order of the 7 days within the raw 336-slot grid read from/written to the
/// stove (`EdilkaminRegisters.chronoScheduleRegister`) has not been confirmed against
/// a real stove — the decompiled official app source doesn't make it explicit. This
/// codebase assumes Monday is day 0 (`CaseIterable`'s declaration order below).
/// Verify by writing a single known slot (e.g. Monday 08:00–08:30) and comparing with
/// the stove's own Chrono screen — see plan.md and the PR description.
enum ChronoDay: Int, CaseIterable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

/// The state of a single 30-minute Chrono slot.
///
/// Each slot is packed on 2 bits in the raw grid, so it has 4 possible raw values.
/// Only 3 are confirmed semantically, by reading the decompiled official app's UI
/// code (off/comfort/economy); the 4th (raw value 3) has never been observed there
/// and is mapped to `.off` as a safe default — unconfirmed, see plan.md.
enum ChronoSlot: Int, Sendable {
    case off = 0
    case comfort = 1
    case economy = 2

    init(rawBits: UInt8) {
        switch rawBits & 0b11 {
        case 1: self = .comfort
        case 2: self = .economy
        default: self = .off  // covers raw 0, and the unidentified raw 3
        }
    }
}

/// The full weekly Chrono schedule: 7 days × 48 half-hour slots (00:00–23:30), as
/// read from or written to the stove's schedule grid register — see
/// `EdilkaminRegisters.chronoScheduleRegister`.
struct ChronoSchedule: Equatable, Sendable {
    static let slotsPerDay = 48
    static let totalSlots = ChronoDay.allCases.count * slotsPerDay
    /// 2 bits per slot, 4 slots per byte.
    static let payloadByteCount = totalSlots / 4

    private var slotsByDay: [ChronoDay: [ChronoSlot]]

    init() {
        slotsByDay = Dictionary(
            uniqueKeysWithValues: ChronoDay.allCases.map { ($0, Array(repeating: .off, count: Self.slotsPerDay)) }
        )
    }

    subscript(day: ChronoDay, slot slotIndex: Int) -> ChronoSlot {
        get { slotsByDay[day]?[slotIndex] ?? .off }
        set {
            var daySlots = slotsByDay[day] ?? Array(repeating: .off, count: Self.slotsPerDay)
            daySlots[slotIndex] = newValue
            slotsByDay[day] = daySlots
        }
    }

    func slots(for day: ChronoDay) -> [ChronoSlot] {
        slotsByDay[day] ?? Array(repeating: .off, count: Self.slotsPerDay)
    }

    mutating func setSlots(_ slots: [ChronoSlot], for day: ChronoDay) {
        precondition(slots.count == Self.slotsPerDay)
        slotsByDay[day] = slots
    }

    /// Encodes this schedule into the 84-byte payload expected by
    /// `EdilkaminRegisters.writeChronoSchedule`.
    ///
    /// Reconstructed from the decompiled official app (`ChronoViewModel.kt`'s read
    /// path), not yet verified against a real stove — see plan.md. On read, the app
    /// walks the 84 bytes in order and decodes each byte into 4 slots (2 bits each,
    /// least-significant pair first), then — once all 336 slots have been collected
    /// in that byte order — reverses the whole 336-slot list to get the day/time
    /// ordered schedule. Writing does the exact opposite: flatten the day/time ordered
    /// schedule, reverse it, then re-pack it 4 slots per byte in the same order.
    func encoded() -> [UInt8] {
        var ordered: [ChronoSlot] = []
        ordered.reserveCapacity(Self.totalSlots)
        for day in ChronoDay.allCases {
            ordered.append(contentsOf: slots(for: day))
        }
        let rawOrder = Array(ordered.reversed())
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Self.payloadByteCount)
        for groupStart in stride(from: 0, to: rawOrder.count, by: 4) {
            bytes.append(Self.packByte(rawOrder[groupStart..<(groupStart + 4)]))
        }
        return bytes
    }

    /// Decodes an 84-byte payload read from the stove into a schedule — see
    /// `encoded()` for the (unverified) byte layout this inverts.
    static func decoded(fromPayload bytes: [UInt8]) -> ChronoSchedule {
        precondition(bytes.count == payloadByteCount)
        var rawOrder: [ChronoSlot] = []
        rawOrder.reserveCapacity(totalSlots)
        for byte in bytes {
            rawOrder.append(contentsOf: unpackByte(byte))
        }
        let ordered = Array(rawOrder.reversed())
        var schedule = ChronoSchedule()
        for (dayIndex, day) in ChronoDay.allCases.enumerated() {
            let start = dayIndex * slotsPerDay
            schedule.setSlots(Array(ordered[start..<(start + slotsPerDay)]), for: day)
        }
        return schedule
    }

    private static func packByte(_ slots: ArraySlice<ChronoSlot>) -> UInt8 {
        var byte: UInt8 = 0
        for (offset, slot) in slots.enumerated() {
            byte |= UInt8(slot.rawValue) << (offset * 2)
        }
        return byte
    }

    private static func unpackByte(_ byte: UInt8) -> [ChronoSlot] {
        (0..<4).map { ChronoSlot(rawBits: (byte >> ($0 * 2)) & 0b11) }
    }
}
