import 'dart:typed_data';

import 'package:flutter/material.dart';

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
}

const xLabRealtimeReferences = <XLabRealtimeReference>[
  XLabRealtimeReference(
    id: 'xgp-53f286ca852e494c',
    categoryID: 'charx',
    title: '奶龙',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/UOOdbmssxobSxox6sPGcpIRjndd.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/HjBSbgbjtoEMzzxLi5jc6iq9nMe.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-edacd6760a584092',
    categoryID: 'charx',
    title: '喜多川海梦',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/Wlqcba19korj2zxQZl0cQpJRnhD.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/BlSXbbvUpoVvBoxo2KDcoS2nnxh.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-90545d73d5a04111',
    categoryID: 'charx',
    title: '黄昏',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/TCvFbZQASokaU8xJMzkcQUv8nXb.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/DRfmb3AJBof693xeVRhczhQ6ntb.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-92710eb588ac4379',
    categoryID: 'charx',
    title: '卡布奇诺',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/W2ZvbzQRyoEqgrxnpLLcO1iVnS5.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/charx/Na42b2qDfoslzexy553cqvZRn8B.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-541a9f88486a437c',
    categoryID: 'clothx',
    title: '女装',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/PerfbUxRdoGfADx70AJcQdEunse.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/VxRobHUleoX4hXxU2Jmc8X61nGh.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-c202ac728d394737',
    categoryID: 'clothx',
    title: '女装',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/YPERbHwinom0VBxgLfrcfqHVnvh.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/ZW0Db6FVnoDYxvxKW8Hci8GfnGh.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-8219a934f4cb4127',
    categoryID: 'clothx',
    title: '女装',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/Dq2xb499ioxVuOxCggKc9SVenmg.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/Fdp2bqvA1op6jcxOhOccW6TanAg.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-3c48cf964ecb4708',
    categoryID: 'clothx',
    title: '女装',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/BrPlbbwlCoLkfTxYocHcTggTnze.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/clothx/CtjHbFmkEonao4xdR9mczjyPnYK.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-218ec86016674037',
    categoryID: 'vibex',
    title: '王者荣耀孙权',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/Yz3ybbA6iokGbDxpQBacCnI6n1m.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/JUZAbWyMQo0057x6FQ9cbVBGnjf.jpg',
  ),
  XLabRealtimeReference(
    id: 'xgp-84c0a6202c17420c',
    categoryID: 'vibex',
    title: '哪吒老大',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/DI6ebgUkCofFdRxMh8McoJmfnkf.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/M0DhbS86moarEIxMXkTce9TznW0.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-4c138317a3524f85',
    categoryID: 'vibex',
    title: '芭比特',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/ZdhNbWMuloryVmxCt78caKD6n86.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/GXJPbd2edoRQWpx5GLrcat6snbc.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-79f704db0763408b',
    categoryID: 'vibex',
    title: '神代类',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/JnCCbS7yyoAd39xenRgcQUY3nUe.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/vibex/V9dnboWqWoGiZJxa9F8cjqZLnEf.jpg',
  ),
  XLabRealtimeReference(
    id: 'xgp-61e24b1672dc4d5e',
    categoryID: 'dimx',
    title: '光头强',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/LHzEbR8DTowxLUxsDKBcX2ginag.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/EdUubKIAfoBw3pxKMSBcWbI5nkb.jpg',
  ),
  XLabRealtimeReference(
    id: 'xgp-7ca6c15cdd844ae3',
    categoryID: 'dimx',
    title: '熊二',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/GmVqbAQZroGe5jxemYkcIgv3nFf.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/Np1qbz5l1oetgVxUkxpcqapOnJh.jpg',
  ),
  XLabRealtimeReference(
    id: 'xgp-7a85e596eed34fb8',
    categoryID: 'dimx',
    title: '流萤',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/K7sLbUE8goU6WPxKAdqcAMEtnCb.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/Rca8brql3o8pCfxWnl7cF3c7nFg.png',
  ),
  XLabRealtimeReference(
    id: 'xgp-ef9b5ca7f4144954',
    categoryID: 'dimx',
    title: '祁煜',
    iconURL:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/No2ibdX85oTLaixSaigcTdqVneb.png',
    referencePath:
        'https://assets.ducktracks.fun/xlive/gameplay/feishu/dimx/H30nb42tuoeoMBxAmqqc6apDnnc.jpg',
  ),
];

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
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
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
                      size: 20,
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
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = XLabRealtimePanelMode.values[index];
                      final selected = item == mode;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: busy ? null : () => onModeChanged(item),
                        child: Center(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: selected ? 1 : 0.48,
                              ),
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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

final class _ReferenceStrip extends StatelessWidget {
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
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.only(left: 14, right: 14),
    itemCount: references.length + 1,
    separatorBuilder: (_, _) => const SizedBox(width: 10),
    itemBuilder: (context, index) {
      if (index == 0) {
        return _AddReferenceButton(
          uploading: uploadingReference,
          onPressed: uploadingReference ? null : onAddReference,
        );
      }
      final reference = references[index - 1];
      final selected = selectedReference?.id == reference.id;
      return GestureDetector(
        onTap: () => onReferenceChanged(selected ? null : reference),
        child: Container(
          width: 50,
          height: 50,
          padding: EdgeInsets.all(selected ? 2 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFFFF2E88), width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(selected ? 8 : 10),
            child: _ReferenceImage(reference: reference),
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF303032),
        borderRadius: BorderRadius.circular(10),
      ),
      child: uploading
          ? const Padding(
              padding: EdgeInsets.all(15),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, color: Colors.white, size: 22),
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
            width: radius == null ? 50 : radius! * 2,
            height: radius == null ? 50 : radius! * 2,
            fit: BoxFit.cover,
          )
        : url == null
        ? const ColoredBox(
            color: Color(0xFF303032),
            child: Icon(Icons.image_outlined, color: Colors.white54),
          )
        : Image.network(
            url,
            width: radius == null ? 50 : radius! * 2,
            height: radius == null ? 50 : radius! * 2,
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
