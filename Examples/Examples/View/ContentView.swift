import BluetoothKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        TabView {
            ConnectView(viewModel: container.connectViewModel)
                .tabItem { Label("接続", systemImage: "dot.radiowaves.left.and.right") }

            LogView(viewModel: container.logViewModel)
                .tabItem { Label("ログ", systemImage: "list.bullet.rectangle") }
        }
    }
}

#Preview {
    ContentView().environmentObject(PreviewDeps.container)
}
