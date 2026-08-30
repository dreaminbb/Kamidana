import CoreWLAN
import SwiftUI

struct WiFiConnectionView: View {
    @EnvironmentObject var netManager: NetworkManager

    let config: NetworkWidgetConfig
    @Binding var isPresented: Bool
    var showsSurface = true

    @State private var selectedSSID: String?
    @State private var wifiPassword = ""
    @State private var connectionStatusMessage = ""
    @FocusState private var isPasswordFieldFocused: Bool

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Wi-Fi Networks")
                    .font(.headline)
                    .foregroundColor(Color(hex: colors.textPrimary))
                Spacer()
                Button("Refresh") { scanIfAllowed() }
                    .buttonStyle(.plain)
                    .disabled(!netManager.canScanWiFi || netManager.wifiScanState == .scanning)
            }
            .padding(.bottom, 5)

            if netManager.currentConnection == "LAN" {
                Text("Wi-Fi scanning is disabled while a wired connection is active.")
                    .foregroundColor(Color(hex: colors.textTertiary))
                    .frame(width: 250, alignment: .leading)
                    .padding(.vertical, 8)
            } else if let ssid = selectedSSID {
                passwordView(ssid: ssid, colors: colors)
            } else {
                scanContent(colors: colors)
            }
        }
        .padding()
        .background(showsSurface ? Color(hex: colors.background) : Color.clear)
        .onAppear { scanIfAllowed() }
    }

    @ViewBuilder
    private func scanContent(colors: GlobalColorsConfig) -> some View {
        switch netManager.wifiScanState {
        case .idle, .scanning:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Scanning for Wi-Fi networks...")
            }
            .foregroundColor(Color(hex: colors.textTertiary))
            .frame(width: 250, alignment: .center)
            .padding()
        case .loaded:
            networkList(colors: colors)
        case .empty:
            Text("No visible Wi-Fi networks were found.")
                .foregroundColor(Color(hex: colors.textTertiary))
                .frame(width: 250, alignment: .center)
                .padding()
        case .unavailable(let reason), .failed(let reason):
            VStack(spacing: 8) {
                Text("Wi-Fi scan failed")
                    .foregroundColor(Color(hex: colors.textSecondary))
                Text(reason)
                    .font(.caption)
                    .foregroundColor(Color(hex: colors.textTertiary))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 250, alignment: .center)
            .padding()
        }
    }

    private func scanIfAllowed() {
        guard netManager.canScanWiFi else { return }
        if !netManager.isWiFiAuthorizationDetermined {
            netManager.scanForNetworks() // triggers auth request
            return
        }
        netManager.scanForNetworks()
    }

    private func passwordView(ssid: String, colors: GlobalColorsConfig) -> some View {
        VStack(spacing: 12) {
            Text("Connect to \(ssid)")
                .font(.subheadline)
                .foregroundColor(Color(hex: colors.textPrimary))

            SecureField("Password", text: $wifiPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 230)
                .focused($isPasswordFieldFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPasswordFieldFocused = true
                    }
                }

            if !connectionStatusMessage.isEmpty {
                Text(connectionStatusMessage)
                    .font(.caption)
                    .foregroundColor(Color(hex: colors.textSecondary))
            }

            HStack {
                Button("Cancel") {
                    selectedSSID = nil
                    wifiPassword = ""
                    connectionStatusMessage = ""
                }
                Spacer()
                Button("Connect") { connect(ssid: ssid) }
                    .buttonStyle(.borderedProminent)
                    .disabled(wifiPassword.isEmpty)
            }
            .frame(width: 230)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
    }

    private func networkList(colors: GlobalColorsConfig) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                if !connectionStatusMessage.isEmpty {
                    Text(connectionStatusMessage)
                        .font(.caption)
                        .foregroundColor(Color(hex: colors.textSecondary))
                        .padding(.bottom, 5)
                }

                ForEach(Array(orderedNetworks.enumerated()), id: \.offset) {
                    _, network in
                    let isCurrentNetwork = network.ssid == netManager.currentSSID
                    Button {
                        guard let ssid = network.ssid else { return }
                        if netManager.isKnownNetwork(ssid: ssid) {
                            connectKnownNetwork(ssid: ssid)
                        } else {
                            selectedSSID = ssid
                            wifiPassword = ""
                            connectionStatusMessage = ""
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    } label: {
                        HStack {
                            NerdFontIcon(config.wirelessIcon)
                                .foregroundColor(
                                    Color(hex: isCurrentNetwork ? colors.accent : colors.textPrimary)
                                )
                            Text(network.ssid ?? "Hidden")
                                .lineLimit(1)
                                .foregroundColor(
                                    Color(hex: isCurrentNetwork ? colors.accent : colors.textPrimary)
                                )
                            Spacer()
                            Text("\(network.rssiValue) dBm")
                                .font(.caption)
                                .foregroundColor(
                                    Color(hex: isCurrentNetwork ? colors.accent : colors.textTertiary)
                                )
                        }
                        .frame(width: 230)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Color(hex: isCurrentNetwork ? colors.surfaceHighlight : colors.surface)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var orderedNetworks: [CWNetwork] {
        netManager.availableNetworks.sorted { lhs, rhs in
            let lhsIsCurrent = lhs.ssid == netManager.currentSSID
            let rhsIsCurrent = rhs.ssid == netManager.currentSSID
            if lhsIsCurrent != rhsIsCurrent {
                return lhsIsCurrent
            }
            return lhs.rssiValue > rhs.rssiValue
        }
    }

    private func connect(ssid: String) {
        connectionStatusMessage = "Connecting..."
        let password = wifiPassword
        DispatchQueue.global(qos: .userInitiated).async {
            let result = netManager.connectWIFI(ssid: ssid, password: password)
            DispatchQueue.main.async { handle(result) }
        }
    }

    private func connectKnownNetwork(ssid: String) {
        connectionStatusMessage = "Connecting to \(ssid)..."
        DispatchQueue.global(qos: .userInitiated).async {
            let result = netManager.connectWIFI(ssid: ssid, password: nil)
            DispatchQueue.main.async { handle(result) }
        }
    }

    private func handle(_ result: Result<Bool, Error>) {
        switch result {
        case .success:
            connectionStatusMessage = "Connected"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPresented = false
                selectedSSID = nil
                wifiPassword = ""
                connectionStatusMessage = ""
            }
        case .failure(let error):
            connectionStatusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
}
