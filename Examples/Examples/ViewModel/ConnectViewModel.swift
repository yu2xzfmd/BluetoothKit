import Combine
import Foundation

@MainActor
final class ConnectViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isBluetoothOn = false
    @Published var state: ConnectionState = .idle
    private var bag = Set<AnyCancellable>()
    private let usecase: BLEUseCase

    init(usecase: BLEUseCase) {
        self.usecase = usecase
        bind()
    }

    private func bind() {
        usecase.devicesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)

        usecase.isBluetoothOnPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isBluetoothOn)

        usecase.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }

    func startScan() {
        usecase.startScanSmart()
    }

    func stopScan() {
        usecase.stopScan()
    }

    func connect(id: UUID) {
        usecase.connect(deviceId: id)
    }

    func disconnect() {
        usecase.disconnect()
    }
}
