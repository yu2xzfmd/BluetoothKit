Pod::Spec.new do |s|
  s.name             = 'BluetoothKit'
  s.version          = '0.1.0'
  s.summary          = 'BLE 制御用のフレームワーク'
  s.description      = 'CoreBluetooth をラップし、スキャン/接続/通知購読/書き込みを簡潔に扱う'
  s.homepage         = 'https://github.com/yu2xzfmd/BluetoothKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yu2xzfmd' => 'you@example.com' }
  s.source           = { :git => 'https://github.com/yu2xzfmd/BluetoothKit.git', :tag => s.version.to_s }
  s.swift_version    = '5.9'
  s.platform         = :ios, '15.0'
  s.source_files     = 'Sources/**/*.{swift}'
  s.frameworks       = 'CoreBluetooth'
  s.module_name      = 'BluetoothKit'
end
