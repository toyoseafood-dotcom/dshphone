# 手机DSH · iOS 版

电脑上的 DeepSeek Harness 搬到 iPhone 上的外壳 App。
界面还是从电脑取，本地只负责显示——跟安卓那个 APK 一个思路。

## 这东西是什么

- `Sources/` —— SwiftUI + WKWebView 外壳，约 300 行
- `project.yml` —— XcodeGen 描述文件（不用手写 .pbxproj）
- `.github/workflows/build-ipa.yml` —— 云端编译，出 `.ipa`
- `Resources/Assets.xcassets` —— 图标

## 怎么出 IPA（不用 Mac）

1. 把这个目录推成一个 GitHub 仓库（公开私有都行）。
2. 仓库 Actions 页面 → `Build DSHPhone IPA` → `Run workflow`。
3. 等 5～8 分钟，在 run 页面底部下载 `DSHPhone-ipa` 这个 artifact。
4. 解压得到 `DSHPhone.ipa`。

## 怎么装进 iPhone

配合 SideStore（免费 Apple ID 自签）：

1. SideStore 里点 `+`，选这个 `DSHPhone.ipa`，Install。
2. 7 天到期前开着 StosVPN 会自动续签。

没有 SideStore 就先看 `D:\Deepseek\iPhone17侧载-20261106\SideStore-Windows清单.md`。

## 用起来

- 首次打开会问电脑地址，填 `100.122.189.102:62210`（Tailscale）或 `192.168.0.113:62210`（同 Wi-Fi）。
- 顶部长按/齿轮可以换地址，刷新按钮重新加载。
- 连不上会出面错误页，两个按钮：重试 / 换地址。

## 前提

电脑上两样东西得开着：

1. DeepSeek Harness
2. 手机DSH 网关（`D:\Deepseek\DSHPhone-20261105\start-gateway.vbs`，已设开机自启）

网关现在会自己探测 DSH 的端口，不用再改配置。

## 本机验证过什么

- 网关 `/` 返回 200，标题 `DeepSeek Harness`
- `/__mobile/manifest.webmanifest`、`icon-192.png`、`mobile.css` 都是 200
- 端口探测能跳过「手机入口」那个 50380 之外的旁支，只认带 `__DSH_BOOT__` 的页面

Swift 部分没在本机编译过（本机没有 Xcode），第一次跑 Actions 如果有报错，看 `build-log` 那个 artifact。
