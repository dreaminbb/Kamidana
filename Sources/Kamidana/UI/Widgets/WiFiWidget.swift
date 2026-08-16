import CoreWLAN
import SwiftUI

struct WiFiWidget: View {
    @ObservedObject var netManager: NetworkManager
    @State private var showPopover = false
    @State private var selectedSSID: String? = nil
    @State private var wifiPassword = ""
    @State private var connectionStatusMsg = ""
    @State private var isHovered = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let config = ConfigManager.shared.currentConfig.wifi
        Button(action: {
            showPopover.toggle()
            if showPopover {
                netManager.scanForNetworks()
            }
        }) {
            HStack(spacing: 4) {
                NerdFontIcon(
                    netManager.currentConnection == "WIFI"
                        ? config.connectedIcon
                        : (netManager.currentConnection == "LAN" ? config.lanIcon : config.disconnectedIcon)
                )
                .foregroundColor(Color(hex: config.iconColor))
            }
            .foregroundColor(
                netManager.currentConnection != "OFF" ? Color(hex: config.textColor) : Color(hex: config.disconnectedTextColor))
        }
        .buttonStyle(.plain)
        .SmoothUIModule()
        .onHover { hover in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Wi-Fi Networks")
                        .font(.headline)
                        .foregroundColor(Color(hex: colors.textPrimary))
                    Spacer()
                    Button(action: {
                        netManager.scanForNetworks()
                    }) {
                        NerdFontIcon("󰑐")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 5)

                if let ssid = selectedSSID {
                    // Password input view
                    VStack(spacing: 12) {
                        Text("\(ssid) に接続")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: colors.textPrimary))

                        SecureField("パスワード", text: $wifiPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 230)

                        if !connectionStatusMsg.isEmpty {
                            Text(connectionStatusMsg)
                                .font(.caption)
                                .foregroundColor(
                                    connectionStatusMsg.contains("成功") ? Color(hex: colors.success) : Color(hex: colors.danger)
                                )
                        }

                        HStack {
                            Button("キャンセル") {
                                selectedSSID = nil
                                wifiPassword = ""
                                connectionStatusMsg = ""
                            }
                            Spacer()
                            Button("接続") {
                                connectionStatusMsg = "接続中..."
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let result = netManager.connectWIFI(
                                        ssid: ssid, password: wifiPassword)
                                    DispatchQueue.main.async {
                                        switch result {
                                        case .success(_):
                                            connectionStatusMsg = "✅ 接続成功！"
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                showPopover = false
                                                selectedSSID = nil
                                                wifiPassword = ""
                                                connectionStatusMsg = ""
                                            }
                                        case .failure(let error):
                                            connectionStatusMsg =
                                                "❌ 失敗: \(error.localizedDescription)"
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(wifiPassword.isEmpty)
                        }
                        .frame(width: 230)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                } else if netManager.availableNetworks.isEmpty {
                    Text("ネットワークを検索中...")
                        .foregroundColor(Color(hex: colors.textTertiary))
                        .frame(width: 250, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            if !connectionStatusMsg.isEmpty && selectedSSID == nil {
                                Text(connectionStatusMsg)
                                    .font(.caption)
                                    .foregroundColor(
                                        connectionStatusMsg.contains("✅")
                                            ? Color(hex: colors.success)
                                            : (connectionStatusMsg.contains("❌")
                                                ? Color(hex: colors.danger) : Color(hex: colors.caution))
                                    )
                                    .padding(.bottom, 5)
                            }

                            ForEach(netManager.availableNetworks, id: \.bssid) { network in
                                Button(action: {
                                    if let ssid = network.ssid {
                                        if netManager.isKnownNetwork(ssid: ssid) {
                                            connectionStatusMsg = "自動接続中: \(ssid)..."
                                            DispatchQueue.global(qos: .userInitiated).async {
                                                let result = netManager.connectWIFI(
                                                    ssid: ssid, password: nil)
                                                DispatchQueue.main.async {
                                                    switch result {
                                                    case .success(_):
                                                        connectionStatusMsg = "✅ 接続しました！"
                                                        DispatchQueue.main.asyncAfter(
                                                            deadline: .now() + 1.0
                                                        ) {
                                                            showPopover = false
                                                            connectionStatusMsg = ""
                                                        }
                                                    case .failure(let error):
                                                        connectionStatusMsg =
                                                            "❌ 失敗: \(error.localizedDescription)"
                                                    }
                                                }
                                            }
                                        } else {
                                            selectedSSID = ssid
                                            wifiPassword = ""
                                            connectionStatusMsg = ""
                                        }
                                    }
                                }) {
                                    HStack {
                                        NerdFontIcon(config.connectedIcon).foregroundColor(Color(hex: colors.textPrimary))
                                        Text(network.ssid ?? "Hidden")
                                            .lineLimit(1)
                                            .foregroundColor(Color(hex: colors.textPrimary))
                                        Spacer()
                                        Text("\(network.rssiValue) dBm")
                                            .font(.caption)
                                            .foregroundColor(Color(hex: colors.textTertiary))
                                    }
                                    .frame(width: 230)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(hex: colors.surface))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding()
            .background(Color(hex: colors.background))
        }
    }
}
