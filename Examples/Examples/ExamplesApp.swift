import BluetoothKit
import SwiftUI

@main
struct ExamplesApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let repository: BLERespository
    let usecase: BLEUseCaseImpl
    let connectViewModel: ConnectViewModel
    let logViewModel: LogViewModel

    init() {
        repository = BLERespository()
        usecase = BLEUseCaseImpl(repository: repository)
        connectViewModel = ConnectViewModel(usecase: usecase)
        logViewModel = LogViewModel(usecase: usecase)
    }
}
