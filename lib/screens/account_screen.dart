import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/local_data_service.dart';
import '../services/user_session.dart';
import 'splash_screen.dart';
import 'help_screen.dart';
import 'payment_accounts_screen.dart';
import 'safety_screen.dart';
import 'inbox_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'about_screen.dart';
import 'ride_history_screen.dart';
import 'promo_code_screen.dart';
import 'driver/driver_home_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _gold = Color(0xFFD4A843);

  Map<String, String>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await UserSession.getUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      slideFromRightRoute(_SettingsScreen()),
    );
    _loadUser(); // Refresh avatar & name after editing profile
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final firstName = _user?['firstName'] ?? 'User';
    final lastName = _user?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final photoPath = _user?['photoPath'] ?? '';

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
                    color: c.isDark ? c.surface : Colors.white,
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

              // ── Name + Photo row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name
                  Expanded(
                    child: Text(
                      fullName,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Profile photo
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: photoPath.isNotEmpty && (kIsWeb || File(photoPath).existsSync())
                          ? (kIsWeb
                              ? Image.network(
                                  photoPath,
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                  gaplessPlayback: true,
                                )
                              : Image.file(
                                  File(photoPath),
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                  filterQuality: FilterQuality.high,
                                  cacheWidth: 280,
                                  gaplessPlayback: true,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: child,
                                );
                              },
                            ))
                          : Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: c.textTertiary,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Menu grid ──
              _buildMenuGrid(c),

              const SizedBox(height: 28),

              // ── Favorites section ──
              Text(
                'Favorites',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildFavoriteItem(c, Icons.home_rounded, 'Add Home'),
              const SizedBox(height: 10),
              _buildFavoriteItem(c, Icons.work_rounded, 'Add Work'),
              const SizedBox(height: 10),
              _buildFavoriteItem(c, Icons.star_rounded, 'Add Place'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(AppColors c) {
    final items = [
      _MenuItem(Icons.help_outline_rounded, 'Help'),
      _MenuItem(Icons.account_balance_wallet_outlined, 'Wallet'),
      _MenuItem(Icons.history_rounded, 'Trips'),
      _MenuItem(Icons.local_offer_rounded, 'Promos'),
      _MenuItem(Icons.shield_outlined, 'Safety'),
      _MenuItem(Icons.mail_outline_rounded, 'Inbox'),
      _MenuItem(Icons.settings_outlined, 'Settings'),
      _MenuItem(Icons.directions_car_filled_rounded, 'Drive'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return GestureDetector(
          onTap: () async {
            switch (item.label) {
              case 'Help':
                Navigator.of(context).push(slideFromRightRoute(const HelpScreen()));
                break;
              case 'Wallet':
                Navigator.of(context).push(slideFromRightRoute(const PaymentAccountsScreen()));
                break;
              case 'Trips':
                Navigator.of(context).push(slideFromRightRoute(const RideHistoryScreen()));
                break;
              case 'Promos':
                Navigator.of(context).push(slideFromRightRoute(const PromoCodeScreen()));
                break;
              case 'Safety':
                Navigator.of(context).push(slideFromRightRoute(const SafetyScreen()));
                break;
              case 'Inbox':
                Navigator.of(context).push(slideFromRightRoute(const InboxScreen()));
                break;
              case 'Settings':
                _openSettings();
                break;
              case 'Drive':
                await UserSession.saveMode('driver');
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  slideFromRightRoute(const DriverHomeScreen()),
                  (_) => false,
                );
                break;
            }
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 48 - 12) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: item.label == 'Drive'
                  ? _gold.withValues(alpha: 0.10)
                  : (c.isDark ? c.surface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: item.label == 'Drive'
                  ? Border.all(color: _gold.withValues(alpha: 0.30))
                  : (c.isDark
                      ? null
                      : Border.all(color: Colors.black.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                Icon(item.icon,
                    color: item.label == 'Drive' ? _gold : c.textPrimary,
                    size: 24),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: item.label == 'Drive' ? FontWeight.w700 : FontWeight.w600,
                    color: item.label == 'Drive' ? _gold : c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onFavoriteTap(String label) async {
    final c = AppColors.of(context);

    final address = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FavoriteAddressSheet(c: c, label: label),
    );

    if (address == null || address.isEmpty) return;

    final favLabel = label.replaceAll('Add ', '');
    await LocalDataService.saveFavorite(FavoritePlace(label: favLabel, address: address));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$favLabel address saved'),
      backgroundColor: c.surface,
    ));
  }

  Widget _buildFavoriteItem(AppColors c, IconData icon, String label) {
    return GestureDetector(
      onTap: () => _onFavoriteTap(label),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: c.isDark
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 20),
        ],
      ),
    ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem(this.icon, this.label);
}

// ─────────────────────────────────────────────
// Settings Screen with Sign Out
// ─────────────────────────────────────────────
class _SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
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
                    color: c.isDark ? c.surface : Colors.white,
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

              // ── Title ──
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Settings options ──
              _settingsItem(
                c,
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () async {
                  await Navigator.of(context).push(
                    slideFromRightRoute(const EditProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _settingsItem(
                c,
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {
                  Navigator.of(context).push(
                    slideFromRightRoute(const NotificationSettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _settingsItem(
                c,
                icon: Icons.lock_outline_rounded,
                label: 'Privacy',
                onTap: () {
                  Navigator.of(context).push(
                    slideFromRightRoute(const PrivacyScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _settingsItem(
                c,
                icon: Icons.info_outline_rounded,
                label: 'About',
                onTap: () {
                  Navigator.of(context).push(
                    slideFromRightRoute(const AboutScreen()),
                  );
                },
              ),

              const Spacer(),

              // ── Sign Out button ──
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4A843),
                      side: const BorderSide(color: Color(0xFFD4A843), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout_rounded, size: 22),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsItem(
    AppColors c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: c.isDark ? c.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: c.isDark
              ? null
              : Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.textPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  void _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.of(context).textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFD4A843),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await UserSession.logout();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      smoothFadeRoute(const SplashScreen(), durationMs: 600),
      (_) => false,
    );
  }
}

// ---- Dedicated widget to avoid MediaQuery InheritedWidget dependency crash ----
class _FavoriteAddressSheet extends StatefulWidget {
  final AppColors c;
  final String label;
  const _FavoriteAddressSheet({required this.c, required this.label});

  @override
  State<_FavoriteAddressSheet> createState() => _FavoriteAddressSheetState();
}

class _FavoriteAddressSheetState extends State<_FavoriteAddressSheet>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  double _bottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateInsets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _updateInsets();
  }

  void _updateInsets() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final newInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (mounted && newInset != _bottomInset) {
      setState(() => _bottomInset = newInset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: _bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set ${widget.label} address',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(fontSize: 16, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter address...',
                hintStyle: TextStyle(color: c.textTertiary),
                filled: true,
                fillColor: c.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A843),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) Navigator.of(context).pop(text);
                },
                child: const Text('Save',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
