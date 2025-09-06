import Combine
import CoreBluetooth
import Foundation

/// BLE接続に関する状態を表す
public enum BLEConnectionState: String {
    /// アイドル状態
    case idle
    /// スキャン中
    case scanning
    /// 接続処理中
    case connecting
    /// 接続確立済み
    case connected
    /// 切断処理中
    case disconnecting
    /// 切断完了
    case disconnected
    /// 端末のBluetooth電源OFF
    case bluetoothOff
}

/// CoreBluetooth をラップし、イベント（Event）と操作（Action）を束ねて公開するリポジトリ
/// アプリケーション層からは Publisher 経由で状態を購読し、明示的なメソッドで操作を指示する設計とする
public final class BLERespository: ObservableObject {
    /// BLE 接続状態のストリーム。最新値は CurrentValueSubject 相当で保持し、購読開始時に直近状態を配信する。
    public var statePublisher: AnyPublisher<BLEConnectionState, Never> { state.eraseToAnyPublisher() }
    /// 端末 Bluetooth 電源状態のストリーム。true なら poweredOn。
    public var isPoweredOnPublisher: AnyPublisher<Bool, Never> { isPoweredOn.eraseToAnyPublisher() }
    /// 発見済みデバイス一覧のストリーム。スキャン中は随時更新される。
    public var devicesPublisher: AnyPublisher<[DeviceInfo], Never> { devices.eraseToAnyPublisher() }
    /// 現在接続中のデバイス（存在しない場合は nil）のストリーム。
    public var connectedDevicePublisher: AnyPublisher<DeviceInfo?, Never> { connectedDevice.eraseToAnyPublisher() }
    /// 画面表示やデバッグ向けのログ配列ストリーム。時系列追記で配信する。
    public var logsPublisher: AnyPublisher<[String], Never> { logs.eraseToAnyPublisher() }

    private let state = CurrentValueSubject<BLEConnectionState, Never>(.idle)
    private let isPoweredOn = CurrentValueSubject<Bool, Never>(false)
    private let devices = CurrentValueSubject<[DeviceInfo], Never>([])
    private let connectedDevice = CurrentValueSubject<DeviceInfo?, Never>(nil)
    private let logs = CurrentValueSubject<[String], Never>([])

    private let event: BLEServiceEvent
    private let action: BLEServiceAction

    private var cancellables = Set<AnyCancellable>()
    private var indexById: [UUID: Int] = [:]
    private var notifyChars: [CBUUID: (peripheral: CBPeripheral, char: CBCharacteristic)] = [:]
    private var writeChars: [CBUUID: (peripheral: CBPeripheral, char: CBCharacteristic)] = [:]
    private let svcGenericAccess = CBUUID(string: "1800")
    private let charDeviceName = CBUUID(string: "2A00")
    private var targetServiceIds: [CBUUID]?
    private var targetNotifyCharIds: Set<CBUUID> = []
    private var targetWriteCharIds: Set<CBUUID> = []

    /// BLEService を内部生成し、イベント購読を開始する
    public init() {
        let service = BLEService()
        event = service
        action = service
        bind()
    }

    /// 操作対象となるサービス UUID / Notify 特性 UUID / Write 特性 UUID を設定する
    /// - Parameters:
    ///   - serviceIds: 探索対象サービスの UUID 文字列配列（nil または空で全サービス）
    ///   - notifyIds: 購読対象の特性 UUID
    ///   - writeIds: 書込み対象の特性 UUID
    /// 設定は次回のサービス・キャラクタリスティク探索に反映される
    public func configure(serviceIds: [String]?, notifyIds: [String]?, writeIds: [String]?) {
        targetServiceIds = serviceIds?.map { CBUUID(string: $0) }
        targetNotifyCharIds = Set((notifyIds ?? []).map { CBUUID(string: $0) })
        targetWriteCharIds = Set((writeIds ?? []).map { CBUUID(string: $0) })
        appendLog("Configured services=\(targetServiceIds?.map(\.uuidString).joined(separator: ",") ?? "nil"), " +
            "notify=\(targetNotifyCharIds.map(\.uuidString).joined(separator: ",")), " +
            "write=\(targetWriteCharIds.map(\.uuidString).joined(separator: ","))")
    }

    /// CoreBluetooth のイベント Publisher を購読し、内部状態へ反映する
    private func bind() {
        bindCentralState()
        bindDiscovery()
        bindConnect()
        bindDisconnect()
        bindServicesDiscovered()
        bindCharacteristicsDiscovered()
        bindValueUpdated()
        bindDidWrite()
    }

    // MARK: - Individual bindings

    private func bindCentralState() { event.centralStatePublisher
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state in
            guard let self else { return }
            let poweredOn = (state == .poweredOn)
            isPoweredOn.send(poweredOn)
            appendLog("Central State -> \(state.rawValue)")
            let next: BLEConnectionState = poweredOn
                ? (self.state.value == .bluetoothOff ? .idle : self.state.value)
                : .bluetoothOff
            self.state.send(next)
        }
        .store(in: &cancellables)
    }

    private func bindDiscovery() {
        event.discoveryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral, adv, rssi in
                guard let self else { return }
                let advName = (adv[CBAdvertisementDataLocalNameKey] as? String)
                let isConnectable = (adv[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
                let svcUUIDs = adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
                let mfg = adv[CBAdvertisementDataManufacturerDataKey] as? Data
                let info = DeviceInfo(
                    peripheral: peripheral,
                    name: advName ?? peripheral.name,
                    advServiceUUIDs: svcUUIDs,
                    manufacturerData: mfg,
                    rssi: rssi,
                    isConnectable: isConnectable,
                    lastSeen: Date()
                )

                if info.peripheral.state == .connected {
                    connectedDevice.send(info)
                }
                var list = devices.value
                if let idx = indexById[peripheral.identifier] {
                    let old = list[idx]
                    let updated = DeviceInfo(
                        peripheral: old.peripheral,
                        name: info.name ?? old.name,
                        advServiceUUIDs: info.advServiceUUIDs ?? old.advServiceUUIDs,
                        manufacturerData: info.manufacturerData ?? old.manufacturerData,
                        rssi: info.rssi,
                        isConnectable: info.isConnectable,
                        lastSeen: info.lastSeen
                    )
                    list[idx] = updated
                    devices.send(list)
                } else {
                    indexById[peripheral.identifier] = list.count
                    list.append(info)
                    devices.send(list)
                }
            }
            .store(in: &cancellables)
    }

    private func bindConnect() {
        event.connectPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral in
                guard let self else { return }
                var list = devices.value
                if let found = list.first(where: { $0.id == peripheral.identifier }) {
                    connectedDevice.send(found)
                } else {
                    let provisional = DeviceInfo(
                        peripheral: peripheral,
                        name: peripheral.name,
                        advServiceUUIDs: nil,
                        manufacturerData: nil,
                        rssi: 0,
                        isConnectable: true,
                        lastSeen: Date()
                    )
                    connectedDevice.send(provisional)
                    indexById[peripheral.identifier] = list.count
                    list.append(provisional)
                    devices.send(list)
                }

                notifyChars.removeAll()
                writeChars.removeAll()
                appendLog("Connected ✅ \(peripheral.name ?? "Unknown")")
                state.send(.connected)

                if let services = targetServiceIds, !services.isEmpty {
                    action.discoverServices(services + [svcGenericAccess], for: peripheral)
                } else {
                    action.discoverServices(nil, for: peripheral)
                }
            }
            .store(in: &cancellables)
    }

    private func bindDisconnect() {
        event.disconnectPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, error in
                guard let self else { return }
                appendLog("Disconnected 🔌 \(error?.localizedDescription ?? "normal")")
                connectedDevice.send(nil)
                notifyChars.removeAll()
                writeChars.removeAll()
                state.send(.disconnected)
            }
            .store(in: &cancellables)
    }

    private func bindServicesDiscovered() {
        event.servicesDiscoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral in
                guard let self, peripheral.identifier == self.connectedDevice.value?.id else { return }
                guard let services = peripheral.services, !services.isEmpty else {
                    appendLog("Services empty -> retry discover all")
                    action.discoverServices(nil, for: peripheral)
                    return
                }
                if let service = services.first(where: { $0.uuid == self.svcGenericAccess }) {
                    action.discoverCharacteristics([charDeviceName], for: service, peripheral: peripheral)
                }
                if let targetServices = targetServiceIds, !targetServices.isEmpty {
                    services.filter { targetServices.contains($0.uuid) }.forEach {
                        self.action.discoverCharacteristics(nil, for: $0, peripheral: peripheral)
                    }
                } else {
                    services.forEach { self.action.discoverCharacteristics(nil, for: $0, peripheral: peripheral) }
                }
            }
            .store(in: &cancellables)
    }

    private func bindCharacteristicsDiscovered() {
        event.characteristicsDiscoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral, service in
                guard let self else { return }
                if service.uuid == svcGenericAccess,
                   let characteristic = service.characteristics?.first(where: { $0.uuid == self.charDeviceName })
                {
                    action.read(characteristic, peripheral: peripheral)
                    return
                }

                for characteristic in service.characteristics ?? [] {
                    if characteristic.properties.contains(.notify) {
                        let passes = targetNotifyCharIds.isEmpty || targetNotifyCharIds
                            .contains(characteristic.uuid)
                        if passes, notifyChars[characteristic.uuid] == nil {
                            notifyChars[characteristic.uuid] = (peripheral, characteristic)
                            appendLog(
                                "Subscribe notify -> \(service.uuid.uuidString)/\(characteristic.uuid.uuidString)"
                            )
                            action.setNotify(true, for: characteristic, peripheral: peripheral)
                        }
                    }
                    if characteristic.properties.contains(.write) || characteristic.properties
                        .contains(.writeWithoutResponse)
                    {
                        let passes = targetWriteCharIds.isEmpty || targetWriteCharIds
                            .contains(characteristic.uuid)
                        if passes, writeChars[characteristic.uuid] == nil {
                            writeChars[characteristic.uuid] = (peripheral, characteristic)
                            appendLog("write uuid -> \(service.uuid.uuidString)/\(characteristic.uuid.uuidString)")
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func bindValueUpdated() {
        event.valueUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral, characteristic, data in
                guard let self,
                      peripheral.identifier == self.connectedDevice.value?.id else { return }

                if notifyChars[characteristic.uuid] != nil, let data {
                    appendLog("Notify[\(characteristic.uuid.uuidString)] \(data.count)B: \(data as NSData)")
                } else if characteristic.uuid == charDeviceName, let data, let name = String(
                    data: data,
                    encoding: .utf8
                ) {
                    if let idx = indexById[peripheral.identifier] {
                        var list = devices.value
                        let old = list[idx]
                        let updated = DeviceInfo(
                            peripheral: old.peripheral,
                            name: name,
                            advServiceUUIDs: old.advServiceUUIDs,
                            manufacturerData: old.manufacturerData,
                            rssi: old.rssi,
                            isConnectable: old.isConnectable,
                            lastSeen: old.lastSeen
                        )
                        list[idx] = updated
                        devices.send(list)
                    }
                    appendLog("DeviceName: \(name)")
                }
            }
            .store(in: &cancellables)
    }

    private func bindDidWrite() {
        event.didWritePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, characteristic, error in
                guard let self else { return }
                if let error {
                    appendLog("Write ERROR [\(characteristic.uuid.uuidString)]: \(error.localizedDescription)")
                } else { appendLog("Write OK [\(characteristic.uuid.uuidString)]") }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// スキャンを開始する。必要に応じてサービス UUID フィルタを適用する
    /// - Parameter allowDuplicates: 同一デバイスの重複通知を許可するか
    public func startScan(allowDuplicates: Bool = true) {
        guard isPoweredOn.value else { return }
        indexById.removeAll()
        devices.send([])
        state.send(.scanning)

        appendLog("Start Scan \(targetServiceIds?.map(\.uuidString).joined(separator: ",") ?? "[All]")")
        action.startScan(with: targetServiceIds, allowDuplicates: allowDuplicates)
    }

    /// フィルタ付きでスキャンを試行し、所定時間でヒットがなければ無フィルタにフォールバックするスマートスキャンを実行する
    /// - Parameters:
    ///   - timeout: フィルタで結果が出ない場合に無フィルタへ切り替えるまでの秒数
    ///   - allowDuplicates: 同一デバイスの重複通知を許可するか
    public func startScanSmart(timeout: TimeInterval = 3.0, allowDuplicates: Bool = false) {
        guard isPoweredOn.value else { return }
        indexById.removeAll()
        devices.send([])
        state.send(.scanning)

        // 現在の設定フィルタ
        let filter = targetServiceIds
        appendLog("Start Scan (primary) \(filter?.map(\.uuidString).joined(separator: ",") ?? "[All]")")
        action.startScan(with: filter, allowDuplicates: allowDuplicates)

        // 一定時間で何も見つからなければ無フィルタにフォールバック
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self else { return }
            if devices.value.isEmpty, state.value == .scanning {
                appendLog("No result with filter -> fallback to unfiltered scan")
                action.stopScan()
                action.startScan(with: nil, allowDuplicates: allowDuplicates)
            }
        }
    }

    /// スキャンを停止し、状態を idle に戻す
    public func stopScan() {
        action.stopScan()
        if state.value == .scanning {
            state.send(.idle)
        }
        appendLog("Stop Scan")
    }

    /// 指定 UUID のデバイスへ接続を試行する。該当デバイスが内部一覧に存在しない場合は何も行わない
    /// - Parameter uuid: デバイスの識別子（CBPeripheral.identifier）
    public func connect(_ uuid: UUID) {
        guard let device = devices.value.first(where: { $0.id == uuid }) else {
            stopScan()
            return
        }
        stopScan()
        state.send(.connecting)
        appendLog("Connect -> \(device.name ?? "Unknown")")
        action.connect(device.peripheral)
    }

    /// 現在接続中のデバイスを切断する、接続が存在しない場合は何も行わない
    public func disconnect() {
        guard let peripheral = connectedDevice.value?.peripheral else { return }
        state.send(.disconnecting)
        appendLog("Disconnect -> \(peripheral.name ?? "Unknown")")
        action.cancel(peripheral)
    }

    /// 内部に保持しているログを全消去する、画面表示のリセットやテスト時に利用する
    public func clearLogs() {
        logs.send([])
    }

    /// Write 特性へ任意データを書き込む。対象特性は UUID で指定し、省略時は最初に検出した書込み特性を用いる
    /// - Parameters:
    ///   - data: 書込みデータ
    ///   - writeId: 対象特性の UUID（省略時は自動選択）
    ///   - withoutResponse: 書込みモードの明示。nil の場合は特性の Capabilities から自動選択
    public func send(_ data: Data, to writeId: String? = nil, withoutResponse: Bool? = nil) {
        // ターゲット解決：指定UUID → 最初のwrite
        let pair: (CBPeripheral, CBCharacteristic)? = if let writeId {
            writeChars[CBUUID(string: writeId)].map { ($0.peripheral, $0.char) }
        } else {
            writeChars.values.first.map { ($0.peripheral, $0.char) }
        }

        guard let (peripheral, characteristic) = pair else {
            appendLog("Write skipped: no writable characteristic\(writeId != nil ? " for \(writeId!)" : "")")
            return
        }

        let chosenType: CBCharacteristicWriteType = {
            if let preferWoRsp = withoutResponse { return preferWoRsp ? .withoutResponse : .withResponse }
            if characteristic.properties.contains(.write) { return .withResponse }
            return .withoutResponse
        }()

        action.write(data, to: characteristic, type: chosenType, peripheral: peripheral)
        appendLog(
            "Write(\(chosenType == .withResponse ? "withRsp" : "woRsp")) [\(characteristic.uuid.uuidString)]: \(data as NSData)"
        )
    }

    /// 代表の Write 特性へダミーデータを書き込む、明示設定があればその特性を優先する
    public func writeDummy(_ data: Data) {
        if let id = targetWriteCharIds.first {
            send(data, to: id.uuidString)
        } else {
            send(data)
        }
    }

    // MARK: - Log

    /// ログ配列に追記し、購読者へ配信する時刻プレフィックスを付与する
    private func appendLog(_ line: String) {
        var arr = logs.value
        arr.append("[\(dateToTime(date: Date()))] \(line)")
        logs.send(arr)
        print(line)
    }

    /// 時刻を HH:mm:ss.SSS 形式の文字列にフォーマットするユーティリティ
    private func dateToTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
