import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../foundation/logging/XmaxLoggerOption.dart';

/// One startup attempt owns one monotonic timeline. Superseded attempts never
/// overwrite the current attempt's stages or produce cancellation diagnostics.
final class RealtimeTiming {
  RealtimeTiming({int Function()? now}) : _now = now ?? _readClock {
    _startedAt = _now();
  }

  static final _clock = Stopwatch()..start();
  static int _readClock() => _clock.elapsedMicroseconds;
  final int Function() _now;
  late final int _startedAt;
  int? _connectionStart;
  int? _connectionEnd;
  int? _sessionStart;
  int? _sessionEnd;
  int? _roomStart;
  int? _roomEnd;
  int? _signalStart;
  int? _seiMatched;
  bool _finished = false;

  void beginConnection() => _connectionStart = _now();
  void finishConnection() => _connectionEnd = _now();
  void beginSessionCreation() => _sessionStart = _now();
  void finishSessionCreation() => _sessionEnd = _now();
  void beginRoomJoin() => _roomStart = _now();
  void finishRoomJoin() => _roomEnd = _now();
  void beginSignal() => _signalStart = _now();
  void matchSEI() => _seiMatched = _now();

  void finish() {
    if (_finished) return;
    _finished = true;
    final readyAt = _now();
    final lines = <String>[
      '实时生成启动耗时 (Realtime Generation Startup Timing)',
      '├─ ${_label('总耗时：', 'Total Duration: ')}${_duration(_startedAt, readyAt)}',
    ];
    if (_connectionStart != null && _connectionEnd != null) {
      lines.add(
        '├─ ${_label('实时连接：', 'Realtime Connection: ')}${_duration(_connectionStart, _connectionEnd)}',
      );
      final details = <String>[];
      _detail(
        details,
        _label('服务端会话创建：', 'Server Session Creation: '),
        _sessionStart,
        _sessionEnd,
      );
      _detail(
        details,
        _label('RTC 房间连接：', 'RTC Room Connection: '),
        _roomStart,
        _roomEnd,
      );
      for (var index = 0; index < details.length; index++) {
        lines.add(
          '│  ${index == details.length - 1 ? '└─' : '├─'} ${details[index]}',
        );
      }
    }
    lines.add(
      '├─ ${_label('等待生成结果流确认：', 'Waiting for Remote Stream: ')}${_duration(_signalStart, _seiMatched)}',
    );
    lines.add(
      '└─ ${_label('结果流确认到首帧就绪：', 'First Frame Ready: ')}${_duration(_seiMatched, readyAt)}',
    );
    _write(lines);
  }

  void finishFailure(Object error) {
    if (_finished) return;
    _finished = true;
    final failure = XmaxError.from(error);
    if (failure.code == XmaxErrorCode.cancelled) return;
    final failedAt = _now();
    final lines = <String>[
      '实时生成启动未完成耗时 (Incomplete Realtime Generation Startup Timing)',
      '├─ ${_label('已耗时：', 'Elapsed Time: ')}${_duration(_startedAt, failedAt)}',
      '├─ ${_label('停留阶段：', 'Current Stage: ')}$_pendingStage',
    ];
    final details = <String>[];
    _detail(
      details,
      _label('服务端会话创建：', 'Server Session Creation: '),
      _sessionStart,
      _sessionEnd ?? failedAt,
    );
    _detail(
      details,
      _label('RTC 房间连接：', 'RTC Room Connection: '),
      _roomStart,
      _roomEnd ?? failedAt,
    );
    _detail(
      details,
      _label('实时连接：', 'Realtime Connection: '),
      _connectionStart,
      _connectionEnd ?? failedAt,
    );
    _detail(
      details,
      _label('等待生成结果流确认：', 'Waiting for Result Stream Confirmation: '),
      _signalStart,
      _seiMatched ?? failedAt,
    );
    _detail(
      details,
      _label(
        '结果流确认后等待首帧：',
        'Waiting for First Frame After Result Stream Confirmation: ',
      ),
      _seiMatched,
      failedAt,
    );
    lines.addAll(details.map((detail) => '├─ $detail'));
    lines.add('└─ ${_label('失败原因：', 'Failure Reason: ')}${failure.message}');
    _write(lines);
  }

  String get _pendingStage {
    if (_seiMatched != null) {
      return _label(
        '结果流已确认，正在等待首帧',
        'Result Stream Confirmed, Waiting for First Frame',
      );
    }
    if (_signalStart != null) {
      return _label('正在等待生成结果流确认', 'Waiting for Result Stream Confirmation');
    }
    if (_connectionEnd != null) {
      return _label('连接完成后准备生成', 'Preparing Generation After Connection');
    }
    if (_roomStart != null && _roomEnd == null) {
      return _label('正在连接 RTC 房间', 'Connecting to RTC Room');
    }
    if (_sessionEnd != null) return _label('RTC 连接准备', 'RTC Connection Setup');
    if (_sessionStart != null) {
      return _label('服务端会话创建', 'Server Session Creation');
    }
    return _label('调用与本地准备', 'Invocation and Local Preparation');
  }

  static String _label(String chinese, String english) =>
      XmaxLogger.localized(chinese, english);
  static String _duration(int? start, int? end) => start == null || end == null
      ? '--'
      : '${((end - start) / 1000).clamp(0, double.infinity).toStringAsFixed(1)} ms';

  static void _detail(List<String> lines, String label, int? start, int? end) {
    if (start != null && end != null && end - start >= 1000) {
      lines.add('$label${_duration(start, end)}');
    }
  }

  static void _write(List<String> lines) {
    try {
      XmaxLogger.info(
        category: XmaxLoggerCategory.realtime,
        option: XmaxLoggerOption.performance,
        message: lines.join('\n'),
      );
    } catch (_) {
      // An optional diagnostic sink must not fail an otherwise valid startup.
    }
  }
}
