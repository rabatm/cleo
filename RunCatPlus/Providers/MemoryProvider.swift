import Foundation
import Darwin

enum MemoryPressure: Int, CaseIterable {
    case normal, warning, critical, unknown

    var color: String {
        switch self {
        case .normal: return "normal"
        case .warning: return "warning"
        case .critical: return "critical"
        case .unknown: return "unknown"
        }
    }
}

struct MemorySnapshot {
    var usedFraction: Double = 0   // 0.0 ... 1.0 (active + wired + compressées) / total
    var usedGB: Double = 0
    var totalGB: Double = 0
    var swapUsedMB: Double = 0
    var pressure: MemoryPressure = .unknown
}

/// Pression mémoire (niveau système) + quantités via host_statistics64.
/// Le DispatchSource est sur la queue principale et sample() n'est appelé
/// que depuis le thread principal.
final class MemoryProvider: ObservableObject {
    @Published private(set) var snapshot = MemorySnapshot()
    private var pressureSource: DispatchSourceMemoryPressure?

    init() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: .main)
        source.setEventHandler { [weak self] in
            let mask = source.data
            if mask.contains(.critical) {
                self?.snapshot.pressure = .critical
            } else if mask.contains(.warning) {
                self?.snapshot.pressure = .warning
            }
        }
        source.resume()
        pressureSource = source
    }

    deinit {
        pressureSource?.cancel()
    }

    func sample() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride
                                           / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        var totalBytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)

        let pageSize = UInt64(getpagesize())
        let used = UInt64(stats.active_count) + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        let totalPages = totalBytes / pageSize

        var newSnapshot = snapshot
        newSnapshot.totalGB = Double(totalBytes) / 1e9
        newSnapshot.usedGB = Double(used) * Double(pageSize) / 1e9
        newSnapshot.usedFraction = totalPages > 0 ? Double(used) / Double(totalPages) : 0
        newSnapshot.swapUsedMB = Self.readSwapUsedMB()
        // On réinitialise à normal à chaque sample : DispatchSource ne signale
        // que les montées en pression, jamais les retours à la normale.
        newSnapshot.pressure = .normal
        snapshot = newSnapshot
    }

    private static func readSwapUsedMB() -> Double {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let kr = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(usage.xsu_used) / 1e6
    }
}
