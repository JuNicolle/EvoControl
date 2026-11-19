import SwiftUI

/// Generic "N tappable bars" level control — used for the manual power level and for
/// each fan's speed, which share the same stove-panel look.
struct BarLevelCard: View {
    let title: String
    let systemImage: String
    @Binding var level: Int
    let appliedLevel: Int
    /// Highest selectable bar. When `autoAtMax` is true, that top bar means "Auto"
    /// (fans go 1–5 plus an automatic mode; manual power only goes 1–5).
    var maxLevel: Int = 5
    var autoAtMax: Bool = false
    let isBusy: Bool
    /// Extra note shown under the control, e.g. the automatic-mode caveat.
    var footnote: String?
    let onApply: () -> Void

    private var isDirty: Bool { level != appliedLevel }

    var body: some View {
        Card {
            CardTitle(title: title, systemImage: systemImage)
            HStack(spacing: 8) {
                ForEach(1...maxLevel, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(bar <= level ? Theme.ember : .white.opacity(0.1))
                        .frame(height: barHeight(for: bar))
                        .frame(maxWidth: .infinity)
                        .onTapGesture { level = bar }
                }
            }
            .frame(height: 70, alignment: .bottom)
            .animation(.snappy, value: level)

            HStack {
                Text(levelLabel).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                if isDirty {
                    Button("Appliquer", action: onApply)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.ember)
                        .disabled(isBusy)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: isDirty)

            if let footnote {
                Label(footnote, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var levelLabel: String {
        if autoAtMax, level == maxLevel { return "Automatique" }
        return "Niveau \(level) sur \(autoAtMax ? maxLevel - 1 : maxLevel)"
    }

    private func barHeight(for bar: Int) -> CGFloat {
        if autoAtMax, bar == maxLevel { return 70 }
        return CGFloat(22 + bar * 8)
    }
}
