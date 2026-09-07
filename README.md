# video_download_ev1 — EV1 视频嗅探下载器

Flutter 跨平台应用（iOS / Android / macOS / Windows）：

- **下载 Tab**：管理已转换的 `.flv` 视频（播放、重命名、搜索、分享、删除）
- **浏览器 Tab**：内置 WebView，自动嗅探 `.ev1` 链接，点选下载
- **测试 Tab**：粘贴 `.ev1` 链接，验证探测与下载流程

## 运行

```bash
cd video_download_ev1
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos      # macOS
flutter run -d windows    # Windows（需在 Windows 上）
flutter run               # 连接 iOS/Android 设备
```

## Windows 打包

**必须在 Windows 电脑上执行**（macOS 无法交叉编译 Windows exe）：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

产物目录：`build/windows/x64/runner/Release/`（含 `video_download_ev1.exe`，需整文件夹一起分发）。

推送到 GitHub 后，`.github/workflows/build-windows.yml` 会在云端自动打 Windows 包，在 Actions → Artifacts 下载 `video_download_ev1-windows-x64.zip`。

## EV1 转换

百家云 `.ev1` 文件：对前 100 字节做 `XOR 0xFF`，其余原样保留，输出标准 FLV。

## 使用说明

1. 打开「浏览器」Tab，输入网址
2. 播放或加载含 `.ev1` 资源的页面
3. 点击雷达图标查看嗅探列表，点「下载」
4. 在「下载」Tab 播放或分享视频
