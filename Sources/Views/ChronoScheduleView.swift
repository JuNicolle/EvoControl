import SwiftUI

/// Dedicated screen for editing the Chrono weekly schedule grid: 7 days × 48
/// half-hour slots. Reads the current grid from the stove on first appearance (or
/// starts from an all-"Off" grid in demo mode), lets the user paint a multi-slot
/// selection with Confort/Économie/Éteint, then writes the whole grid back only once
/// "Envoyer au poêle" is tapped (spec.md, critère 5: no BLE write on every tap).
struct ChronoScheduleView: View {
    let ble: StoveBLEManager
    let isDemoMode: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var schedule = ChronoSchedule()
    @State private var selectedDay: ChronoDay = .monday
    @State private var selectedSlots: Set<Int> = []
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var error: String?
    @State private var didSend = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if isLoading {
                    ProgressView("Lecture de la programmation…")
                        .tint(Theme.ember)
                } else {
                    content
                }
            }
            .navigationTitle("Programmation horaire")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer au poêle") { send() }
                        .disabled(isBusy || isLoading)
                }
            }
            .preferredColorScheme(.dark)
        }
        .task { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                daySelector
                slotGrid
                applyButtons
                legend

                if let error {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if didSend {
                    Label("Programmation envoyée au poêle.", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
            .padding(20)
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChronoDay.allCases, id: \.self) { day in
                    Button(day.shortLabel) {
                        selectedDay = day
                        selectedSlots.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .tint(day == selectedDay ? Theme.ember : .gray)
                    .accessibilityIdentifier("chrono-day-\(day.rawValue)")
                }
            }
        }
    }

    private var slotGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<ChronoSchedule.slotsPerDay, id: \.self) { index in
                let slot = schedule[selectedDay, slot: index]
                Button {
                    toggleSelection(index)
                } label: {
                    Text(timeLabel(for: index))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .foregroundStyle(.white)
                        .background(color(for: slot), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selectedSlots.contains(index) ? Color.white : .clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chrono-slot-\(index)")
            }
        }
    }

    private var applyButtons: some View {
        HStack(spacing: 10) {
            applyButton(title: "Confort", slot: .comfort)
            applyButton(title: "Économie", slot: .economy)
            applyButton(title: "Éteint", slot: .off)
        }
        .disabled(selectedSlots.isEmpty)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendEntry(title: "Confort", slot: .comfort)
            legendEntry(title: "Économie", slot: .economy)
            legendEntry(title: "Éteint", slot: .off)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendEntry(title: String, slot: ChronoSlot) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(for: slot))
                .frame(width: 12, height: 12)
            Text(title)
        }
    }

    private func applyButton(title: String, slot: ChronoSlot) -> some View {
        Button(title) {
            for index in selectedSlots { schedule[selectedDay, slot: index] = slot }
            selectedSlots.removeAll()
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("chrono-apply-\(slot.rawValue)")
    }

    private func toggleSelection(_ index: Int) {
        if selectedSlots.contains(index) {
            selectedSlots.remove(index)
        } else {
            selectedSlots.insert(index)
        }
    }

    private func color(for slot: ChronoSlot) -> Color {
        switch slot {
        case .off: Theme.ash
        case .comfort: Theme.ember
        case .economy: Theme.emberLight.opacity(0.55)
        }
    }

    private func timeLabel(for index: Int) -> String {
        let minutes = index * 30
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func load() async {
        defer { isLoading = false }
        guard !isDemoMode else { return }
        do {
            schedule = try await ble.readChronoSchedule()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send() {
        guard !isBusy else { return }
        isBusy = true
        didSend = false
        Task {
            defer { isBusy = false }
            guard !isDemoMode else { didSend = true; return }
            do {
                try await ble.setChronoSchedule(schedule)
                didSend = true
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private extension ChronoDay {
    var shortLabel: String {
        switch self {
        case .monday: "Lun"
        case .tuesday: "Mar"
        case .wednesday: "Mer"
        case .thursday: "Jeu"
        case .friday: "Ven"
        case .saturday: "Sam"
        case .sunday: "Dim"
        }
    }
}
