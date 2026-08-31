import 'package:flutter/material.dart';

class RealtimePage extends StatelessWidget {
  const RealtimePage({
    required this.apiKey,
    this.customTrajectory = false,
    super.key,
  });

  final String apiKey;
  final bool customTrajectory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(customTrajectory ? '自定义轨迹' : '摄像头实时流')),
      body: _BootstrapCapability(
        icon: customTrajectory ? Icons.gesture : Icons.videocam_outlined,
        title: 'Example 路由已建立',
        description: customTrajectory
            ? '将在 Render 阶段接入自定义 TrajectoryEffectRendering。'
            : '将在 RTC 阶段接入摄像头预览、连接和生成生命周期。',
      ),
    );
  }
}

class _BootstrapCapability extends StatelessWidget {
  const _BootstrapCapability({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF4DF0B5)),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF91A0B3)),
            ),
          ],
        ),
      ),
    );
  }
}
