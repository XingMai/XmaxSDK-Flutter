import 'dart:io';

import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../logging/XmaxLogger.dart';
import '../logging/XmaxLoggerOption.dart';

abstract final class RtcStatsLogger {
  static void logLocalStreamStats(LocalStreamStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final video = stats.videoStats;
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message:
          '本地视频发送 (Local Video Uplink)\n'
          '├─ ${XmaxLogger.localized('分辨率：', 'Resolution: ')}${video.encodedFrameWidth} × ${video.encodedFrameHeight}\n'
          '├─ ${XmaxLogger.localized('发送码率：', 'Send Bitrate: ')}${video.sentKBitrate} kbps\n'
          '├─ ${XmaxLogger.localized('采集帧率：', 'Capture Frame Rate: ')}${video.inputFrameRate} fps\n'
          '├─ ${XmaxLogger.localized('编码帧率：', 'Encode Frame Rate: ')}${video.encoderOutputFrameRate} fps\n'
          '├─ ${XmaxLogger.localized('发送帧率：', 'Send Frame Rate: ')}${video.sentFrameRate} fps\n'
          '├─ ${XmaxLogger.localized('视频丢包率：', 'Video Packet Loss: ')}${percentage(video.videoLossRate)}\n'
          '├─ ${XmaxLogger.localized('网络往返时延：', 'Round-Trip Time: ')}${video.rtt} ms\n'
          '└─ ${XmaxLogger.localized('网络抖动：', 'Network Jitter: ')}${video.jitter} ms',
      option: XmaxLoggerOption.performance,
    );
  }

  static void logRemoteStreamStats(RemoteStreamStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final video = stats.videoStats;
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message:
          '远端视频接收 (Remote Video Downlink)\n'
          '├─ ${XmaxLogger.localized('分辨率：', 'Resolution: ')}${video.width} × ${video.height}\n'
          '├─ ${XmaxLogger.localized('接收码率：', 'Receive Bitrate: ')}${video.receivedKBitrate} kbps\n'
          '├─ ${XmaxLogger.localized('解码帧率：', 'Decode Frame Rate: ')}${video.decoderOutputFrameRate} fps\n'
          '├─ ${XmaxLogger.localized('渲染帧率：', 'Render Frame Rate: ')}${video.rendererOutputFrameRate} fps\n'
          '├─ ${XmaxLogger.localized('视频丢包率：', 'Video Packet Loss: ')}${percentage(video.videoLossRate)}\n'
          '├─ ${XmaxLogger.localized('网络往返时延：', 'Round-Trip Time: ')}${video.rtt} ms\n'
          '├─ ${XmaxLogger.localized('卡顿次数：', 'Stall Count: ')}${video.stallCount}${XmaxLogger.localized(' 次', '')}\n'
          '├─ ${XmaxLogger.localized('卡顿时长：', 'Stall Duration: ')}${video.stallDuration} ms\n'
          '└─ ${XmaxLogger.localized('端到端时延：', 'End-to-End Delay: ')}${video.e2eDelay} ms',
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
      '${hasRemoteQuality ? '├─' : '└─'} ${XmaxLogger.localized('本地发送（上行）', 'Local Uplink')}',
      '${hasRemoteQuality ? '│  ' : '   '}├─ ${XmaxLogger.localized('质量：', 'Quality: ')}${networkQualityName(localQuality.txQuality)}',
      '${hasRemoteQuality ? '│  ' : '   '}└─ ${_networkMetrics(localQuality, includesRtt: true)}',
    ];

    for (var index = 0; index < remoteQualities.length; index += 1) {
      final quality = remoteQualities[index];
      final isLast = index == remoteQualities.length - 1;
      final branch = isLast ? '└─' : '├─';
      final indent = isLast ? '   ' : '│  ';
      lines
        ..add(
          '$branch ${XmaxLogger.localized('远端接收', 'Remote Downlink')} ${quality.uid}${XmaxLogger.localized('（下行）', '')}',
        )
        ..add(
          '$indent├─ ${XmaxLogger.localized('质量：', 'Quality: ')}${networkQualityName(quality.rxQuality)}',
        )
        ..add('$indent└─ ${_networkMetrics(quality, includesRtt: false)}');
    }

    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message: lines.join('\n'),
      option: XmaxLoggerOption.performance,
    );
  }

  static void logSystemStats(SysStats stats) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final cpu = <String>[
      '${XmaxLogger.localized('应用', 'App')} ${percentage(stats.cpuAppUsage)}',
      '${XmaxLogger.localized('系统', 'System')} ${percentage(stats.cpuTotalUsage)}',
      '${stats.cpuCores} ${XmaxLogger.localized('核', 'Cores')}',
    ].join(XmaxLogger.localized('，', ', '));
    final memory = <String>[
      '${XmaxLogger.localized('应用', 'App')} ${stats.memoryUsage.toStringAsFixed(0)} MB',
      '${XmaxLogger.localized('应用占用', 'App Usage')} ${stats.memoryRatio.toStringAsFixed(2)}%',
      '${XmaxLogger.localized('系统占用', 'System Usage')} ${stats.totalMemoryRatio.toStringAsFixed(2)}%',
    ].join(XmaxLogger.localized('，', ', '));
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message:
          '性能统计 (System Performance Metrics)\n'
          '├─ ${XmaxLogger.localized('CPU：', 'CPU: ')}$cpu\n'
          '└─ ${XmaxLogger.localized('内存：', 'Memory: ')}$memory',
      option: XmaxLoggerOption.performance,
    );
  }

  static void logPerformanceAlarm(
    PerformanceAlarmReason reason,
    SourceWantedData data,
  ) {
    if (!XmaxLogger.isEnabled(XmaxLoggerOption.performance)) return;
    final lines = <String>[
      '性能告警 (Performance Alert)',
      '├─ ${XmaxLogger.localized('reason：', 'reason: ')}${reason.name}',
    ];
    final state = performanceAlarmName(reason);
    if (data.width > 0 && data.height > 0 && data.frameRate > 0) {
      lines
        ..add('├─ ${XmaxLogger.localized('状态：', 'Status: ')}$state')
        ..add(
          '└─ ${XmaxLogger.localized('建议：', 'Recommendation: ')}${data.width} × ${data.height}${XmaxLogger.localized('，', ', ')}${data.frameRate} fps',
        );
    } else {
      lines.add('└─ ${XmaxLogger.localized('状态：', 'Status: ')}$state');
    }
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message: lines.join('\n'),
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
    final metrics = <String>[
      '${XmaxLogger.localized('丢包', 'Packet Loss')} ${percentage(loss)}',
    ];
    if (includesRtt) {
      metrics.add('RTT ${quality.rtt} ms');
    }
    metrics.add(
      '${XmaxLogger.localized('带宽', 'Bandwidth')} ${(quality.totalBandwidth / 1000).toStringAsFixed(0)} kbps',
    );
    return '${XmaxLogger.localized('指标：', 'Metrics: ')}${metrics.join(XmaxLogger.localized('，', ', '))}';
  }

  static String networkQualityName(NetworkQuality quality) {
    final name = quality.name.toLowerCase();
    if (name.contains('very_bad') || name.contains('verybad')) {
      return XmaxLogger.localized('极差', 'Very Bad');
    }
    if (name.contains('excellent')) {
      return XmaxLogger.localized('极好', 'Excellent');
    }
    if (name.contains('good')) return XmaxLogger.localized('良好', 'Good');
    if (name.contains('poor')) return XmaxLogger.localized('较差', 'Poor');
    if (name.contains('bad')) return XmaxLogger.localized('差', 'Bad');
    if (name.contains('down')) {
      return XmaxLogger.localized('断网', 'Disconnected');
    }
    return XmaxLogger.localized('未知', 'Unknown');
  }

  static String performanceAlarmName(PerformanceAlarmReason reason) {
    final name = reason.name.toLowerCase();
    if (name.contains('bandwidth_fallback')) {
      return XmaxLogger.localized('网络受限', 'Bandwidth Limited');
    }
    if (name.contains('bandwidth_resumed')) {
      return XmaxLogger.localized('网络恢复', 'Bandwidth Recovered');
    }
    if (name.contains('fallback')) {
      return XmaxLogger.localized('设备性能受限', 'Device Performance Limited');
    }
    if (name.contains('resumed')) {
      return XmaxLogger.localized('设备性能恢复', 'Device Performance Recovered');
    }
    return XmaxLogger.localized('未知', 'Unknown');
  }

  static String percentage(num value) => '${(value * 100).toStringAsFixed(2)}%';
}
