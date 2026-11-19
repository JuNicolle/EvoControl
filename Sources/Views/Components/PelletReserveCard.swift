import SwiftUI

/// A fuel-gauge style indicator. The stove only reports a low/not-low threshold, not a
/// precise percentage, so the fill level is illustrative (mostly full vs. nearly empty),
/// not a measurement — the caption says so.
struct PelletReserveCard: View {
    let isLow: Bool

    private var fillFraction: CGFloat { isLow ? 0.12 : 0.82 }
    private var gradient: [Color] {
        isLow ? [.red.opacity(0.85), .orange] : [Theme.ember, Theme.emberLight]
    }

    var body: some View {
        Card {
            HStack {
                CardTitle(title: "Réserve de pellets", systemImage: "takeoutbag.and.cup.and.straw.fill")
                Spacer()
                Text(isLow ? "Basse" : "Correcte")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isLow ? .orange : Theme.emberLight)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(26, geo.size.width * fillFraction))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: max(26, geo.size.width * fillFraction))
                        .mask(Capsule().frame(height: 9).offset(y: -5))
                }
                .animation(.snappy, value: isLow)
            }
            .frame(height: 22)
            .overlay(Capsule().strokeBorder(.white.opacity(0.08)))

            Text(
                isLow
                    ? "Pensez à recharger le réservoir."
                    : "Le poêle indique seulement un seuil bas, pas un pourcentage précis."
            )
            .font(.caption)
            .foregroundStyle(isLow ? .orange : .secondary)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isLow ? Color.orange.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}
