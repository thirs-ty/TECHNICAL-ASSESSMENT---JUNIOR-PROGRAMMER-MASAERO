import 'package:flutter_test/flutter_test.dart';
import 'package:masaero_booking_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const BookingApp());
  });
}