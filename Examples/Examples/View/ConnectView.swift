import Combine
import SwiftUI

struct ConnectView: View {
    @StateObject var viewModel: ConnectViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(viewModel.isBluetoothOn ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(viewModel.isBluetoothOn ? "Bluetooth: ON" : "Bluetooth: OFF")
                        .font(.subheadline)
                    Spacer()
                    Text("State: \(viewModel.state.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("スキャン開始") { viewModel.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isBluetoothOn)
                    Button("停止") { viewModel.stopScan() }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.isBluetoothOn)
                }

                List {
                    Section(header: Text("デバイス")) {
                        ForEach(viewModel.devices) { device in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text(device.id.uuidString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if device.isConnected {
                                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                                }
                                Button(device.isConnected ? "切断" : "接続") {
                                    device.isConnected
                                        ? viewModel.disconnect()
                                        : viewModel.connect(id: device.id)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding()
            .navigationTitle("接続")
        }
    }
}

#Preview {
    ConnectView(viewModel: PreviewDeps.container.connectViewModel)
}
