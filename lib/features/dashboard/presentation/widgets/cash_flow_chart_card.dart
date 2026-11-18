import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';

/// Matches Figma "Salary Allocation & Split Cash Flow" card using live API data.
class CashFlowChartCard extends StatelessWidget {
  const CashFlowChartCard({
    super.key,
    required this.cashFlow,
    required this.monthlySalaryKobo,
    required this.hideBalance,
  });

  final Map<String, dynamic> cashFlow;
  final num monthlySalaryKobo;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final buckets = (cashFlow['buckets'] as List<dynamic>?) ??
        (cashFlow['series'] as List<dynamic>?) ??
        (cashFlow['items'] as List<dynamic>?) ??
        const [];

    final changePct = cashFlow['changePercent'] as num?;
    final total = (cashFlow['totalAmount'] ?? monthlySalaryKobo) as num;

    final chartItems = buckets.take(6).map((b) {
      final m = b as Map<String, dynamic>;
      return _BarPoint(
        label: (m['label'] ?? m['month'] ?? '').toString(),
        wallets: ((m['wallets'] ?? m['walletTotal'] ?? 0) as num).toDouble(),
        beneficiaries:
            ((m['beneficiaries'] ?? m['beneficiaryTotal'] ?? 0) as num)
                .toDouble(),
        isHighlighted: m['isCurrent'] == true,
      );
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Salary Allocation & Split Cash Flow',
            style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hideBalance
                    ? '••••••'
                    : CurrencyFormatter.formatKobo(total, showDecimals: false),
                style: AppTextStyles.headlineMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (changePct != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${changePct >= 0 ? '+' : ''}$changePct%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: changePct >= 0 ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text('from last month', style: AppTextStyles.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _DotLabel(color: AppColors.primary, label: 'Wallets'),
              SizedBox(width: 16),
              _DotLabel(
                  color: AppColors.textPrimary, label: 'Recipient/Beneficiaries'),
            ],
          ),
          const SizedBox(height: 18),
          if (chartItems.isEmpty)
            Container(
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No cash flow history yet.\nSplits will be charted here automatically.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _CashFlowPainter(points: chartItems),
                size: const Size(double.infinity, 160),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: chartItems
                  .map(
                    (p) => Text(
                      p.label,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DotLabel extends StatelessWidget {
  const _DotLabel({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _BarPoint {
  const _BarPoint({
    required this.label,
    required this.wallets,
    required this.beneficiaries,
    this.isHighlighted = false,
  });

  final String label;
  final double wallets;
  final double beneficiaries;
  final bool isHighlighted;
}

class _CashFlowPainter extends CustomPainter {
  _CashFlowPainter({required this.points});
  final List<_BarPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final maxVal = points.fold<double>(
      1.0,
      (prev, p) => [prev, p.wallets, p.beneficiaries]
          .reduce((a, b) => a > b ? a : b),
    );

    final dashPaint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 1;
    const dashW = 5.0;
    for (double x = 0; x < size.width; x += dashW * 2) {
      canvas.drawLine(Offset(x, midY), Offset(x + dashW, midY), dashPaint);
    }

    final slotW = size.width / points.length;
    const barW = 24.0;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = slotW * i + slotW / 2;

      if (p.wallets > 0) {
        final h = (p.wallets / maxVal) * (midY - 10);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, midY - h, barW, h),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = p.isHighlighted
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.14),
        );
        canvas.drawLine(
          Offset(cx - barW / 2 + 2, midY - h),
          Offset(cx + barW / 2 - 2, midY - h),
          Paint()
            ..color = AppColors.primary
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }

      if (p.beneficiaries > 0) {
        final h = (p.beneficiaries / maxVal) * (midY - 10);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, midY, barW, h),
          bottomLeft: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = p.isHighlighted
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.08),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}
