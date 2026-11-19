import SwiftUI

struct StoveView: View {
    let ble: StoveBLEManager

    @State private var isOn = false
    @State private var ambient: Double = 0
    @State private var target: Double = 20
    @State private var level = 1
    @State private var automaticMode = false
    @State private var error: String?
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if ble.state == .ready {
                    commandsSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
                if !ble.exchangeLog.isEmpty {
                    Section("Historique des échanges (diagnostic, plus récent en haut)") {
                        ForEach(Array(ble.exchangeLog.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Evo Cherie 11")
            .toolbar {
                if ble.state == .ready {
                    Button("Déconnecter", role: .destructive) { ble.disconnect() }
                }
            }
        }
    }

    @ViewBuilder private var statusSection: some View {
        Section {
            switch ble.state {
            case .idle, .disconnected:
                Button("Se connecter au poêle (Bluetooth)") { run { try await ble.connect(); try await refresh() } }
            case .scanning, .connecting:
                HStack { ProgressView(); Text("Recherche du poêle…") }
            case .ready:
                LabeledContent("État", value: isOn ? "Allumé" : "Éteint")
                LabeledContent("Température ambiante", value: "\(ambient.formatted(.number.precision(.fractionLength(1)))) °C")
                LabeledContent("Consigne actuelle", value: "\(target.formatted(.number.precision(.fractionLength(1)))) °C")
                LabeledContent("Mode", value: automaticMode ? "Automatique" : "Manuel")
            case .failed(let message):
                Text(message).foregroundStyle(.red)
                Button("Réessayer") { run { try await ble.connect(); try await refresh() } }
            }
        } header: {
            Text("Approchez-vous du poêle avant de vous connecter.")
        }
    }

    @ViewBuilder private var commandsSection: some View {
        Section("Commandes") {
            Button(isOn ? "Éteindre" : "Allumer", systemImage: "power") {
                run { try await ble.setPower(on: !isOn); try await refresh() }
            }
            .disabled(isBusy)
            Stepper(
                "Consigne : \(target.formatted(.number.precision(.fractionLength(1)))) °C",
                value: $target, in: 5...35, step: 0.5
            )
            Button("Appliquer la consigne") {
                run { try await ble.setTargetTemperature(celsius: target); try await refresh() }
            }
            .disabled(isBusy)
            Stepper("Puissance : \(level)", value: $level, in: 1...5)
            Button("Appliquer la puissance") {
                run { try await ble.setPowerLevel(level); try await refresh() }
            }
            .disabled(isBusy)
            if automaticMode {
                Text("Le poêle est en mode automatique : le réglage de puissance ne prendra effet qu'en mode manuel (à changer sur l'écran du poêle).")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Button("Rafraîchir l'état") { run { try await refresh() } }.disabled(isBusy)
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do { try await action(); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }

    private func refresh() async throws {
        let state = try await ble.readState()
        isOn = state.isOn
        ambient = state.ambient
        target = state.target
        level = max(1, min(5, state.powerLevel))
        automaticMode = state.automaticMode
    }
}
