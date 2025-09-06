# BluetoothKit

Swift / iOS / macOS 向けの Bluetooth Low Energy (BLE) ライブラリ。  

---

## Features

- [x] Combine Publisher ベースのイベント購読
- [x] `Repository` による状態管理（スキャン / 接続 / 通知 / 書き込み）
- [x] 複数 Notify/Write characteristic に対応

---

## Requirements

- iOS 15.0+
- macOS 10.15+
- Swift 5.9+
- Xcode 15+

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yu2xzfmd/BluetoothKit.git", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'BluetoothKit', :git => 'https://github.com/yu2xzfmd/BluetoothKit.git'
```

---

## Usage

```swift
import BluetoothKit
import Combine

class BLEManager {
    private var repository = BLERespository()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to discovered devices
        repository.devicesPublisher
            .sink { devices in
                print("Discovered devices: \(devices)")
            }
            .store(in: &cancellables)

        // Subscribe to logs
        repository.logsPublisher
            .sink { log in
                print("Log: \(log)")
            }
            .store(in: &cancellables)
    }

    func startScanning() {
        repository.startScan()
    }

    func connectToDevice(_ device: BLEDevice) {
        repository.connect(device: device) { result in
            switch result {
            case .success:
                print("Connected to \(device.name)")
                // Example: write data after connection
                let demoData = Data([0x01, 0x02, 0x03])
                repository.write(data: demoData, to: device)
            case .failure(let error):
                print("Connection failed: \(error)")
            }
        }
    }
}
```

---

## Examples

`Examples/` 以下に SwiftUI のサンプルアプリを同梱。

- 接続/切断
- Notify/Write のログ表示

---

## Xcode 設定メモ

- Build Settings → `User Script Sandboxing` → **OFF**
- `Info.plist` に以下を追加:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>{Discription}"</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## License

BluetoothKit is released under the MIT License. See [LICENSE](LICENSE) for details.
