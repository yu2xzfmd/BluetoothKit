//
//  Device.swift
//  Examples
//
import Foundation

public struct Device: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var manufacturerData: Data?
    public var rssi: Int
    public var isConnected: Bool
}
