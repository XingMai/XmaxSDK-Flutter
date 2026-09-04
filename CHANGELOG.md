# Changelog

## 1.0.1

- 修复使用新版腾讯 COS 依赖时 Android Release 构建的 R8 缺失类型错误。
- 完善 Android 宿主的 R8 配置说明，确保 pub.dev、Git 和本地 path 接入可正常构建。

## 1.0.0

- SDK Dart 文件名与 iOS 对齐为首字母大写驼峰，Example 保持 Flutter snake_case。
- 实现与 iOS 对齐的 XmaxClient、实时 Manager、Session 和状态机。
- 接入火山 RTC 摄像头采集、本地/远端渲染及视频发布。
- 实现多点轨迹采集、坐标映射、默认效果和自定义 Renderer。
- 实现腾讯 COS 图片/视频上传、图片安全检测、下载和进度回调。
- 完成 iOS/Android XLab、平台配置、单元测试和双端 Debug 构建验证。
- 初始化 XmaxSDK Flutter Package 和 iOS/Android Example 工程。
- 固定 Flutter、火山 RTC 与腾讯 COS 依赖基线。
