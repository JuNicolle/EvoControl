import SwiftUI

/// Only shown while the stove reports an active alarm. Lets the user acknowledge it
/// once the stove is off, mirroring the precondition the stove itself enforces.
struct AlarmCard: View {
    let alarmCode: UInt8
    let isOn: Bool
    let isBusy: Bool
    let onAcknowledge: () -> Void

    var body: some View {
        Card {
            CardTitle(title: "Alarme active", systemImage: "exclamationmark.triangle.fill")
            Text("Code d'alarme \(alarmCode)")
                .font(.title3.weight(.semibold))
            if isOn {
                Text("Éteignez le poêle avant de pouvoir acquitter l'alarme.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button("Acquitter l'alarme", action: onAcknowledge)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isBusy)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.red.opacity(0.5), lineWidth: 1.5)
        )
    }
}
