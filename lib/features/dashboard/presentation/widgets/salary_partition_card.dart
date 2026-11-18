import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';

/// Matches Figma "Salary Partition" card with dual-arc gauge (Wallets vs Beneficiaries)
/// and Spend Account Remainder in the center.
class SalaryPartitionCard extends StatelessWidget {
  const SalaryPartitionCard({
    super.key,
    required this.walletsKobo,
    required this.beneficiariesKobo,
    required this.remainderKobo,
    required this.remainderPercent,
    required this.hideBalance,
    required this.onSeeRules,
  });

  final num walletsKobo;
  final num beneficiariesKobo;
  final num remainderKobo;
  final num remainderPercent;
  final bool hideBalance;
  final VoidCallback onSeeRules;

  @override
  Widget build(BuildContext context) {
    final total = walletsKobo + beneficiariesKobo + remainderKobo;
    final walletRatio = total > 0 ? (walletsKobo / total).toDouble() : 0.45;
    final benRatio = total > 0 ? (beneficiariesKobo / total).toDouble() : 0.27;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Salary Partition', style: AppTextStyles.titleMedium),
            InkWell(
              onTap: onSeeRules,
              child: Row(
                children: [
                  Text(
                    'See Rules',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 190,
                child: CustomPaint(
                  painter: _PartitionGaugePainter(
                    walletFraction: walletRatio,
                    beneficiaryFraction: benRatio,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Spend Account\nRemainder',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hideBalance
                              ? '••••••'
                              : CurrencyFormatter.formatKobo(
                                  remainderKobo,
                                  showDecimals: false,
                                ),
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${remainderPercent.toStringAsFixed(0)}% Left for Living',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _LegendMetric(
                      barColor: AppColors.primary,
                      amount: hideBalance
                          ? '••••••'
                          : CurrencyFormatter.formatKobo(
                              walletsKobo,
                              showDecimals: false,
                            ),
                      label: 'Wallets',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _LegendMetric(
                      barColor: AppColors.textPrimary,
                      amount: hideBalance
                          ? '••••••'
                          : CurrencyFormatter.formatKobo(
                              beneficiariesKobo,
                              showDecimals: false,
                            ),
                      label: 'Beneficiaries',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendMetric extends StatelessWidget {
  const _LegendMetric({
    required this.barColor,
    required this.amount,
    required this.label,
  });

  final Color barColor;
  final String amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    amount,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartitionGaugePainter extends CustomPainter {
  _PartitionGaugePainter({
    required this.walletFraction,
    required this.beneficiaryFraction,
  });

  final double walletFraction;
  final double beneficiaryFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    // Inner subtle dashed circle
    final innerPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dashCount = 36;
    final innerRadius = radius - 18;
    for (int i = 0; i < dashCount; i++) {
      final start = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        start,
        math.pi / dashCount,
        false,
        innerPaint,
      );
    }

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Left Blue Arc (Wallets)
    final walletSweep =
        (walletFraction.clamp(0.12, 0.75) * math.pi * 1.45).toDouble();
    final walletPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2 - 0.12,
      -walletSweep,
      false,
      walletPaint,
    );

    // Right Dark Arc (Beneficiaries)
    final benSweep =
        (beneficiaryFraction.clamp(0.12, 0.75) * math.pi * 1.45).toDouble();
    final benPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2 + 0.12,
      benSweep,
      false,
      benPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PartitionGaugePainter oldDelegate) {
    return oldDelegate.walletFraction != walletFraction ||
        oldDelegate.beneficiaryFraction != beneficiaryFraction;
  }
}
