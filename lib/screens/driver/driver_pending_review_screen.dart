import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/page_transitions.dart';
import '../../services/api_service.dart';
import '../../services/local_data_service.dart';
import '../../services/user_session.dart';
import '../welcome_screen.dart';
import 'driver_home_screen.dart';

/// Shown after a driver submits their application.
/// Polls the backend every 5 seconds for dispatch approval.
/// The driver CANNOT navigate away — this is the gate.
class DriverPendingReviewScreen extends StatefulWidget {
  const DriverPendingReviewScreen({super.key});

  @override
  State<DriverPendingReviewScreen> createState() =>
      _DriverPendingReviewScreenState();
}

class _DriverPendingReviewScreenState extends State<DriverPendingReviewScreen>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFE8C547);

  Timer? _pollTimer;
  String _status = 'pending'; // pending | approved | rejected
  String? _rejectionReason;

  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final result = await ApiService.getDriverApprovalStatus();
        final status =
            result['approval_status'] as String? ??
            result['status'] as String? ??
            'pending';
        if (!mounted) return;

        if (status == 'approved') {
          _pollTimer?.cancel();
          await LocalDataService.setDriverApprovalStatus('approved');
          if (!mounted) return;
          setState(() => _status = 'approved');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            slideFromRightRoute(const DriverHomeScreen()),
            (_) => false,
          );
        } else if (status == 'rejected') {
          _pollTimer?.cancel();
          final reason =
              result['rejection_reason'] as String? ??
              result['reason'] as String? ??
              'Your application was not approved at this time.';
          await LocalDataService.setDriverApprovalStatus('rejected');
          if (!mounted) return;
          setState(() {
            _status = 'rejected';
            _rejectionReason = reason;
          });
        }
      } catch (_) {
        // Silently retry
      }
    });
  }

  Future<void> _logout() async {
    await UserSession.logout();
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _status == 'approved'
              ? _buildApproved()
              : _status == 'rejected'
              ? _buildRejected()
              : _buildPending(),
        ),
      ),
    );
  }

  // ── Pending ──────────────────────────────────────────────────────────────

  Widget _buildPending() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Animated pulsing icon
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.08 + _pulseCtrl.value * 0.06),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.3 + _pulseCtrl.value * 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(
                      alpha: 0.1 + _pulseCtrl.value * 0.15,
                    ),
                    blurRadius: 30 + _pulseCtrl.value * 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: _gold,
                size: 48,
              ),
            ),
          ),

          const SizedBox(height: 36),

          const Text(
            'Application Under Review',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Our dispatch team is reviewing your application and documents. This typically takes 24–48 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),

          // Status steps
          _statusRow(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'Application submitted',
            subtitle: 'All documents received',
            done: true,
          ),
          const SizedBox(height: 16),
          _statusRow(
            icon: Icons.shield_rounded,
            iconColor: _gold,
            title: 'Background check',
            subtitle: 'Checkr verification in progress',
            done: false,
            active: true,
          ),
          const SizedBox(height: 16),
          _statusRow(
            icon: Icons.verified_rounded,
            iconColor: Colors.white24,
            title: 'Final review',
            subtitle: 'Dispatch approval pending',
            done: false,
          ),

          const Spacer(flex: 3),

          // Dot animation
          _buildDots(),
          const SizedBox(height: 12),
          Text(
            'Checking for updates...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 32),

          // Logout button
          TextButton(
            onPressed: _logout,
            child: Text(
              'Log out',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, dot) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = ((_dotCtrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase : 1.0 - phase) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: opacity.clamp(0.2, 1.0)),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool done,
    bool active = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                : active
                ? _gold.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: done || active ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: done || active ? 0.5 : 0.25,
                  ),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (active) ...[
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.5 + _pulseCtrl.value * 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Approved ──────────────────────────────────────────────────────────────

  Widget _buildApproved() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4CAF50),
              size: 52,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'You\'re Approved!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to the Cruise driver team. You can now go online and start accepting rides.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: Color(0xFF4CAF50),
            strokeWidth: 2.5,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  // ── Rejected ──────────────────────────────────────────────────────────────

  Widget _buildRejected() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.cancel_rounded,
              color: Colors.redAccent,
              size: 52,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Application Not Approved',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          if (_rejectionReason != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Text(
                _rejectionReason!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 32),
          Text(
            'You may contact support or reapply with updated documents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Back to Welcome',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
