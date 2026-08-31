import 'package:flutter/material.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

import '../realtime/realtime_page.dart';
import '../storage/storage_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    if (_apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入 API Key')));
      return;
    }

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'XmaxSDK',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Flutter ${XmaxSDKInfo.version} · Camera-first',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF91A0B3)),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API Key',
                helperText: '仅保存在当前 Example 进程内',
                suffixIcon: IconButton(
                  tooltip: _obscureApiKey ? '显示' : '隐藏',
                  onPressed: () {
                    setState(() => _obscureApiKey = !_obscureApiKey);
                  },
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const _SectionTitle('GENERATION PIPELINE'),
            const SizedBox(height: 12),
            _CapabilityCard(
              index: '01',
              title: '摄像头实时流',
              subtitle: '预览、连接、生成、切换摄像头与完整生命周期。',
              method: 'createLocalCameraStream()',
              icon: Icons.videocam_outlined,
              onTap: () =>
                  _open(RealtimePage(apiKey: _apiKeyController.text.trim())),
            ),
            const SizedBox(height: 30),
            const _SectionTitle('SDK FEATURES'),
            const SizedBox(height: 12),
            _CapabilityCard(
              index: '02',
              title: '自定义轨迹渲染',
              subtitle: '复用摄像头实时页，注入 Flutter trajectory renderer。',
              method: 'TrajectoryEffectRendering',
              icon: Icons.gesture,
              onTap: () => _open(
                RealtimePage(
                  apiKey: _apiKeyController.text.trim(),
                  customTrajectory: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CapabilityCard(
              index: '03',
              title: '存储服务',
              subtitle: '上传、下载、进度、取消和错误处理。',
              method: 'createStorageManager()',
              icon: Icons.cloud_upload_outlined,
              onTap: () =>
                  _open(StoragePage(apiKey: _apiKeyController.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: const Color(0xFF4DF0B5),
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.method,
    required this.icon,
    required this.onTap,
  });

  final String index;
  final String title;
  final String subtitle;
  final String method;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4DF0B5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4DF0B5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index  $title',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF91A0B3)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      method,
                      style: const TextStyle(
                        color: Color(0xFF73A7FF),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF607086)),
            ],
          ),
        ),
      ),
    );
  }
}
