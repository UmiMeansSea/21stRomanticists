import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/theme_provider.dart';

/// Premium settings screen — account management, app info, sign-out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _version = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Account section ──────────────────────────────────────────────
          _SectionHeader(label: 'Account'),

          if (user != null) ...[
            // User card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border.all(color: AppColors.outlineVariant, width: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.secondary,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              (user.displayName?.isNotEmpty == true
                                      ? user.displayName![0]
                                      : user.email?[0] ?? 'R')
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.displayName?.isNotEmpty == true)
                            Text(
                              user.displayName!,
                              style: GoogleFonts.ebGaramond(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface,
                              ),
                            ),
                          Text(
                            user.email ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _SettingsTile(
              icon: Icons.person_outline,
              label: 'My Profile',
              onTap: () { context.pop(); context.go('/profile'); },
            ),
            _SettingsTile(
              icon: Icons.edit_note_outlined,
              label: 'My Submissions',
              onTap: () { context.pop(); context.go('/profile'); },
            ),
            _SettingsTile(
              icon: Icons.bookmark_border_outlined,
              label: 'Saved Posts',
              onTap: () { context.pop(); context.go('/bookmarks'); },
            ),
            _DividerTile(),
            _SettingsTile(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              labelColor: AppColors.error,
              iconColor: AppColors.error,
              onTap: () => _confirmSignOut(context, auth),
            ),
          ] else ...[
            _SettingsTile(
              icon: Icons.login_outlined,
              label: 'Sign In / Create Account',
              onTap: () { context.pop(); context.push('/login'); },
            ),
          ],

          const SizedBox(height: 8),

          // ── Content section ──────────────────────────────────────────────
          _SectionHeader(label: 'Content'),
          _SettingsTile(
            icon: Icons.home_outlined,
            label: 'Home Feed',
            onTap: () { context.pop(); context.go('/'); },
          ),
          _SettingsTile(
            icon: Icons.auto_stories_outlined,
            label: 'Read',
            onTap: () { context.pop(); context.go('/read'); },
          ),

          const SizedBox(height: 8),

          // ── Appearance section ──────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          Consumer<ThemeProvider>(
            builder: (context, theme, child) {
              return SwitchListTile(
                secondary: Icon(
                  theme.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Dark Mode',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                value: theme.isDarkMode,
                onChanged: (value) => theme.toggleTheme(value),
                activeColor: Theme.of(context).colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── About section ────────────────────────────────────────────────
          _SectionHeader(label: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'App Version',
            trailing: Text(
              _version,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.auto_stories,
            label: 'The 21st Romanticists',
            subtitle: 'A literary platform for poets and authors.',
          ),
          _SettingsTile(
            icon: Icons.mail_outline,
            label: 'Submit Your Work',
            onTap: () { context.pop(); context.go('/write'); },
          ),

          const SizedBox(height: 40),

          // Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '— The pen is mightier than the algorithm —',
              textAlign: TextAlign.center,
              style: GoogleFonts.ebGaramond(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.outline,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text('Sign Out',
            style: GoogleFonts.ebGaramond(fontSize: 22, fontWeight: FontWeight.w500)),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.literata(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.signOut();
              if (context.mounted) context.go('/');
            },
            child: Text('Sign Out',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Reusable tile components ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? labelColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: iconColor ?? AppColors.onSurfaceVariant),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: labelColor ?? AppColors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.literata(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, size: 18,
                  color: AppColors.outline)
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _DividerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(thickness: 0.4, height: 1),
    );
  }
}
