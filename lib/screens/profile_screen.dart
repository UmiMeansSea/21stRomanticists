import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:romanticists_app/app_theme.dart';

/// Placeholder — full implementation on Day 6 (profile + bookmarks).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: const Icon(Icons.person_outline,
                    size: 40, color: AppColors.outline),
              ),
              const SizedBox(height: 20),
              Text(
                'Clara Vellum',
                style: GoogleFonts.ebGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'POET & ESSAYIST',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Full profile with works, bookmarks\nand stats coming Day 6 →',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
