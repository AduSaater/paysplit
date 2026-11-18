import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import 'auth_provider.dart';

/// Matches Figma "Account Creation Success" screen:
/// - Sunburst radial background at top
/// - Blue circular checkmark badge
/// - "Welcome to PaySplit, `<FirstName>`"
/// - Step 1 (Profile & Identity Verification) & Step 2 (Setup Checklist) cards
/// - Bottom row: "Go to Dashboard" | "Continue to KYC"
class AccountSuccessScreen extends ConsumerWidget {
  const AccountSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName =
        ref.watch(authProvider).user?['firstName']?.toString() ?? '';
    final greeting = firstName.isNotEmpty
        ? 'Welcome to PaySplit, $firstName'
        : 'Welcome to PaySplit';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: ClipRect(
              child: CustomPaint(painter: _SuccessSunburstPainter()),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    greeting,
                    style: AppTextStyles.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your account has been created successfully. Let's personalise your profile and set up your salary partitions in under 3 minutes.",
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  const _SuccessStepCard(
                    step: 'Step 1',
                    title: 'Profile & Identity Verification',
                    subtitle: 'Biometric liveness',
                    active: true,
                  ),
                  SizedBox(
                    height: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 2,
                          height: 3,
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  const _SuccessStepCard(
                    step: 'Step 2',
                    title: 'Setup Checklist',
                    subtitle: 'Income, vaults & rules',
                    active: false,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/dashboard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Go to Dashboard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go('/kyc'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Continue to KYC'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessStepCard extends StatelessWidget {
  const _SuccessStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final String step;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  step,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _SuccessSunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final center = Offset(size.width / 2, 110);
    final paint = Paint()
      ..color = AppColors.background.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 3.14159 * 2) / 12;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: size.width),
          angle,
          0.14,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
