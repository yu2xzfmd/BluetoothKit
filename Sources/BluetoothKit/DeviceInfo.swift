import CoreBluetooth
import Foundation

/// Bluetoothデバイスの情報を保持する構造体
public struct DeviceInfo: Identifiable, Hashable {
    /// デバイスを一意に識別する UUID
    public let id: UUID
    /// CoreBluetooth のペリフェラルオブジェクト
    public let peripheral: CBPeripheral
    /// デバイス名（広告データまたは接続から取得）
    public let name: String?
    /// 広告に含まれるサービス UUID の一覧
    public let advServiceUUIDs: [CBUUID]?
    /// 広告に含まれるメーカー固有データ
    public let manufacturerData: Data?
    /// 受信信号強度 (RSSI)
    public let rssi: NSNumber
    /// 接続可能かどうか
    public let isConnectable: Bool
    /// 最後に検出された時刻
    public let lastSeen: Date

    /// 初期化
    public init(
        peripheral: CBPeripheral,
        name: String?,
        advServiceUUIDs: [CBUUID]? = nil,
        manufacturerData: Data? = nil,
        rssi: NSNumber,
        isConnectable: Bool?,
        lastSeen: Date
    ) {
        id = peripheral.identifier
        self.peripheral = peripheral
        self.name = name
        self.advServiceUUIDs = advServiceUUIDs
        self.manufacturerData = manufacturerData
        self.rssi = rssi
        self.isConnectable = isConnectable ?? false
        self.lastSeen = lastSeen
    }
}
