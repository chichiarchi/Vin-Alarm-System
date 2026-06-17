import 'package:flutter_test/flutter_test.dart';
import 'package:vin_alarm_system/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VinAlarmApp());
    expect(find.text("Vin's Alarm"), findsOneWidget);
  });
}
