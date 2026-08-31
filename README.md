# XmaxSDK Flutter

XmaxSDK 的 Flutter 实现。首版支持 iOS 和 Android 摄像头实时生成、轨迹交互以及独立的腾讯 COS Storage 能力。

当前仓库处于工程初始化阶段。公开 API、架构与执行约束见：

- [`docs/API_PARITY.md`](docs/API_PARITY.md)
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md)
- [`docs/BOOTSTRAP_AND_EXAMPLE.md`](docs/BOOTSTRAP_AND_EXAMPLE.md)

## 开发环境

```shell
fvm use
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

可运行的接入宿主位于 [`example/`](example/)。
