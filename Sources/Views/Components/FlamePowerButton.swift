import SwiftUI

/// The big circular power control. Rebuilt away from a flat filled "ball": a soft
/// blurred aura bleeding into the background, a glass-like disc with a specular
/// highlight, and a thin metallic bezel — closer to a premium thermostat dial.
struct FlamePowerButton: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer aura: blurred, extends past the disc instead of a hard edge.
                Circle()
                    .fill(Theme.ember)
                    .frame(width: 170, height: 170)
                    .blur(radius: 46)
                    .opacity(isOn ? (breathe ? 0.55 : 0.35) : 0)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)

                // Glass disc.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isOn
                                ? [Theme.ashLight, Theme.ash]
                                : [Theme.ashLight.opacity(0.9), Theme.ash.opacity(0.9)],
                            center: .center, startRadius: 0, endRadius: 110
                        )
                    )
                    .frame(width: 210, height: 210)

                // Metallic bezel.
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: isOn
                                ? [Theme.emberLight, Theme.ember, Theme.ember.opacity(0.4)]
                                : [.white.opacity(0.3), .white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 210, height: 210)

                // Specular highlight, upper-left, for a glossy feel.
                Ellipse()
                    .fill(.white.opacity(0.1))
                    .frame(width: 110, height: 60)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -40, y: -68)
                    .mask(Circle().frame(width: 206, height: 206))

                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isOn ? Theme.emberLight : .white.opacity(0.28),
                        isOn ? Theme.ember : .white.opacity(0.14)
                    )
                    .shadow(color: isOn ? Theme.ember.opacity(0.6) : .clear, radius: 16)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: isOn)

                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                        .offset(y: 78)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .sensoryFeedback(.impact(weight: .medium), trigger: isOn)
        .onAppear { breathe = true }
        .accessibilityLabel(isOn ? "Éteindre le poêle" : "Allumer le poêle")
    }
}
