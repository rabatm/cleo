import Foundation
import Darwin.Mach

/// Lit la charge CPU globale via l'API Mach, lissée sur quelques échantillons.
/// Appelée uniquement depuis le thread principal (timer du runloop).
final class CPUProvider: ObservableObject {
    @Published private(set) var usage: Double = 0 // 0.0 ... 1.0

    private var previous: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func sample() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }
        let result = host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var user: UInt64 = 0, system: UInt64 = 0, idle: UInt64 = 0, nice: UInt64 = 0
        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            user   += UInt64(info[base + Int(CPU_STATE_USER)])
            system += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            idle   += UInt64(info[base + Int(CPU_STATE_IDLE)])
            nice   += UInt64(info[base + Int(CPU_STATE_NICE)])
        }

        guard let prev = previous else {
            previous = (user, system, idle, nice)
            return
        }
        previous = (user, system, idle, nice)

        let dUser = user &- prev.user
        let dSystem = system &- prev.system
        let dIdle = idle &- prev.idle
        let dNice = nice &- prev.nice
        let total = dUser &+ dSystem &+ dIdle &+ dNice
        guard total > 0 else { return }

        let instant = Double(dUser &+ dSystem &+ dNice) / Double(total)
        usage = usage * 0.6 + instant * 0.4 // lissage exponentiel (~2 s)
    }
}
