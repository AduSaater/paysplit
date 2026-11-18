import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _ngnFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  static final NumberFormat _ngnNoDecimals = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  /// Formats an amount in kobo (1 NGN = 100 kobo) to ₦850,000.00
  static String formatKobo(num? kobo, {bool showDecimals = true}) {
    final amount = (kobo ?? 0) / 100.0;
    return showDecimals
        ? _ngnFormat.format(amount)
        : _ngnNoDecimals.format(amount);
  }

  /// Formats signed kobo (e.g. +₦50,000.00 or -₦30,000.00)
  static String formatSignedKobo(num? kobo) {
    final value = kobo ?? 0;
    final prefix = value > 0 ? '+' : (value < 0 ? '-' : '');
    return '$prefix${formatKobo(value.abs())}';
  }

  /// Parses Naira string (e.g. "50,000.50") into integer kobo (5000050).
  static int? parseNairaToKobo(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll('₦', '').trim();
    if (cleaned.isEmpty) return null;
    final naira = double.tryParse(cleaned);
    if (naira == null) return null;
    return (naira * 100).round();
  }

  /// Converts kobo to Naira string for editing in text fields.
  static String koboToEditableNaira(num? kobo) {
    if (kobo == null || kobo == 0) return '';
    final naira = kobo / 100.0;
    if (naira == naira.roundToDouble()) {
      return naira.toInt().toString();
    }
    return naira.toStringAsFixed(2);
  }
}
