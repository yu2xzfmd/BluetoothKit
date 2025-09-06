import BluetoothKit
import Combine
import Foundation

public final class BLEUseCaseImpl {
    private let repository: BLERespository
    private var bag = Set<AnyCancellable>()

    private let devicesSubj = CurrentValueSubject<[Device], Never>([])
    private let logsSubj = CurrentValueSubject<[String], Never>([])
    private let btOnSubj = CurrentValueSubject<Bool, Never>(false)
    private let stateSubj = CurrentValueSubject<ConnectionState, Never>(.idle)
    private var scanFallbackWorkItem: DispatchWorkItem?

    public init(repository: BLERespository) {
        self.repository = repository
        bind()
    }

    // MARK: - Binding

    private func bind() {
        repository.devicesPublisher
            .prepend([])
            .combineLatest(
                repository.connectedDevicePublisher
                    .map { $0?.id }
                    .prepend(nil)
            )
            .map { list, connectedID in
                list.map { info in
                    Device(
                        id: info.id,
                        name: info.name ?? "Unknown",
                        manufacturerData: info.manufacturerData,
                        rssi: info.rssi.intValue,
                        isConnected: info.id == connectedID
                    )
                }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devicesSubj.send(devices)
            }
            .store(in: &bag)

        repository.logsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.logsSubj.send($0) }
            .store(in: &bag)

        repository.isPoweredOnPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.btOnSubj.send($0) }
            .store(in: &bag)

        repository.statePublisher
            .removeDuplicates()
            .map { state in
                ConnectionState(rawValue: state.rawValue) ?? .idle
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.stateSubj.send($0) }
            .store(in: &bag)
    }
}

extension BLEUseCaseImpl: BLEUseCase {
    // MARK: - BLEUseCase (Publishers)

    public var devicesPublisher: AnyPublisher<[Device], Never> { devicesSubj.eraseToAnyPublisher() }
    public var logsPublisher: AnyPublisher<[String], Never> { logsSubj.eraseToAnyPublisher() }
    public var isBluetoothOnPublisher: AnyPublisher<Bool, Never> { btOnSubj.eraseToAnyPublisher() }
    public var statePublisher: AnyPublisher<ConnectionState, Never> { stateSubj.eraseToAnyPublisher() }

    // MARK: - BLEUseCase (Commands)

    public func setTarget(serviceIds: [String]?, notifyIds: [String]?, writeIds: [String]?) {
        repository.configure(serviceIds: serviceIds, notifyIds: notifyIds, writeIds: writeIds)
    }

    public func startScan() {
        repository.startScanSmart()
    }

    public func startScanSmart() {
        repository.startScanSmart()
    }

    public func stopScan() {
        repository.stopScan()
    }

    public func connect(deviceId: UUID) {
        repository.connect(deviceId)
    }

    public func disconnect() {
        repository.disconnect()
    }

    public func send(text: String) {
        repository.send(text.data(using: .utf8)!)
    }

    public func clearLogs() {
        repository.clearLogs()
    }
}
