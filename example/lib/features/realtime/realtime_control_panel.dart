import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum XLabRealtimePanelMode {
  character('charx', '换形象', '视频中角色替换成参考图中角色'),
  clothing('clothx', '换装', '视频中人物衣服替换成参考图中衣服'),
  style('vibex', '换风格', '视频风格变为参考图指定的风格'),
  summon('dimx', '虚拟召唤', '指定角色在场景中互动'),
  touch('mox', '触控动图', '让画面自然动起来'),
  free('free', '自由', '');

  const XLabRealtimePanelMode(this.id, this.label, this.prompt);

  final String id;
  final String label;
  final String prompt;

  bool get usesReferences => switch (this) {
    character || clothing || style || summon => true,
    touch || free => false,
  };
}

final class XLabRealtimeReference {
  const XLabRealtimeReference({
    required this.id,
    required this.categoryID,
    required this.title,
    required this.referencePath,
    this.iconURL,
    this.iconBytes,
  });

  final String id;
  final String categoryID;
  final String title;
  final String referencePath;
  final String? iconURL;
  final Uint8List? iconBytes;

  factory XLabRealtimeReference.fromJson(Map<String, dynamic> json) =>
      XLabRealtimeReference(
        id: json['id'] as String,
        categoryID: json['categoryID'] as String,
        title: json['title'] as String,
        iconURL: json['iconURL'] as String,
        referencePath: json['referencePath'] as String,
      );
}

Future<List<XLabRealtimeReference>> loadXLabRealtimeReferences() async {
  final catalog =
      jsonDecode(
            await rootBundle.loadString(
              'assets/realtime_reference_catalog.json',
            ),
          )
          as Map<String, dynamic>;
  final items = catalog['items'] as List<dynamic>;
  return items
      .cast<Map<String, dynamic>>()
      .map(XLabRealtimeReference.fromJson)
      .toList(growable: false);
}

final class XLabRealtimeControlPanel extends StatelessWidget {
  const XLabRealtimeControlPanel({
    required this.mode,
    required this.generating,
    required this.busy,
    required this.promptController,
    required this.references,
    required this.selectedReference,
    required this.onModeChanged,
    required this.onStop,
    required this.onReferenceChanged,
    required this.onAddReference,
    required this.onTouchStart,
    required this.onPromptSubmit,
    required this.onPromptReference,
    this.promptReference,
    this.uploadingReference = false,
    super.key,
  });

  final XLabRealtimePanelMode mode;
  final bool generating;
  final bool busy;
  final TextEditingController promptController;
  final List<XLabRealtimeReference> references;
  final XLabRealtimeReference? selectedReference;
  final XLabRealtimeReference? promptReference;
  final bool uploadingReference;
  final ValueChanged<XLabRealtimePanelMode> onModeChanged;
  final VoidCallback onStop;
  final ValueChanged<XLabRealtimeReference?> onReferenceChanged;
  final VoidCallback onAddReference;
  final VoidCallback onTouchStart;
  final VoidCallback onPromptSubmit;
  final VoidCallback onPromptReference;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF101010),
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 14),
                SizedBox(
                  width: 28,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: generating && !busy ? onStop : null,
                    icon: Icon(
                      Icons.block,
                      size: 16,
                      color: Colors.white.withValues(
                        alpha: generating ? 1 : 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 14),
                    itemCount: XLabRealtimePanelMode.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final item = XLabRealtimePanelMode.values[index];
                      final selected = item == mode;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: busy ? null : () => onModeChanged(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Center(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: selected ? 1 : 0.48,
                                ),
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(height: 50, child: _content()),
        ],
      ),
    ),
  );

  Widget _content() {
    if (mode.usesReferences) {
      final visible = references
          .where((item) => item.categoryID == mode.id)
          .toList(growable: false);
      return _ReferenceStrip(
        references: visible,
        selectedReference: selectedReference,
        uploadingReference: uploadingReference,
        onReferenceChanged: onReferenceChanged,
        onAddReference: onAddReference,
      );
    }
    if (mode == XLabRealtimePanelMode.touch) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: SizedBox.expand(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(
                alpha: generating ? 0.09 : 0.14,
              ),
              foregroundColor: Colors.white.withValues(
                alpha: generating ? 0.40 : 0.85,
              ),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.19)),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: generating || busy ? null : onTouchStart,
            child: Text(generating ? '在画面上拖拽，用轨迹控制角色' : '点击开始生成'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF272728),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                controller: promptController,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onPromptSubmit(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration.collapsed(
                  hintText: '输入你想要的效果',
                  hintStyle: TextStyle(color: Color(0x80FFFFFF), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CircleAction(
              tooltip: '添加参考图',
              onPressed: busy ? null : onPromptReference,
              child: promptReference == null
                  ? const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white,
                      size: 16,
                    )
                  : _ReferenceImage(reference: promptReference!, radius: 14),
            ),
            const SizedBox(width: 8),
            _CircleAction(
              tooltip: '提交自定义模式描述',
              backgroundColor: const Color(0xFFFF2E88),
              onPressed: busy || promptController.text.trim().isEmpty
                  ? null
                  : onPromptSubmit,
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

final class _ReferenceStrip extends StatefulWidget {
  const _ReferenceStrip({
    required this.references,
    required this.selectedReference,
    required this.uploadingReference,
    required this.onReferenceChanged,
    required this.onAddReference,
  });

  final List<XLabRealtimeReference> references;
  final XLabRealtimeReference? selectedReference;
  final bool uploadingReference;
  final ValueChanged<XLabRealtimeReference?> onReferenceChanged;
  final VoidCallback onAddReference;

  @override
  State<_ReferenceStrip> createState() => _ReferenceStripState();
}

final class _ReferenceStripState extends State<_ReferenceStrip> {
  final Map<String, GlobalKey> _referenceKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scheduleCenterSelectedReference();
  }

  @override
  void didUpdateWidget(covariant _ReferenceStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = _selectedIndex(oldWidget);
    final newIndex = _selectedIndex(widget);
    if (oldWidget.selectedReference?.id != widget.selectedReference?.id ||
        oldIndex != newIndex) {
      _scheduleCenterSelectedReference();
    }
  }

  int _selectedIndex(_ReferenceStrip target) {
    final selectedID = target.selectedReference?.id;
    if (selectedID == null) return -1;
    return target.references.indexWhere((item) => item.id == selectedID);
  }

  void _scheduleCenterSelectedReference() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedID = widget.selectedReference?.id;
      if (selectedID == null) return;
      final itemContext = _referenceKeys[selectedID]?.currentContext;
      if (itemContext == null) return;
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 6),
    itemCount: widget.references.length + 1,
    separatorBuilder: (_, _) => const SizedBox(width: 10),
    itemBuilder: (context, index) {
      if (index == 0) {
        return _AddReferenceButton(
          uploading: widget.uploadingReference,
          onPressed: widget.uploadingReference ? null : widget.onAddReference,
        );
      }
      final reference = widget.references[index - 1];
      final selected = widget.selectedReference?.id == reference.id;
      return GestureDetector(
        key: _referenceKeys.putIfAbsent(reference.id, GlobalKey.new),
        onTap: () => widget.onReferenceChanged(selected ? null : reference),
        child: Container(
          width: 44,
          height: 44,
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: _ReferenceImage(reference: reference),
              ),
              if (selected)
                Positioned(
                  top: -2,
                  right: -2,
                  bottom: -2,
                  left: -2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: const Color(0xFFFF2E88),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

final class _AddReferenceButton extends StatelessWidget {
  const _AddReferenceButton({required this.uploading, required this.onPressed});

  final bool uploading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF303032),
        borderRadius: BorderRadius.circular(9),
      ),
      child: uploading
          ? const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, color: Colors.white, size: 19),
                Text('参考图', style: TextStyle(color: Colors.white, fontSize: 9)),
              ],
            ),
    ),
  );
}

final class _ReferenceImage extends StatelessWidget {
  const _ReferenceImage({required this.reference, this.radius});

  final XLabRealtimeReference reference;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final bytes = reference.iconBytes;
    final url = reference.iconURL;
    final image = bytes != null
        ? Image.memory(
            bytes,
            width: radius == null ? 44 : radius! * 2,
            height: radius == null ? 44 : radius! * 2,
            fit: BoxFit.cover,
          )
        : url == null
        ? const ColoredBox(
            color: Color(0xFF303032),
            child: Icon(Icons.image_outlined, color: Colors.white54),
          )
        : Image.network(
            url,
            width: radius == null ? 44 : radius! * 2,
            height: radius == null ? 44 : radius! * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFF303032),
              child: Icon(Icons.image_outlined, color: Colors.white54),
            ),
          );
    if (radius == null) return image;
    return ClipOval(child: image);
  }
}

final class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.backgroundColor = const Color(0xFF3A3A3C),
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.2),
      ),
      onPressed: onPressed,
      icon: child,
    ),
  );
}
