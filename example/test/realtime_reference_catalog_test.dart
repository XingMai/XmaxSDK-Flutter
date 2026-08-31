import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/realtime/realtime_control_panel.dart';

void main() {
  testWidgets('loads the complete iOS-aligned realtime reference catalog', (
    tester,
  ) async {
    final references = await loadXLabRealtimeReferences();

    expect(references, hasLength(51));
    expect(
      references.where((reference) => reference.categoryID == 'charx'),
      hasLength(12),
    );
    expect(
      references.where((reference) => reference.categoryID == 'clothx'),
      hasLength(12),
    );
    expect(
      references.where((reference) => reference.categoryID == 'vibex'),
      hasLength(15),
    );
    expect(
      references.where((reference) => reference.categoryID == 'dimx'),
      hasLength(12),
    );
  });
}
