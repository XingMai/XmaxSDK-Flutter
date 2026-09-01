import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

void main() {
  test('reports the package version', () {
    expect(XmaxSDKInfo.version, '1.0.0');
  });
}
