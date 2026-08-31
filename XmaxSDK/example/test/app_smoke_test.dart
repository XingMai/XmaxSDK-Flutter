import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/app.dart';

void main() {
  testWidgets('shows the supported capability entry points', (tester) async {
    await tester.pumpWidget(const XmaxSdkExampleApp());

    expect(find.text('XmaxSDK'), findsOneWidget);
    expect(find.textContaining('Flutter 1.0.0'), findsOneWidget);
    expect(find.textContaining('摄像头实时流'), findsOneWidget);
    expect(find.textContaining('自定义轨迹渲染'), findsOneWidget);
    expect(find.textContaining('存储服务'), findsOneWidget);
  });
}
