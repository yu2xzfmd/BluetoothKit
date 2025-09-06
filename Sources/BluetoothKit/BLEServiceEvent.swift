import Combine
import CoreBluetooth

// CoreBluetooth のイベントをCombine Publisherとして公開する役割を持つ
protocol BLEServiceEvent: AnyObject {
    /// Bluetooth状態の更新イベント
    var centralStatePublisher: AnyPublisher<CBManagerState, Never> { get }
    /// ペリフェラル検出イベント
    var discoveryPublisher: AnyPublisher<(CBPeripheral, [String: Any], NSNumber), Never> { get }
    /// 接続成功イベント
    var connectPublisher: AnyPublisher<CBPeripheral, Never> { get }
    /// 切断イベント
    var disconnectPublisher: AnyPublisher<(CBPeripheral, Error?), Never> { get }
    /// サービス探索完了イベント
    var servicesDiscoveredPublisher: AnyPublisher<CBPeripheral, Never> { get }
    /// キャラクタリスティック探索完了イベント
    var characteristicsDiscoveredPublisher: AnyPublisher<(CBPeripheral, CBService), Never> { get }
    /// 値更新イベント
    var valueUpdatedPublisher: AnyPublisher<(CBPeripheral, CBCharacteristic, Data?), Never> { get }
    /// 書き込み完了イベント
    var didWritePublisher: AnyPublisher<(CBPeripheral, CBCharacteristic, Error?), Never> { get }
}
