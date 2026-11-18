import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysplit/core/utils/currency_formatter.dart';
import 'package:paysplit/core/utils/validators.dart';
import 'package:paysplit/core/widgets/status_badge.dart';
import 'package:paysplit/core/widgets/app_button.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats kobo to NGN currency string', () {
      expect(CurrencyFormatter.formatKobo(60000000), '₦600,000.00');
      expect(CurrencyFormatter.formatKobo(0), '₦0.00');
    });

    test('parses Naira input string to integer kobo', () {
      expect(CurrencyFormatter.parseNairaToKobo('50,000'), 5000000);
      expect(CurrencyFormatter.parseNairaToKobo('1250.50'), 125050);
    });
  });

  group('Validators', () {
    test('validates 10-digit NUBAN and 11-digit BVN/NIN', () {
      expect(Validators.nuban('0123456789'), isNull);
      expect(Validators.nuban('12345'), isNotNull);
      expect(Validators.bvnOrNin('22234918239'), isNull);
      expect(Validators.bvnOrNin('123'), isNotNull);
    });

    test('validates strong password requirements', () {
      expect(Validators.strongPassword('P@ssword123'), isNull);
      expect(Validators.strongPassword('weak'), isNotNull);
    });
  });

  group('Reusable Widgets', () {
    testWidgets('StatusBadge renders capitalized status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(status: 'active')),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('AppPrimaryButton shows spinner when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPrimaryButton(
              label: 'Save',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });
  });
}
