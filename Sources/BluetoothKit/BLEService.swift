import Combine
import CoreBluetooth
import Foundation

// MARK: - Implementation

/// BLEServiceクラス
/// Bluetooth Low Energy通信の中心的な役割を担うサービスクラス
/// ビジネス用途のアプリ開発において、BLEデバイスとの接続やデータ送受信、イベント管理を一元的に担当する
final class BLEService: NSObject {
    /// CBCentralManagerインスタンス
    private var central: CBCentralManager?
    /// BLE処理専用のディスパッチキュー。UI操作と分離し、パフォーマンスと安全性を確保する
    private let bleQueue = DispatchQueue(label: "BLE.queue", qos: .userInitiated)
    /// CBCentralManagerの状態変化イベントを通知するパブリッシャ
    private let centralState = PassthroughSubject<CBManagerState, Never>()
    /// BLEデバイス発見時のイベントを通知するパブリッシャ
    private let discovered = PassthroughSubject<(CBPeripheral, [String: Any], NSNumber), Never>()
    /// デバイス接続成功時のイベントを通知するパブリッシャ
    private let connected = PassthroughSubject<CBPeripheral, Never>()
    /// デバイス切断時のイベントを通知するパブリッシャ
    private let disconnected = PassthroughSubject<(CBPeripheral, Error?), Never>()
    /// サービス発見時のイベントを通知するパブリッシャ
    private let servicesDiscovered = PassthroughSubject<CBPeripheral, Never>()
    /// キャラクタリスティック発見時のイベントを通知するパブリッシャ
    private let characteristicsDiscovered = PassthroughSubject<(CBPeripheral, CBService), Never>()
    /// キャラクタリスティック値更新時のイベントを通知するパブリッシャ
    private let valueUpdated = PassthroughSubject<(CBPeripheral, CBCharacteristic, Data?), Never>()
    /// 書き込み完了時のイベントを通知するパブリッシャ
    private let didWrite = PassthroughSubject<(CBPeripheral, CBCharacteristic, Error?), Never>()

    /// CBCentralManagerを初期化し、BLEイベントのデリゲートを自身に設定する
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: bleQueue)
    }
}

/// BLEServiceEventプロトコルの実装
/// 各種BLEイベントのパブリッシャを外部へ公開する
extension BLEService: BLEServiceEvent {
    /// CBCentralManagerの状態変化を購読するためのパブリッシャ
    var centralStatePublisher: AnyPublisher<CBManagerState, Never> { centralState.eraseToAnyPublisher() }
    /// デバイス発見イベントを購読するためのパブリッシャ
    var discoveryPublisher: AnyPublisher<(CBPeripheral, [String: Any], NSNumber), Never> {
        discovered.eraseToAnyPublisher()
    }

    /// 接続成功イベントを購読するためのパブリッシャ
    var connectPublisher: AnyPublisher<CBPeripheral, Never> { connected.eraseToAnyPublisher() }
    /// 切断イベントを購読するためのパブリッシャ
    var disconnectPublisher: AnyPublisher<(CBPeripheral, Error?), Never> { disconnected.eraseToAnyPublisher() }
    /// サービス発見イベントを購読するためのパブリッシャ
    var servicesDiscoveredPublisher: AnyPublisher<CBPeripheral, Never> { servicesDiscovered.eraseToAnyPublisher() }
    /// キャラクタリスティック発見イベントを購読するためのパブリッシャ
    var characteristicsDiscoveredPublisher: AnyPublisher<(CBPeripheral, CBService), Never> {
        characteristicsDiscovered.eraseToAnyPublisher()
    }

    /// 値更新イベントを購読するためのパブリッシャ
    var valueUpdatedPublisher: AnyPublisher<(CBPeripheral, CBCharacteristic, Data?), Never> {
        valueUpdated.eraseToAnyPublisher()
    }

    /// 書き込み完了イベントを購読するためのパブリッシャ
    var didWritePublisher: AnyPublisher<(CBPeripheral, CBCharacteristic, Error?), Never> {
        didWrite.eraseToAnyPublisher()
    }
}

/// BLEServiceActionプロトコルの実装
/// 各種BLE操作（スキャン、接続、サービス・キャラクタリスティック探索、通知設定、読み書き）を提供する
extension BLEService: BLEServiceAction {
    /// BLEデバイスのスキャンを開始する
    /// - Parameter services: 検索対象のサービスUUID配列。nilの場合は全デバイス対象
    /// - Parameter allowDuplicates: 重複発見を許可するかどうか
    func startScan(with services: [CBUUID]?, allowDuplicates: Bool) {
        guard central?.state == .poweredOn else { return }
        central?.scanForPeripherals(
            withServices: services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        )
    }

    /// スキャンを停止する
    func stopScan() { central?.stopScan() }

    /// 指定したペリフェラルと接続する
    /// - Parameter peripheral: 接続対象のCBPeripheral
    func connect(_ peripheral: CBPeripheral) { central?.connect(peripheral, options: nil) }

    /// 指定したペリフェラルとの接続をキャンセルする
    /// - Parameter peripheral: 切断対象のCBPeripheral
    func cancel(_ peripheral: CBPeripheral) { central?.cancelPeripheralConnection(peripheral) }

    /// サービス探索を開始する
    /// - Parameter services: 探索対象サービスUUID配列
    /// - Parameter peripheral: 対象のCBPeripheral
    func discoverServices(_ services: [CBUUID]?, for peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(services)
    }

    /// キャラクタリスティック探索を開始する
    /// - Parameter characteristics: 探索対象キャラクタリスティックUUID配列
    /// - Parameter service: 対象のCBService
    /// - Parameter peripheral: 対象のCBPeripheral
    func discoverCharacteristics(_ characteristics: [CBUUID]?, for service: CBService, peripheral: CBPeripheral) {
        peripheral.discoverCharacteristics(characteristics, for: service)
    }

    /// 通知設定を有効または無効にする
    /// - Parameter enabled: 通知を有効にする場合はtrue
    /// - Parameter characteristic: 対象キャラクタリスティック
    /// - Parameter peripheral: 対象のCBPeripheral
    func setNotify(_ enabled: Bool, for characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        peripheral.setNotifyValue(enabled, for: characteristic)
    }

    /// キャラクタリスティックの値を読み取る
    /// - Parameter characteristic: 対象キャラクタリスティック
    /// - Parameter peripheral: 対象のCBPeripheral
    func read(_ characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        peripheral.readValue(for: characteristic)
    }

    /// キャラクタリスティックに値を書き込む
    /// - Parameter data: 書き込むデータ
    /// - Parameter characteristic: 対象キャラクタリスティック
    /// - Parameter type: 書き込みタイプ
    /// - Parameter peripheral: 対象のCBPeripheral
    func write(
        _ data: Data,
        to characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType,
        peripheral: CBPeripheral
    ) {
        peripheral.writeValue(data, for: characteristic, type: type)
    }
}

// MARK: - Delegates

/// CBCentralManagerDelegateの実装
/// BLE通信に関するシステムイベントを受け取り、パブリッシャへ通知する
extension BLEService: CBCentralManagerDelegate {
    /// CBCentralManagerの状態が変化した時に呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState.send(central.state)
    }

    /// デバイス発見時に呼ばれる
    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discovered.send((peripheral, advertisementData, RSSI))
    }

    /// デバイス接続成功時に呼ばれる
    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        connected.send(peripheral)
    }

    /// デバイス切断時に呼ばれる
    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        disconnected.send((peripheral, error))
    }
}

/// CBPeripheralDelegateの実装
/// ペリフェラルとのサービス・キャラクタリスティック発見や値変更などのイベントを受け取り、パブリッシャへ通知する
extension BLEService: CBPeripheralDelegate {
    /// サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        servicesDiscovered.send(peripheral)
    }

    /// キャラクタリスティック発見時に呼ばれる
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        characteristicsDiscovered.send((peripheral, service))
    }

    /// キャラクタリスティック値更新時に呼ばれる
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error _: Error?
    ) {
        valueUpdated.send((peripheral, characteristic, characteristic.value))
    }

    /// キャラクタリスティックへの書き込み完了時に呼ばれる
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        didWrite.send((peripheral, characteristic, error))
    }
}
