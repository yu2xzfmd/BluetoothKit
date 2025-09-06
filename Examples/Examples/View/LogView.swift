import BluetoothKit
import SwiftUI

struct LogView: View {
    @StateObject var viewModel: LogViewModel
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ログ (\(viewModel.logs.count))").font(.headline)
                Spacer()
                Toggle("Auto", isOn: $autoScroll).toggleStyle(.switch).labelsHidden()
                Button("クリア") { viewModel.clear() }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { idx, line in
                            Text(line).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: viewModel.logs.count) { _ in
                    if autoScroll, let last = viewModel.logs.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            HStack {
                Button("Dummy Write") { viewModel.writeDummy() }
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding()
        .navigationTitle("ログ")
    }
}

#Preview {
    LogView(viewModel: PreviewDeps.container.logViewModel)
}
