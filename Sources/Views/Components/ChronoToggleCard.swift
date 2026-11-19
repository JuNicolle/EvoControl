import SwiftUI

/// Chrono (weekly schedule) on/off toggle, plus the two preset temperatures
/// (Économie/Confort) it uses. The toggle applies immediately, like `RelaxModeCard`;
/// the presets only apply once "Appliquer" is tapped, like `TemperatureCard`.
struct ChronoToggleCard: View {
    @Binding var chronoOn: Bool
    @Binding var economyPreset: Double
    @Binding var comfortPreset: Double
    let appliedEconomyPreset: Double
    let appliedComfortPreset: Double
    let isBusy: Bool
    let onToggleChrono: (Bool) -> Void
    let onApplyPresets: () -> Void

    private var isDirty: Bool {
        economyPreset != appliedEconomyPreset || comfortPreset != appliedComfortPreset
    }

    var body: some View {
        Card {
            HStack {
                CardTitle(title: "Chrono", systemImage: "clock.fill")
                Spacer()
                Toggle("", isOn: $chronoOn)
                    .labelsHidden()
                    .tint(Theme.ember)
                    .disabled(isBusy)
                    .onChange(of: chronoOn) { _, newValue in onToggleChrono(newValue) }
            }
            Text("Suit la programmation horaire plutôt qu'une consigne fixe tant qu'il est actif.")
                .font(.caption)
                .foregroundStyle(.secondary)

            presetStepper(title: "Économie", systemImage: "leaf.fill", value: $economyPreset)
            presetStepper(title: "Confort", systemImage: "sofa.fill", value: $comfortPreset)

            if isDirty {
                Button(action: onApplyPresets) {
                    Label("Appliquer les présets", systemImage: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ember)
                .disabled(isBusy)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isDirty)
    }

    private func presetStepper(title: String, systemImage: String, value: Binding<Double>) -> some View {
        Stepper(value: value, in: 5...35, step: 0.5) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline)
                Spacer()
                Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(1))))°C")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value.wrappedValue)
            }
        }
        .disabled(isBusy)
    }
}
