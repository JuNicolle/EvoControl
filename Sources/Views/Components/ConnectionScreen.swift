import SwiftUI

/// Full-screen state shown before the app is connected: idle, scanning (with a
/// pulsing radar ring), or a failure with a retry button.
struct ConnectionScreen: View {
    let state: StoveBLEManager.ConnectionState
    let onConnect: () -> Void
    var onPreview: (() -> Void)?

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                if isScanning {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(Theme.ember.opacity(0.4), lineWidth: 2)
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulse ? 1.8 : 1)
                            .opacity(pulse ? 0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(i) * 0.6),
                                value: pulse
                            )
                    }
                }
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 140, height: 140)
                Image(systemName: isScanning ? "antenna.radiowaves.left.and.right" : symbolForIdleOrFailed)
                    .font(.system(size: 46))
                    .foregroundStyle(isFailed ? .red : Theme.emberLight)
                    .symbolEffect(.pulse, isActive: isScanning)
            }
            .onAppear { pulse = true }

            VStack(spacing: 8) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !isScanning {
                Button(action: onConnect) {
                    Label(isFailed ? "Réessayer" : "Se connecter au poêle", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ember)
                .padding(.horizontal, 40)

                if let onPreview {
                    Button("Aperçu sans poêle (design)", action: onPreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("previewButton")
                }
            } else {
                ProgressView().tint(Theme.emberLight)
            }
            Spacer()
            Spacer()
        }
    }

    private var isScanning: Bool { state == .scanning || state == .connecting }
    private var isFailed: Bool { if case .failed = state { true } else { false } }
    private var symbolForIdleOrFailed: String { isFailed ? "exclamationmark.triangle.fill" : "flame" }

    private var title: String {
        switch state {
        case .scanning: "Recherche du poêle…"
        case .connecting: "Connexion…"
        case .failed: "Connexion impossible"
        default: "Evo Cherie 11"
        }
    }

    private var subtitle: String {
        if case .failed(let message) = state { return message }
        switch state {
        case .scanning, .connecting: return "Reste à proximité, ça ne prend que quelques secondes."
        default: return "Approche-toi du poêle, puis connecte-toi en Bluetooth."
        }
    }
}
