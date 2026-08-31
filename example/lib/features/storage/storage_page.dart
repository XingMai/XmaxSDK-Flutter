import 'package:flutter/material.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({required this.apiKey, super.key});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('存储服务')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 54,
                color: Color(0xFFFFA657),
              ),
              const SizedBox(height: 20),
              Text(
                'Example 路由已建立',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                '将在 Storage 阶段接入文件选择、上传、下载、进度和取消。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF91A0B3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
