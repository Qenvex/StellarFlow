import Foundation

struct PhysicsCategory {
    static let none:        UInt32 = 0
    static let player:      UInt32 = 0x1 << 0
    static let planetCore:  UInt32 = 0x1 << 1
    static let planetField: UInt32 = 0x1 << 2
    static let meteor:      UInt32 = 0x1 << 3
    static let blackHole:   UInt32 = 0x1 << 4
    static let boundary:    UInt32 = 0x1 << 5
}
