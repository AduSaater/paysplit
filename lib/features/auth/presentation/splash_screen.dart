import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';

/// Matches Figma Splash Screen (node 6119:2154):
/// Full-bleed #33A7F5 background with centered 80x80 PaySplit SVG mark.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Semantics(
          label: 'PaySplit logo',
          child: SvgPicture.asset(
            'assets/images/paysplit_logo.svg',
            width: 80,
            height: 80,
          ),
        ),
      ),
    );
  }
}
