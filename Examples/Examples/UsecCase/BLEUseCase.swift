//
import Combine

//  Untitled.swift
//  Examples
//
import Foundation

public protocol BLEUseCase: AnyObject {
    var devicesPublisher: AnyPublisher<[Device], Never> { get }
    var logsPublisher: AnyPublisher<[String], Never> { get }
    var isBluetoothOnPublisher: AnyPublisher<Bool, Never> { get }
    var statePublisher: AnyPublisher<ConnectionState, Never> { get }

    func startScan()
    func startScanSmart()
    func stopScan()
    func connect(deviceId: UUID)
    func disconnect()
    func send(text: String)
    func clearLogs()
}

public enum ConnectionState: String {
    case idle, scanning, connecting, connected, disconnecting, disconnected, bluetoothOff
}
