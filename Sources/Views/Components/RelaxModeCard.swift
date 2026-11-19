import SwiftUI

/// "Relax" (quiet/night) mode: lowers fan noise. Blocks manual power/fan changes while
/// active, so it gets the same kind of warning the automatic-mode cards show.
struct RelaxModeCard: View {
    @Binding var relaxMode: Bool
    let isBusy: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Card {
            HStack {
                CardTitle(title: "Mode silence", systemImage: "moon.zzz.fill")
                Spacer()
                Toggle("", isOn: $relaxMode)
                    .labelsHidden()
                    .tint(Theme.ember)
                    .disabled(isBusy)
                    .onChange(of: relaxMode) { _, newValue in onChange(newValue) }
            }
            Text("Réduit le bruit des ventilateurs. Bloque les réglages de puissance et de ventilateurs tant qu'il est actif.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
