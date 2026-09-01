import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

import '../../ui/xlab_theme.dart';
import '../realtime/realtime_page.dart';
import '../storage/storage_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _apiKeyStorageKey = 'xlab.realtime.apiKey';
  static final _apiKeyApplicationURL = Uri.parse(
    'https://platform.xmaxai.com/api-keys',
  );
  final _apiKeyController = TextEditingController();
  final _preferences = SharedPreferencesAsync();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAPIKey());
  }

  Future<void> _loadAPIKey() async {
    final apiKey = await _preferences.getString(_apiKeyStorageKey) ?? '';
    if (!mounted) {
      return;
    }
    _apiKeyController.text = apiKey;
  }

  Future<void> _openAPIKeyApplicationPage() async {
    try {
      final opened = await launchUrl(
        _apiKeyApplicationURL,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开 Xmax 开放平台')));
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _open(Widget Function(String apiKey) builder) {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入 API Key')));
      return;
    }
    unawaited(_preferences.setString(_apiKeyStorageKey, apiKey));
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => builder(apiKey)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: XLabBackground(
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: <Widget>[
              const XLabTopBar(
                title: 'XMAXSDK',
                accent: XLabPalette.mint,
                version: XmaxSDKInfo.version,
              ),
              const SizedBox(height: 34),
              _hero(),
              const SizedBox(height: 12),
              const Row(
                children: <Widget>[
                  Expanded(
                    child: _Metric(label: 'RUNTIME', value: 'Flutter'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _Metric(label: 'MIN OS', value: 'iOS 15+'),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _Metric(label: 'LATEST MODEL', value: 'X2.0'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _modelRegistry(),
              const SizedBox(height: 30),
              const _SectionHeader(
                title: 'GENERATION PIPELINES',
                subtitle: '选择一种内容输入方式',
              ),
              const SizedBox(height: 14),
              _PipelineCard(
                sequence: '01',
                mode: 'MODE_01 / CAMERA',
                title: '摄像头实时流',
                subtitle: '实时采集摄像头画面，持续驱动视频生成。',
                capability: 'createLocalCameraStream()',
                color: XLabPalette.mint,
                onTap: () => _open((apiKey) => RealtimePage(apiKey: apiKey)),
              ),
              const SizedBox(height: 30),
              const _SectionHeader(
                title: 'SDK FEATURES',
                subtitle: '更多能力与接入示例',
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                category: 'SDK RENDERING / TRAJECTORY',
                watermark: 'FX',
                title: '自定义轨迹渲染',
                subtitle: '使用自定义 Renderer 绘制交互轨迹。',
                tags: const <String>['CANVAS', 'MULTI-TOUCH', 'CUSTOM EFFECT'],
                color: XLabPalette.pink,
                icon: Icons.gesture_rounded,
                iconLabel: 'RENDER',
                onTap: () => _open(
                  (apiKey) =>
                      RealtimePage(apiKey: apiKey, customTrajectory: true),
                ),
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                category: 'SDK SERVICE / STORAGE',
                watermark: 'URL',
                title: '存储服务',
                subtitle: '上传图片或视频，获取可复用的远程地址。',
                tags: const <String>['IMAGE', 'VIDEO', 'REMOTE URL'],
                color: XLabPalette.orange,
                icon: Icons.cloud_upload_outlined,
                iconLabel: 'UPLOAD',
                onTap: () => _open((apiKey) => StoragePage(apiKey: apiKey)),
              ),
              const SizedBox(height: 38),
              const Center(
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: 36,
                      child: Divider(color: Color(0x18FFFFFF)),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Copyright © 2026 XMAX.AI PTE. LTD. All rights reserved.',
                      style: TextStyle(color: Color(0x50FFFFFF), fontSize: 9),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'sdk@xmax.ai',
                      style: TextStyle(color: Color(0x688EF0C8), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() => const XLabCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Divider(color: XLabPalette.mint, thickness: 2),
            ),
            SizedBox(width: 8),
            Text(
              'XMAX PLAYGROUND',
              style: TextStyle(
                color: XLabPalette.mint,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        Text(
          '实时交互视频模型',
          style: TextStyle(
            color: XLabPalette.primaryText,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '使用摄像头输入，启动 XmaxSDK 流式生成链路',
          style: TextStyle(color: Color(0xFF91A0B2), fontSize: 12),
        ),
      ],
    ),
  );

  Widget _modelRegistry() => XLabCard(
    accent: XLabPalette.mint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '选择你的模型',
                style: TextStyle(
                  color: Color(0xFFE9EDF3),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '1 MODEL',
              style: TextStyle(
                color: Color(0x70FFFFFF),
                fontSize: 8,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x42080C12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'API KEY',
                style: TextStyle(
                  color: Color(0xFF7E8A9A),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: TextField(
                  key: const ValueKey<String>('api-key-field'),
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (value) => unawaited(
                    _preferences.setString(_apiKeyStorageKey, value),
                  ),
                  cursorColor: XLabPalette.mint,
                  style: const TextStyle(
                    color: Color(0xFFD6DEE9),
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入 Xmax API Key',
                    hintStyle: const TextStyle(
                      color: Color(0x80607080),
                      fontSize: 12,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0x66080C12),
                    contentPadding: const EdgeInsets.only(left: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1CFFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1CFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1CFFFFFF)),
                    ),
                    suffixIconConstraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          setState(() => _obscureApiKey = !_obscureApiKey),
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xC7D6DEE9),
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  const Text(
                    '还没有 API Key？',
                    style: TextStyle(color: Color(0x99708090), fontSize: 9),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: TextButton(
                      key: const ValueKey<String>('api-key-platform-link'),
                      onPressed: _openAPIKeyApplicationPage,
                      style: TextButton.styleFrom(
                        foregroundColor: XLabPalette.mint.withValues(
                          alpha: 0.63,
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 9),
                      ),
                      child: const Text('前往 Xmax 开放平台申请'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: XLabPalette.mint.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: <Widget>[
              Text('◆', style: TextStyle(color: XLabPalette.mint, fontSize: 8)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'X2.0',
                      style: TextStyle(
                        color: Color(0xFFF0F2F5),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'RealtimeModel.X2_0',
                      style: TextStyle(color: Color(0x70FFFFFF), fontSize: 8),
                    ),
                  ],
                ),
              ),
              XLabPill('ACTIVE', color: XLabPalette.mint),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xB30E141C),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0x17FFFFFF)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0x62FFFFFF),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8EDF5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFFC6D0DD),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF667384), fontSize: 11),
      ),
    ],
  );
}

final class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.sequence,
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.capability,
    required this.color,
    required this.onTap,
  });
  final String sequence;
  final String mode;
  final String title;
  final String subtitle;
  final String capability;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => XLabCard(
    accent: color,
    onTap: onTap,
    child: Stack(
      children: <Widget>[
        Positioned(
          right: 0,
          top: 18,
          child: Text(
            sequence,
            style: const TextStyle(
              color: Color(0x0AFFFFFF),
              fontSize: 58,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.circle, color: color, size: 7),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mode,
                    style: const TextStyle(
                      color: Color(0xFF9AA7B7),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                XLabPill('READY', color: color),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(
                color: XLabPalette.primaryText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                color: XLabPalette.secondaryText,
                height: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 36,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: const Color(0x66080C12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x16FFFFFF)),
                    ),
                    child: FittedBox(
                      child: Text(
                        capability,
                        style: const TextStyle(
                          color: Color(0xFFB8C3D1),
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 82,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '运行',
                    style: TextStyle(
                      color: Color(0xFF08110E),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

final class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.category,
    required this.watermark,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.color,
    required this.icon,
    required this.iconLabel,
    required this.onTap,
  });
  final String category;
  final String watermark;
  final String title;
  final String subtitle;
  final List<String> tags;
  final Color color;
  final IconData icon;
  final String iconLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => XLabCard(
    accent: color,
    padding: EdgeInsets.zero,
    gradient: const LinearGradient(
      colors: <Color>[Color(0xF01C1813), Color(0xF00D1117), Color(0xF0151210)],
    ),
    borderColor: const Color(0x21FFFFFF),
    clipBehavior: Clip.antiAlias,
    onTap: onTap,
    child: Stack(
      children: <Widget>[
        Positioned(
          right: -40,
          top: -52,
          child: Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: -9,
          child: Text(
            watermark,
            style: const TextStyle(
              color: Color(0x08FFFFFF),
              fontSize: 45,
              fontWeight: FontWeight.bold,
              letterSpacing: -2,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 47,
          child: Container(
            width: 3,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: color, blurRadius: 7),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Color(0xFFA99A8A),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _FeatureAvailablePill(color: color),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          color.withValues(alpha: 0.28),
                          const Color(0x471B1712),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.28)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: color, size: 24),
                        const SizedBox(height: 1),
                        Text(
                          iconLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: XLabPalette.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Color(0xFF81786F),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 58,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '进入',
                      style: TextStyle(
                        color: Color(0xFF08110E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: tags
                    .map(
                      (tag) => _FeatureTag(
                        tag,
                        color: color,
                        highlighted: tag == tags.last,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _FeatureAvailablePill extends StatelessWidget {
  const _FeatureAvailablePill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 25,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0x0CFFFFFF),
      borderRadius: BorderRadius.circular(12.5),
      border: Border.all(color: const Color(0x2EFFFFFF)),
    ),
    child: Text(
      'AVAILABLE',
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.7,
      ),
    ),
  );
}

final class _FeatureTag extends StatelessWidget {
  const _FeatureTag(
    this.text, {
    required this.color,
    required this.highlighted,
  });

  final String text;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: highlighted ? const Color(0x12FFFFFF) : const Color(0x66080C12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x17FFFFFF)),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? color : const Color(0xFFA89A8B),
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
