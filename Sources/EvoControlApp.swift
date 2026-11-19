import SwiftUI

@main
struct EvoControlApp: App {
    @State private var ble = StoveBLEManager()

    var body: some Scene {
        WindowGroup {
            StoveView(ble: ble)
        }
    }
}
