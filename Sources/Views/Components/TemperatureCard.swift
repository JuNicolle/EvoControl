import SwiftUI

/// Target-temperature card: round +/- steppers around a big number, with an
/// "Appliquer" chip that only appears once the value actually differs from what
/// the stove currently reports.
struct TemperatureCard: View {
    @Binding var target: Double
    let appliedTarget: Double
    let isBusy: Bool
    let onApply: () -> Void

    private var isDirty: Bool { abs(target - appliedTarget) >= 0.01 }

    var body: some View {
        Card {
            CardTitle(title: "Consigne", systemImage: "thermometer.sun")
            HStack(spacing: 20) {
                roundButton("minus") { target = max(5, target - 0.5) }
                VStack(spacing: 2) {
                    Text(target.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: target)
                    Text("°C")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                roundButton("plus") { target = min(35, target + 0.5) }
            }
            if isDirty {
                Button(action: onApply) {
                    Label("Appliquer \(target.formatted(.number.precision(.fractionLength(1))))°C", systemImage: "checkmark")
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

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}
