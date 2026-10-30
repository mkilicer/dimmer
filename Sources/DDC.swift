import Foundation
import IOKit

// DDC/CI over the private IOAVService API (Apple Silicon). Same approach as m1ddc and MonitorControl.
typealias IOAVService = CFTypeRef

@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<IOAVService>?

@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: IOAVService, _ chip: UInt32, _ offset: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: IOAVService, _ chip: UInt32, _ address: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

enum VCP: UInt8 {
    case brightness = 0x10
    case contrast = 0x12
}

final class DDC {
    private let service: IOAVService

    private init(service: IOAVService) { self.service = service }

    /// First external display that has an AV service. The Mac mini has no built-in panel, so this is the monitor.
    static func external() -> DDC? {
        guard let matching = IOServiceMatching("DCPAVServiceProxy") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard location == "External", let av = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() else { continue }
            return DDC(service: av)
        }
        return nil
    }

    func write(_ vcp: VCP, _ value: UInt16) -> Bool {
        var data: [UInt8] = [0x84, 0x03, vcp.rawValue, UInt8(value >> 8), UInt8(value & 0xFF), 0]
        data[5] = data[0..<5].reduce(0x6E ^ 0x51, ^)
        // Monitors drop packets now and then; two writes is what MonitorControl settled on.
        var ok = false
        for _ in 0..<2 {
            usleep(10_000)
            ok = IOAVServiceWriteI2C(service, 0x37, 0x51, &data, UInt32(data.count)) == kIOReturnSuccess || ok
        }
        return ok
    }

    /// Returns (current, max), or nil when the monitor does not answer.
    func read(_ vcp: VCP) -> (current: UInt16, max: UInt16)? {
        var request: [UInt8] = [0x82, 0x01, vcp.rawValue, 0]
        request[3] = request[0..<3].reduce(0x6E ^ 0x51, ^)
        for _ in 0..<3 {
            var reply = [UInt8](repeating: 0, count: 12)
            usleep(10_000)
            guard IOAVServiceWriteI2C(service, 0x37, 0x51, &request, UInt32(request.count)) == kIOReturnSuccess else { continue }
            usleep(50_000)
            guard IOAVServiceReadI2C(service, 0x37, 0x51, &reply, UInt32(reply.count)) == kIOReturnSuccess else { continue }
            let checksum = reply[0..<11].reduce(0x50, ^)
            guard reply[2] == 0x02, reply[3] == 0x00, reply[4] == vcp.rawValue, checksum == reply[11] else { continue }
            return (UInt16(reply[8]) << 8 | UInt16(reply[9]), UInt16(reply[6]) << 8 | UInt16(reply[7]))
        }
        return nil
    }
}
