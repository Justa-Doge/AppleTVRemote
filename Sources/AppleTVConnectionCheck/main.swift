import Foundation
import ItsytvCore

let requestedName = CommandLine.arguments.dropFirst().first
let manager = AppleTVManager()
let deadline = Date().addingTimeInterval(8)

manager.startScanning()

while Date() < deadline && manager.discoveredDevices.isEmpty {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}

guard let device = manager.discoveredDevices.first(where: { requestedName == nil || $0.name == requestedName }) else {
    fputs("Connection check failed: Apple TV was not discovered.\n", stderr)
    exit(1)
}

print("Discovered \(device.name) at \(device.host):\(device.port)")
manager.connect(to: device)

let connectionDeadline = Date().addingTimeInterval(12)
while Date() < connectionDeadline {
    switch manager.connectionStatus {
    case .connected:
        print("Connection check passed: authenticated Companion session is connected.")
        manager.disconnect()
        exit(0)
    case .error(let message):
        fputs("Connection check failed: \(message)\n", stderr)
        exit(1)
    default:
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}

fputs("Connection check failed: timed out while connecting.\n", stderr)
exit(1)
