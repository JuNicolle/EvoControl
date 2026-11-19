import SwiftUI

/// Collapsed by default: the hex exchange log is useful for troubleshooting but has
/// no place cluttering the everyday screen.
struct DiagnosticCard: View {
    let log: [String]
    @State private var expanded = false

    var body: some View {
        Card {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                HStack {
                    CardTitle(title: "Diagnostic Bluetooth", systemImage: "ladybug")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
