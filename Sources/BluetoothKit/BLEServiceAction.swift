import CoreBluetooth

// CoreBluetooth の低レベル操作を抽象化する役割を持つ
protocol BLEServiceAction: AnyObject {
    /// サービスUUID指定のスキャン開始
    func startScan(with services: [CBUUID]?, allowDuplicates: Bool)
    /// スキャン停止
    func stopScan()
    /// 指定ペリフェラルへの接続
    func connect(_ peripheral: CBPeripheral)
    /// 接続キャンセル
    func cancel(_ peripheral: CBPeripheral)
    /// サービス探索
    func discoverServices(_ services: [CBUUID]?, for peripheral: CBPeripheral)
    /// キャラクタリスティック探索
    func discoverCharacteristics(_ characteristics: [CBUUID]?, for service: CBService, peripheral: CBPeripheral)
    /// 通知有効化/無効化
    func setNotify(_ enabled: Bool, for characteristic: CBCharacteristic, peripheral: CBPeripheral)
    /// キャラクタリスティックの値読み出し
    func read(_ characteristic: CBCharacteristic, peripheral: CBPeripheral)
    /// キャラクタリスティックへの書き込み
    func write(
        _ data: Data,
        to characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType,
        peripheral: CBPeripheral
    )
}
