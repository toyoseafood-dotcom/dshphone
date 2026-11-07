import SwiftUI
import WebKit

// MARK: - 地址存储

final class Store: ObservableObject {
    static let key = "serverAddress"
    static let fallback = "https://toyoseafood.com:8444"

    @Published var address: String {
        didSet { UserDefaults.standard.set(address, forKey: Self.key) }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key) ?? Self.fallback
        self.address = saved
    }

    var url: URL? {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        return URL(string: s)
    }
}

// MARK: - 根界面

struct RootView: View {
    @StateObject private var store = Store()
    @State private var reloadToken = 0
    @State private var showSettings = false
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        ZStack(alignment: .top) {
            if let url = store.url {
                WebView(
                    url: url,
                    reloadToken: reloadToken,
                    isLoading: $isLoading,
                    errorText: $errorText
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                Color.black.ignoresSafeArea()
            }

            if let err = errorText {
                ErrorOverlay(message: err) {
                    errorText = nil
                    reloadToken += 1
                } onChange: {
                    errorText = nil
                    showSettings = true
                }
            }

            TopBar(
                title: store.url?.host ?? "未设置",
                loading: isLoading,
                onReload: { reloadToken += 1 },
                onSettings: { showSettings = true }
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(store: store) {
                showSettings = false
                errorText = nil
                reloadToken += 1
            } onCancel: {
                showSettings = false
            }
        }
    }
}

// MARK: - 顶部细条（长按也能换地址）

struct TopBar: View {
    let title: String
    let loading: Bool
    let onReload: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            if loading {
                ProgressView().scaleEffect(0.6).tint(.white)
            }
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color.black.opacity(0.55))
        .contentShape(Rectangle())
    }
}

// MARK: - 出错页

struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundColor(.orange)
            Text("连不上服务器")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            HStack(spacing: 12) {
                Button("重试", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button("换地址", action: onChange)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(Color(white: 0.1))
        .cornerRadius(16)
        .padding(28)
    }
}

// MARK: - 换地址

struct SettingsSheet: View {
    @ObservedObject var store: Store
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var text: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器地址")) {
                    TextField("toyoseafood.com:8444", text: $text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }
                Section(footer: Text("默认连日本服务器 toyoseafood.com:8444，无需填写 token。改这个地址只在你换了服务器时用。")) {
                    EmptyView()
                }
            }
            .navigationTitle("连接电脑")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("连接") {
                        store.address = text
                        onSave()
                    }
                }
            }
            .onAppear { text = store.address }
        }
    }
}
