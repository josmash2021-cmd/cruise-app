import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/page_transitions.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../splash_screen.dart';
import 'driver_vehicle_screen.dart';
import 'driver_documents_screen.dart';
import 'driver_settings_screen.dart';
import 'driver_profile_screen.dart';
import 'cruise_level_screen.dart';
import 'payout_methods_screen.dart';
import 'driver_scheduled_trips_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  CRUISE DRIVER — FULL-SCREEN MENU (Uber Driver style)
//  Profile card, quick actions, sectioned list
// ═══════════════════════════════════════════════════════════════

class DriverMenuScreen extends StatefulWidget {
  const DriverMenuScreen({super.key});

  @override
  State<DriverMenuScreen> createState() => _DriverMenuScreenState();
}

class _DriverMenuScreenState extends State<DriverMenuScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFE8C547);
  static const _goldLight = Color(0xFFF5D990);
  static const _bg = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF111111);
  static const _card = Color(0xFF1C1C1E);

  // ── Dynamic profile data ──
  String _driverName = 'Cruise Driver';
  String _tierName = 'Gold';
  String _rating = '—';
  String? _photoUrl;

  late AnimationController _entranceCtrl;
  late Animation<double> _entranceAnim;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _entranceAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await ApiService.getMe();
      if (me != null && mounted) {
        final first = me['first_name'] ?? '';
        final last = me['last_name'] ?? '';
        setState(() {
          _driverName = last.toString().isNotEmpty
              ? '$first ${last.toString()[0].toUpperCase()}.'
              : first.toString();
          _photoUrl = me['photo_url']?.toString();
          final role = me['role']?.toString();
          if (role == 'driver') _tierName = 'Gold';
          final r = me['acceptance_rate'] ?? me['rating'];
          if (r != null) _rating = '$r%';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Top bar ──
          Container(
            color: _surface,
            padding: EdgeInsets.only(
              top: top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40), // balance close button
              ],
            ),
          ),

          // ── Scrollable content ──
          Expanded(
            child: FadeTransition(
              opacity: _entranceAnim,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  const SizedBox(height: 16),

                  // ── Profile card ──
                  _profileCard(context),

                  const SizedBox(height: 20),

                  // ── Quick actions row: Help, Safety, Settings ──
                  _quickActionsRow(context),

                  const SizedBox(height: 28),

                  // ── More ways to earn ──
                  _sectionHeader('More ways to earn'),
                  _item(
                    context,
                    Icons.trending_up_rounded,
                    'Opportunities',
                    'Find more earnings',
                    () => _snack(context, 'Opportunities'),
                  ),
                  _item(
                    context,
                    Icons.workspace_premium_rounded,
                    'Cruise Level',
                    'Green → Gold → Platinum → Diamond',
                    () {
                      Navigator.of(
                        context,
                      ).push(slideFromRightRoute(const CruiseLevelScreen()));
                    },
                  ),
                  _item(
                    context,
                    Icons.work_outline_rounded,
                    'Work Hub',
                    'Delivery & services',
                    () => _snack(context, 'Work Hub'),
                  ),
                  _item(
                    context,
                    Icons.person_add_rounded,
                    'Refer Friends',
                    'Earn bonuses',
                    () => _snack(context, 'Refer a friend'),
                  ),

                  const SizedBox(height: 24),

                  // ── Manage ──
                  _sectionHeader('Manage'),
                  _item(
                    context,
                    Icons.event_note_rounded,
                    'Scheduled Trips',
                    'Upcoming assigned rides',
                    () {
                      Navigator.of(context).push(
                        slideFromRightRoute(const DriverScheduledTripsScreen()),
                      );
                    },
                  ),
                  _item(
                    context,
                    Icons.directions_car_rounded,
                    'Vehicles',
                    'Your car details',
                    () {
                      Navigator.of(
                        context,
                      ).push(slideFromRightRoute(const DriverVehicleScreen()));
                    },
                  ),
                  _item(
                    context,
                    Icons.description_rounded,
                    'Documents',
                    'License & insurance',
                    () {
                      Navigator.of(context).push(
                        slideFromRightRoute(const DriverDocumentsScreen()),
                      );
                    },
                  ),
                  _item(
                    context,
                    Icons.security_rounded,
                    'Insurance',
                    'Coverage info',
                    () => _snack(context, 'Insurance'),
                  ),

                  const SizedBox(height: 24),

                  // ── Money ──
                  _sectionHeader('Money'),
                  _item(
                    context,
                    Icons.receipt_long_rounded,
                    'Tax Info',
                    'Tax documents & forms',
                    () => _snack(context, 'Tax Info'),
                  ),
                  _item(
                    context,
                    Icons.account_balance_rounded,
                    'Payout methods',
                    'Bank & payment setup',
                    () {
                      Navigator.of(
                        context,
                      ).push(slideFromRightRoute(const PayoutMethodsScreen()));
                    },
                  ),
                  _item(
                    context,
                    Icons.credit_card_rounded,
                    'Plus Card',
                    'Cruise debit card',
                    () => _snack(context, 'Plus Card'),
                  ),

                  const SizedBox(height: 24),

                  // ── Resources ──
                  _sectionHeader('Resources'),
                  _item(
                    context,
                    Icons.school_rounded,
                    'Learning Center',
                    'Tips & guides',
                    () => _snack(context, 'Learning Center'),
                  ),
                  _item(
                    context,
                    Icons.bug_report_rounded,
                    'Bug Reporter',
                    'Report issues',
                    () => _snack(context, 'Bug Reporter'),
                  ),
                  _item(
                    context,
                    Icons.info_outline_rounded,
                    'About',
                    'Cruise Driver v1.0.0',
                    () => _snack(context, 'About'),
                  ),

                  const SizedBox(height: 24),
                  _divider(),
                  const SizedBox(height: 8),

                  // ── Sign out ──
                  _item(
                    context,
                    Icons.logout_rounded,
                    'Sign out',
                    'Log out of your account',
                    () {
                      _showSignOut(context);
                    },
                    danger: true,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PROFILE CARD (Uber style: photo, name, Gold badge, rating)
  // ═══════════════════════════════════════════════════
  Widget _profileCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(
          context,
        ).push(slideFromRightRoute(const DriverProfileScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_gold, _goldLight]),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _photoUrl!,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _driverName.isNotEmpty
                            ? _driverName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _driverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Tier badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_gold, _goldLight],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: Colors.black,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _tierName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Rating
                      const Icon(Icons.star_rounded, color: _gold, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        _rating,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  QUICK ACTIONS ROW: Help, Safety, Settings
  // ═══════════════════════════════════════════════════
  Widget _quickActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _quickAction(context, Icons.help_outline_rounded, 'Help', () {
            _showHelp(context);
          }),
          const SizedBox(width: 10),
          _quickAction(context, Icons.shield_outlined, 'Safety', () {
            _snack(context, 'Safety features');
          }),
          const SizedBox(width: 10),
          _quickAction(context, Icons.settings_rounded, 'Settings', () {
            Navigator.of(
              context,
            ).push(slideFromRightRoute(const DriverSettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _quickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SECTION HEADER
  // ═══════════════════════════════════════════════════
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  MENU ITEM
  // ═══════════════════════════════════════════════════
  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap, {
    bool accent = false,
    bool danger = false,
  }) {
    final Color iconColor = danger
        ? const Color(0xFFCC3333)
        : accent
        ? _gold
        : Colors.white.withValues(alpha: 0.6);
    final Color titleColor = danger
        ? const Color(0xFFCC3333)
        : accent
        ? _gold
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: danger
                ? const Color(0xFFCC3333).withValues(alpha: 0.1)
                : accent
                ? _gold.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.1),
          size: 20,
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: Colors.white.withValues(alpha: 0.06)),
    );
  }

  // ═══════════════════════════════════════════════════
  //  HELP BOTTOM SHEET
  // ═══════════════════════════════════════════════════
  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.help_outline_rounded, color: _gold, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Help & Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            _helpRow(Icons.phone_rounded, 'Call Support', '+1 (800) CRUISE'),
            _helpRow(Icons.email_rounded, 'Email Us', 'driver@cruise.app'),
            _helpRow(Icons.chat_rounded, 'Live Chat', 'Available 24/7'),
            _helpRow(Icons.library_books_rounded, 'FAQ', 'Common questions'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(IconData icon, String t, String s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _gold, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    s,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SIGN OUT CONFIRMATION
  // ═══════════════════════════════════════════════════
  void _showSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserSession.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                smoothFadeRoute(const SplashScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC3333),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
