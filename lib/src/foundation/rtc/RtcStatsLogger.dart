import 'dart:io';

import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../logging/XmaxLogger.dart';
import '../logging/XmaxLoggerOption.dart';

abstract final class RtcStatsLogger {
  static const _category = 'RTC';

  static void logLocalStreamStats(LocalStreamStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final video = stats.videoStats;
    XmaxLogger.debug(
      '本地视频发送 (Local Video Uplink)\n'
      '├─ 分辨率：${video.encodedFrameWidth} × ${video.encodedFrameHeight}\n'
      '├─ 发送码率：${video.sentKBitrate} kbps\n'
      '├─ 采集帧率：${video.inputFrameRate} fps\n'
      '├─ 编码帧率：${video.encoderOutputFrameRate} fps\n'
      '├─ 发送帧率：${video.sentFrameRate} fps\n'
      '├─ 视频丢包率：${percentage(video.videoLossRate)}\n'
      '├─ 网络往返时延：${video.rtt} ms\n'
      '└─ 网络抖动：${video.jitter} ms',
      category: _category,
      option: XmaxLoggerOption.performance,
    );
  }

  static void logRemoteStreamStats(RemoteStreamStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final video = stats.videoStats;
    XmaxLogger.debug(
      '远端视频接收 (Remote Video Downlink)\n'
      '├─ 分辨率：${video.width} × ${video.height}\n'
      '├─ 接收码率：${video.receivedKBitrate} kbps\n'
      '├─ 解码帧率：${video.decoderOutputFrameRate} fps\n'
      '├─ 渲染帧率：${video.rendererOutputFrameRate} fps\n'
      '├─ 视频丢包率：${percentage(video.videoLossRate)}\n'
      '├─ 网络往返时延：${video.rtt} ms\n'
      '├─ 卡顿次数：${video.stallCount} 次\n'
      '├─ 卡顿时长：${video.stallDuration} ms\n'
      '└─ 端到端时延：${video.e2eDelay} ms',
      category: _category,
      option: XmaxLoggerOption.performance,
    );
  }

  static void logNetworkQuality(
    NetworkQualityStats localQuality,
    List<NetworkQualityStats> remoteQualities,
  ) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final hasRemoteQuality = remoteQualities.isNotEmpty;
    final lines = <String>[
      '网络质量 (Network Quality Metrics)',
      '${hasRemoteQuality ? '├─' : '└─'} 本地发送（上行）',
      '${hasRemoteQuality ? '│  ' : '   '}├─ 质量：${networkQualityName(localQuality.txQuality)}',
      '${hasRemoteQuality ? '│  ' : '   '}└─ ${_networkMetrics(localQuality, includesRtt: true)}',
    ];

    for (var index = 0; index < remoteQualities.length; index += 1) {
      final quality = remoteQualities[index];
      final isLast = index == remoteQualities.length - 1;
      final branch = isLast ? '└─' : '├─';
      final indent = isLast ? '   ' : '│  ';
      lines
        ..add('$branch 远端接收 ${quality.uid}（下行）')
        ..add('$indent├─ 质量：${networkQualityName(quality.rxQuality)}')
        ..add('$indent└─ ${_networkMetrics(quality, includesRtt: false)}');
    }

    XmaxLogger.debug(
      lines.join('\n'),
      category: _category,
      option: XmaxLoggerOption.performance,
    );
  }

  static void logSystemStats(SysStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final cpu = <String>[
      '应用 ${percentage(stats.cpuAppUsage)}',
      '系统 ${percentage(stats.cpuTotalUsage)}',
      '${stats.cpuCores} 核',
    ].join('，');
    final memory = <String>[
      '应用 ${stats.memoryUsage.toStringAsFixed(0)} MB',
      '应用占用 ${stats.memoryRatio.toStringAsFixed(2)}%',
      '系统占用 ${stats.totalMemoryRatio.toStringAsFixed(2)}%',
    ].join('，');
    XmaxLogger.debug(
      '性能统计 (System Performance Metrics)\n'
      '├─ CPU：$cpu\n'
      '└─ 内存：$memory',
      category: _category,
      option: XmaxLoggerOption.performance,
    );
  }

  static void logPerformanceAlarm(
    PerformanceAlarmReason reason,
    SourceWantedData data,
  ) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final lines = <String>['性能告警 (Performance Alert)'];
    final state = performanceAlarmName(reason);
    if (data.width > 0 && data.height > 0 && data.frameRate > 0) {
      lines
        ..add('├─ 状态：$state')
        ..add('└─ 建议：${data.width} × ${data.height}，${data.frameRate} fps');
    } else {
      lines.add('└─ 状态：$state');
    }
    XmaxLogger.debug(
      lines.join('\n'),
      category: _category,
      option: XmaxLoggerOption.performance,
    );
  }

  static String _networkMetrics(
    NetworkQualityStats quality, {
    required bool includesRtt,
  }) {
    final loss = Platform.isAndroid
        ? quality.fractionLost ?? 0
        : quality.lossRatio ?? 0;
    final metrics = <String>['丢包 ${percentage(loss)}'];
    if (includesRtt) {
      metrics.add('RTT ${quality.rtt} ms');
    }
    metrics.add(
      '带宽 ${(quality.totalBandwidth / 1000).toStringAsFixed(0)} kbps',
    );
    return '指标：${metrics.join('，')}';
  }

  static String networkQualityName(NetworkQuality quality) {
    final name = quality.name.toLowerCase();
    if (name.contains('very_bad') || name.contains('verybad')) return '极差';
    if (name.contains('excellent')) return '极好';
    if (name.contains('good')) return '良好';
    if (name.contains('poor')) return '较差';
    if (name.contains('bad')) return '差';
    if (name.contains('down')) return '断网';
    return '未知';
  }

  static String performanceAlarmName(PerformanceAlarmReason reason) {
    final name = reason.name.toLowerCase();
    if (name.contains('bandwidth_fallback')) return '网络受限';
    if (name.contains('bandwidth_resumed')) return '网络恢复';
    if (name.contains('fallback')) return '设备性能受限';
    if (name.contains('resumed')) return '设备性能恢复';
    return '未知';
  }

  static String percentage(num value) => '${(value * 100).toStringAsFixed(2)}%';
}
