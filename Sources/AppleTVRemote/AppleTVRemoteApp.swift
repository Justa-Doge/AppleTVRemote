import AppKit
import ItsytvCore
import SwiftUI

@main
struct AppleTVRemoteApp: App {
    @State private var manager = AppleTVManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
                .frame(width: 520, height: 700)
                .tint(.blue)
        }
        .defaultSize(width: 520, height: 700)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Apple TVs") {
                    manager.refreshScanning()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

struct ContentView: View {
    @Environment(AppleTVManager.self) private var manager
    @State private var pin = ""
    @State private var keyMonitor: Any?
    @State private var remoteText = ""
    @State private var keyboardBarVisible = false
    @FocusState private var keyboardFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 22) {
                    deviceSection
                    statusSection

                    if keyboardBarVisible && manager.connectionStatus == .connected {
                        keyboardInputSection
                    }

                    if manager.connectionStatus == .connected {
                        RemoteView()
                    } else if manager.connectionStatus == .pairing {
                        PairingView(pin: $pin, submit: submitPIN)
                    }
                }
                .padding(24)
            }
        }
        .background(.regularMaterial)
        .onAppear {
            manager.startScanning()
            installKeyboardMonitor()
            DispatchQueue.main.async {
                NSApp.keyWindow?.setContentSize(NSSize(width: 520, height: 700))
            }
        }
        .onDisappear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            manager.stopScanning()
        }
        .onChange(of: manager.keyboardFocused) { _, focused in
            if focused {
                remoteText = ""
                keyboardBarVisible = true
                keyboardFieldFocused = true
            } else {
                keyboardFieldFocused = false
                manager.resetTextInputState()
            }
        }
        .onChange(of: manager.connectionStatus) { _, status in
            if status != .connected {
                keyboardBarVisible = false
                keyboardFieldFocused = false
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "appletv.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text("Apple TV Remote")
                    .font(.title2.weight(.semibold))
                Text("Local network control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                manager.refreshScanning()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh Apple TV discovery")
        }
        .padding(20)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Apple TVs on this network", systemImage: "appletv")
                    .font(.headline)
                Spacer()
                if manager.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if manager.discoveredDevices.isEmpty {
                Text("No Apple TVs found yet. Make sure the Apple TV is awake and on the same Wi-Fi network.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(manager.discoveredDevices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "appletv.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.body.weight(.medium))
                            Text(device.modelName ?? "Apple TV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Wake") {
                            manager.wakeAppleTV()
                        }
                        .buttonStyle(.bordered)
                        .disabled(manager.connectionStatus == .connecting || manager.connectionStatus == .pairing)
                        Button("Connect") {
                            pin = ""
                            manager.connect(to: device)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manager.connectionStatus == .connecting || manager.connectionStatus == .pairing)
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if manager.connectionStatus == .connected {
                Button("Disconnect") { manager.disconnect() }
                    .buttonStyle(.link)
            }
        }
    }

    private var statusColor: Color {
        switch manager.connectionStatus {
        case .connected: .green
        case .error: .red
        case .connecting, .pairing: .orange
        case .disconnected: .secondary
        }
    }

    private var statusText: String {
        switch manager.connectionStatus {
        case .disconnected: "Not connected"
        case .connecting: "Connecting…"
        case .pairing: "Waiting for Apple TV pairing PIN"
        case .connected: "Connected to \(manager.connectedDeviceName ?? "Apple TV")"
        case .error(let message): message
        }
    }

    private var keyboardInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Apple TV keyboard", systemImage: "keyboard")
                .font(.headline)
            HStack(spacing: 8) {
                TextField("Type on Apple TV…", text: $remoteText)
                    .textFieldStyle(.roundedBorder)
                    .focused($keyboardFieldFocused)
                    .onChange(of: remoteText) { _, value in
                        manager.updateRemoteText(value)
                    }
                    .onSubmit {
                        endKeyboardInput()
                    }

                .onExitCommand {
                    endKeyboardInput()
                }

                Button("Done") {
                    keyboardFieldFocused = false
                }
                .buttonStyle(.bordered)
            }
            Text("Typing here sends text to the focused field on the Apple TV.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func submitPIN() {
        guard pin.count == 4 else { return }
        manager.submitPIN(pin)
    }

    private func endKeyboardInput() {
        keyboardFieldFocused = false
        manager.endTextInput()
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard manager.connectionStatus == .connected,
                  !event.modifierFlags.contains(.control),
                  !(event.modifierFlags.contains(.option) && event.keyCode != 48)
            else { return event }

            // Option-Tab matches a double-click of the Apple TV Home/TV button,
            // opening the app switcher.
            if event.modifierFlags.contains(.option), event.keyCode == 48 {
                guard !event.isARepeat else { return nil }
                manager.pressButton(.home, action: .doubleClick)
                return nil
            }

            // In Apple TV text-entry mode, Return and Escape close the local
            // typing session instead of becoming remote Select/Menu presses.
            // Backspace/Delete remains with the TextField so it edits text.
            if manager.keyboardFocused {
                if event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 53 {
                    guard !event.isARepeat else { return nil }
                    manager.endTextInput()
                    return nil
                }
                if event.keyCode == 51 || event.keyCode == 117 {
                    return event
                }
            }

            // Command-Escape is the standard Mac-style shortcut for Home.
            if event.modifierFlags.contains(.command), event.keyCode == 53 {
                guard !event.isARepeat else { return nil }
                manager.pressButton(.home)
                return nil
            }

            // When tvOS reports a focused text field, forward normal Mac
            // typing through Companion's encrypted text-input channel.
            // The visible TextField owns normal typing. This monitor only
            // handles remote navigation when the field is not being edited.
            if manager.keyboardFocused, !event.modifierFlags.contains(.command), Self.isEditingTextControl() {
                return event
            }

            // Remote buttons are discrete actions. Do not send them repeatedly
            // when a physical key is held down. Normal text-field repeats above.
            guard !event.isARepeat else { return nil }

            let button: CompanionButton? = switch event.keyCode {
            case 126: .up
            case 125: .down
            case 123: .left
            case 124: .right
            case 36, 76: .select
            case 53: .menu
            case 49: .select       // Space = Enter/Select
            case 51, 117: .menu    // Backspace/Delete = Back/Menu
            default: nil
            }

            let character = event.characters
            let isVolumeUp = character == "+" || (event.keyCode == 24 && event.modifierFlags.contains(.shift))
            let isVolumeDown = character == "-" || event.keyCode == 27

            if isVolumeUp {
                manager.pressButton(.volumeUp)
                return nil
            }
            if isVolumeDown {
                manager.pressButton(.volumeDown)
                return nil
            }

            guard let button else { return event }
            manager.pressButton(button)
            return nil
        }
    }

    private static func isEditingTextControl() -> Bool {
        var responder = NSApp.keyWindow?.firstResponder
        while let current = responder {
            if current is NSText || current is NSTextField { return true }
            responder = current.nextResponder
        }
        return false
    }
}

struct PairingView: View {
    @Binding var pin: String
    let submit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Enter the PIN shown on your Apple TV")
                .font(.headline)
            TextField("4-digit PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 150)
                .onChange(of: pin) { _, value in
                    let filtered = String(value.filter(\.isNumber).prefix(4))
                    if filtered != value { pin = filtered }
                    if filtered.count == 4 { submit() }
                }
                .onSubmit(submit)
            Text("This pairs the Mac directly with the Apple TV. No app is installed on the TV.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RemoteView: View {
    @Environment(AppleTVManager.self) private var manager

    var body: some View {
        VStack(spacing: 16) {
            Text("Remote")
                .font(.headline)

            VStack(spacing: 8) {
                RemoteButton(symbol: "chevron.up", label: "Up") { manager.pressButton(.up) }
                HStack(spacing: 8) {
                    RemoteButton(symbol: "chevron.left", label: "Left") { manager.pressButton(.left) }
                    RemoteButton(symbol: "circle.fill", label: "Select", prominent: true) { manager.pressButton(.select) }
                    RemoteButton(symbol: "chevron.right", label: "Right") { manager.pressButton(.right) }
                }
                RemoteButton(symbol: "chevron.down", label: "Down") { manager.pressButton(.down) }
            }

            HStack(spacing: 12) {
                RemoteActionButton(title: "Menu", symbol: "chevron.backward") { manager.pressButton(.menu) }
                RemoteActionButton(title: "Home", symbol: "tv") { manager.pressButton(.home) }
                RemoteActionButton(title: "Play/Pause", symbol: "playpause") { manager.pressButton(.playPause) }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick actions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                RemoteActionButton(title: "Control Center", symbol: "switch.2") {
                    manager.pressButton(.home, action: .hold)
                }
                HStack(spacing: 10) {
                    RemoteActionButton(title: "Power Off", symbol: "power") {
                        manager.pressButton(.sleep)
                    }
                    RemoteActionButton(title: "Power On", symbol: "sun.max") {
                        manager.wakeAppleTV()
                    }
                }
            }

            Text("Keyboard: arrow keys to navigate, Return to select, Escape for Menu")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.12))
        }
    }
}

struct RemoteButton: View {
    let symbol: String
    let label: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 62, height: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? .accentColor : .secondary)
        .help(label)
    }
}

struct RemoteActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.bordered)
    }
}
