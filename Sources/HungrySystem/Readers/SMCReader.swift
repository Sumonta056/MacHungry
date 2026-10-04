import Darwin
import IOKit

struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPowerLimit {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpu: UInt32 = 0
    var gpu: UInt32 = 0
    var memory: UInt32 = 0
}

struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var attributes: UInt8 = 0
    var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

struct SMCParam {
    var key: UInt32 = 0
    var version = SMCVersion()
    var powerLimit = SMCPowerLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var command: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

public final class SMCReader {
    static let expectedParamSize = 80
    private static let selector: UInt32 = 2
    private static let readKeyCommand: UInt8 = 5
    private static let keyInfoCommand: UInt8 = 9
    private static let floatType = fourCharCode("flt ")

    private let connection: io_connect_t

    public init?() {
        guard MemoryLayout<SMCParam>.stride == Self.expectedParamSize else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var opened: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &opened) == KERN_SUCCESS else { return nil }
        connection = opened
    }

    deinit {
        IOServiceClose(connection)
    }

    public func floatKeys(from candidates: [String]) -> [String] {
        candidates.filter { keyInfo(for: $0).map(Self.isFloat) ?? false }
    }

    public func value(of key: String) -> Double? {
        guard let info = keyInfo(for: key), Self.isFloat(info) else { return nil }
        var input = SMCParam()
        input.key = Self.fourCharCode(key)
        input.keyInfo.dataSize = info.dataSize
        input.command = Self.readKeyCommand
        guard let output = call(&input) else { return nil }
        let bytes = output.bytes
        let bits = UInt32(bytes.0) | UInt32(bytes.1) << 8 | UInt32(bytes.2) << 16 | UInt32(bytes.3) << 24
        return Double(Float(bitPattern: bits))
    }

    private func keyInfo(for key: String) -> SMCKeyInfo? {
        var input = SMCParam()
        input.key = Self.fourCharCode(key)
        input.command = Self.keyInfoCommand
        return call(&input)?.keyInfo
    }

    private func call(_ input: inout SMCParam) -> SMCParam? {
        var output = SMCParam()
        var outputSize = MemoryLayout<SMCParam>.stride
        let result = IOConnectCallStructMethod(connection, Self.selector, &input, MemoryLayout<SMCParam>.stride, &output, &outputSize)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    private static func isFloat(_ info: SMCKeyInfo) -> Bool {
        info.dataType == floatType && info.dataSize == 4
    }

    static func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}
