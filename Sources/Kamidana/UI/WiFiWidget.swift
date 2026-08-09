import SwiftUI
import CoreWLAN

struct WiFiWidget: View {
    @ObservedObject var netManager: NetworkManager
    var theme: Theme
    
    @State private var showPopover = false
    @State private var selectedSSID: String? = nil
    @State private var wifiPassword = ""
    @State private var connectionStatusMsg = ""
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            showPopover.toggle()
            if showPopover {
                netManager.scanForNetworks()
            }
        }) {
            HStack(spacing: 4) {
                Image(
                    systemName: netManager.currentConnection == "WIFI"
                        ? "wifi"
                        : (netManager.currentConnection == "LAN" ? "network" : "wifi.slash"))
            }
            .foregroundColor(
                netManager.currentConnection != "OFF" ? theme.text : theme.subtext0)
        }
        .buttonStyle(.plain)
        .SmoothUIModule(theme: theme)
        .onHover { hover in withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover } }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Wi-Fi Networks")
                        .font(.headline)
                        .foregroundColor(theme.text)
                    Spacer()
                    Button(action: {
                        netManager.scanForNetworks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 5)

                if let ssid = selectedSSID {
                    // ▼ パスワード入力画面 ▼
                    VStack(spacing: 12) {
                        Text("\(ssid) に接続")
                            .font(.subheadline)
                            .foregroundColor(theme.text)

                        SecureField("パスワード", text: $wifiPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 230)

                        if !connectionStatusMsg.isEmpty {
                            Text(connectionStatusMsg)
                                .font(.caption)
                                .foregroundColor(
                                    connectionStatusMsg.contains("成功") ? theme.green : theme.red
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
                                            connectionStatusMsg = "❌ 失敗: \(error.localizedDescription)"
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
                        .foregroundColor(theme.subtext0)
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
                                            ? theme.green
                                            : (connectionStatusMsg.contains("❌")
                                                ? theme.red : theme.yellow)
                                    )
                                    .padding(.bottom, 5)
                            }

                            ForEach(netManager.availableNetworks, id: \.bssid) { network in
                                Button(action: {
                                    if let ssid = network.ssid {
                                        if netManager.isKnownNetwork(ssid: ssid) {
                                            connectionStatusMsg = "自動接続中: \(ssid)..."
                                            DispatchQueue.global(qos: .userInitiated).async {
                                                let result = netManager.connectWIFI(ssid: ssid, password: nil)
                                                DispatchQueue.main.async {
                                                    switch result {
                                                    case .success(_):
                                                        connectionStatusMsg = "✅ 接続しました！"
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                            showPopover = false
                                                            connectionStatusMsg = ""
                                                        }
                                                    case .failure(let error):
                                                        connectionStatusMsg = "❌ 失敗: \(error.localizedDescription)"
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
                                        Image(systemName: "wifi").foregroundColor(theme.text)
                                        Text(network.ssid ?? "Hidden")
                                            .lineLimit(1)
                                            .foregroundColor(theme.text)
                                        Spacer()
                                        Text("\(network.rssiValue) dBm")
                                            .font(.caption)
                                            .foregroundColor(theme.subtext0)
                                    }
                                    .frame(width: 230)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(theme.surface0)
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
            .background(theme.base)
        }
    }
}
