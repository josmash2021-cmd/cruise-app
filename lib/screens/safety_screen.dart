import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _gold = Color(0xFFE8C547);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: c.isDark
                        ? null
                        : Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Safety',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your safety is our priority.',
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Emergency ──
              _emergencyCard(c, context),
              const SizedBox(height: 24),

              // ── Safety features ──
              Text(
                'Safety Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _featureCard(
                c,
                icon: Icons.share_location_rounded,
                title: 'Share my trip',
                subtitle:
                    'Let friends and family follow your ride in real time.',
                onTap: () => _showComingSoon(context, c),
              ),
              const SizedBox(height: 10),
              _featureCard(
                c,
                icon: Icons.verified_user_outlined,
                title: 'Verify your ride',
                subtitle:
                    'Confirm your driver\'s identity before getting in.',
                onTap: () => _showComingSoon(context, c),
              ),
              const SizedBox(height: 10),
              _featureCard(
                c,
                icon: Icons.pin_drop_outlined,
                title: 'Trusted contacts',
                subtitle:
                    'Choose contacts who can follow your trips automatically.',
                onTap: () => _showComingSoon(context, c),
              ),
              const SizedBox(height: 10),
              _featureCard(
                c,
                icon: Icons.phone_in_talk_rounded,
                title: 'RideCheck',
                subtitle:
                    'We detect if your trip goes off route and check in on you.',
                onTap: () => _showComingSoon(context, c),
              ),
              const SizedBox(height: 10),
              _featureCard(
                c,
                icon: Icons.record_voice_over_outlined,
                title: 'Audio recording',
                subtitle:
                    'Record audio during your trip for added peace of mind.',
                onTap: () => _showComingSoon(context, c),
              ),

              const SizedBox(height: 28),

              // ── Safety tips ──
              Text(
                'Safety Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _tipItem(c, '1', 'Always verify your driver and vehicle before entering.'),
              const SizedBox(height: 8),
              _tipItem(c, '2', 'Share your trip with a trusted contact.'),
              const SizedBox(height: 8),
              _tipItem(c, '3', 'Sit in the back seat for added personal space.'),
              const SizedBox(height: 8),
              _tipItem(c, '4', 'Trust your instincts — cancel if something feels wrong.'),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emergencyCard(AppColors c, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emergency_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Call 911 for immediate assistance',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('tel:911');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.call_rounded, color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(
    AppColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: c.isDark
              ? null
              : Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _tipItem(AppColors c, String number, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: c.isDark
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 14, color: c.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, AppColors c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon'),
        backgroundColor: c.isDark ? c.surface : Colors.black87,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
