import SwiftUI

/// Switches the stove between automatic and manual power management.
struct ModeCard: View {
    @Binding var automaticMode: Bool
    let isBusy: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Card {
            CardTitle(title: "Mode", systemImage: "dial.medium")
            Picker("Mode", selection: $automaticMode) {
                Text("Manuel").tag(false)
                Text("Automatique").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(isBusy)
            .onChange(of: automaticMode) { _, newValue in onChange(newValue) }
            Text("En automatique, le poêle gère lui-même sa puissance : les réglages de puissance et de ventilateurs n'ont plus d'effet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
