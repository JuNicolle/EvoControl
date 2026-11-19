import SwiftUI

struct StoveView: View {
    let ble: StoveBLEManager

    @State private var isOn = false
    @State private var ambient: Double = 0
    @State private var appliedTarget: Double = 20
    @State private var target: Double = 20
    @State private var appliedLevel = 1
    @State private var level = 1
    @State private var appliedFan1 = 1
    @State private var fan1 = 1
    @State private var hasFan2 = false
    @State private var appliedFan2 = 1
    @State private var fan2 = 1
    @State private var hasFan3 = false
    @State private var appliedFan3 = 1
    @State private var fan3 = 1
    @State private var automaticMode = false
    @State private var relaxMode = false
    @State private var pelletReserve = false
    @State private var alarmCode: UInt8 = 0
    @State private var hasAlarm = false
    @State private var error: String?
    @State private var isBusy = false
    /// Simulator-only: lets the dashboard be reviewed visually without real BLE
    /// hardware, since the iOS Simulator has no Bluetooth radio.
    @State private var demoMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if ble.state == .ready || demoMode {
                    dashboard
                } else {
                    ConnectionScreen(
                        state: ble.state,
                        onConnect: { run { try await ble.connect(); try await refresh() } },
                        onPreview: isSimulator ? { enterDemoMode() } : nil
                    )
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if ble.state == .ready || demoMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Déconnecter", systemImage: "bolt.slash", role: .destructive) {
                            demoMode = false
                            ble.disconnect()
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Evo Cherie 11")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    FlamePowerButton(isOn: isOn, isBusy: isBusy) {
                        if demoMode { isOn.toggle(); return }
                        run { try await ble.setPower(on: !isOn); try await refresh() }
                    }
                    Text("\(ambient.formatted(.number.precision(.fractionLength(1))))°")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("Température ambiante")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    statusPill
                }
                .padding(.top, 8)

                if hasAlarm {
                    AlarmCard(alarmCode: alarmCode, isOn: isOn, isBusy: isBusy) {
                        if demoMode { hasAlarm = false; return }
                        run { try await ble.acknowledgeAlarm(); try await refresh() }
                    }
                }

                PelletReserveCard(isLow: pelletReserve)

                ModeCard(automaticMode: $automaticMode, isBusy: isBusy) { newValue in
                    if demoMode { return }
                    run { try await ble.setAutomaticMode(on: newValue); try await refresh() }
                }

                RelaxModeCard(relaxMode: $relaxMode, isBusy: isBusy) { newValue in
                    if demoMode { return }
                    run { try await ble.setRelaxMode(on: newValue); try await refresh() }
                }

                TemperatureCard(target: $target, appliedTarget: appliedTarget, isBusy: isBusy) {
                    if demoMode { appliedTarget = target; return }
                    run { try await ble.setTargetTemperature(celsius: target); try await refresh() }
                }

                BarLevelCard(
                    title: "Puissance", systemImage: "chart.bar.fill",
                    level: $level, appliedLevel: appliedLevel, isBusy: isBusy,
                    footnote: powerControlsFootnote
                ) {
                    if demoMode { appliedLevel = level; return }
                    run { try await ble.setPowerLevel(level); try await refresh() }
                }

                BarLevelCard(
                    title: "Ventilateur 1", systemImage: "fan.fill",
                    level: $fan1, appliedLevel: appliedFan1, maxLevel: 6, autoAtMax: true, isBusy: isBusy,
                    footnote: powerControlsFootnote
                ) {
                    if demoMode { appliedFan1 = fan1; return }
                    run { try await ble.setFan1Speed(fan1); try await refresh() }
                }

                if hasFan2 {
                    BarLevelCard(
                        title: "Ventilateur 2", systemImage: "fan.fill",
                        level: $fan2, appliedLevel: appliedFan2, maxLevel: 6, autoAtMax: true, isBusy: isBusy
                    ) {
                        if demoMode { appliedFan2 = fan2; return }
                        run { try await ble.setFan2Speed(fan2); try await refresh() }
                    }
                }
                if hasFan3 {
                    BarLevelCard(
                        title: "Ventilateur 3", systemImage: "fan.fill",
                        level: $fan3, appliedLevel: appliedFan3, maxLevel: 6, autoAtMax: true, isBusy: isBusy
                    ) {
                        if demoMode { appliedFan3 = fan3; return }
                        run { try await ble.setFan3Speed(fan3); try await refresh() }
                    }
                }

                if let error {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                if !ble.exchangeLog.isEmpty {
                    DiagnosticCard(log: ble.exchangeLog)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .refreshable { try? await refresh() }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(isOn ? Theme.ember : .gray).frame(width: 7, height: 7)
            Text(isOn ? "Allumé" : "Éteint")
            Text("·").foregroundStyle(.tertiary)
            Text(automaticMode ? "Automatique" : "Manuel")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.white.opacity(0.06), in: Capsule())
    }

    private var powerControlsFootnote: String? {
        if automaticMode { return "Mode automatique : passez en manuel pour que ça change." }
        if relaxMode { return "Mode silence actif : désactivez-le pour que ça change." }
        return nil
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

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    private func enterDemoMode() {
        isOn = true
        ambient = 21.4
        appliedTarget = 21
        target = 21
        appliedLevel = 3
        level = 3
        appliedFan1 = 3
        fan1 = 3
        hasFan2 = true
        appliedFan2 = 6
        fan2 = 6
        hasFan3 = false
        automaticMode = false
        relaxMode = false
        pelletReserve = false
        hasAlarm = false
        alarmCode = 0
        demoMode = true
    }

    private func refresh() async throws {
        let state = try await ble.readState()
        isOn = state.isOn
        ambient = state.ambient
        appliedTarget = state.target
        target = state.target
        appliedLevel = max(1, min(5, state.powerLevel))
        level = appliedLevel
        appliedFan1 = max(1, min(6, state.fan1Speed))
        fan1 = appliedFan1
        if let f2 = state.fan2Speed {
            hasFan2 = true
            appliedFan2 = max(1, min(6, f2))
            fan2 = appliedFan2
        } else {
            hasFan2 = false
        }
        if let f3 = state.fan3Speed {
            hasFan3 = true
            appliedFan3 = max(1, min(6, f3))
            fan3 = appliedFan3
        } else {
            hasFan3 = false
        }
        automaticMode = state.automaticMode
        relaxMode = state.relaxMode
        pelletReserve = state.pelletReserve
        hasAlarm = state.hasAlarm
        alarmCode = state.alarmCode
    }
}
