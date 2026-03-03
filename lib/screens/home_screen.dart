import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'map_screen.dart';
import 'trip_receipt_screen.dart';
import 'account_screen.dart';
import '../config/api_keys.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/local_data_service.dart';
import '../services/places_service.dart';
import '../services/user_session.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Brand colors (same in both themes)
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF5D990);

  late AnimationController _shimmerController;
  String _selectedRider = 'You';
  List<FavoritePlace> _favorites = [];
  List<TripHistoryItem> _recentTrips = [];
  List<FrequentDestination> _topDestinations = [];
  List<AppNotificationItem> _notifications = [];
  bool _loadingSavedData = true;
  bool _hasActivePromo = false;
  int _dockIndex = 0; // 0=Ride, 1=Schedule, 2=Account

  // User profile data
  String _firstName = '';
  String _lastName = '';
  String? _photoPath;

  // Mini-map state
  GoogleMapController? _miniMapController;
  LatLng? _currentLatLng;
  String? _locationError;
  bool _imagesPrecached = false;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadSavedData();
    _fetchCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      // Precache car images so they display instantly
      for (final img in ['suburban', 'camry', 'fusion']) {
        precacheImage(AssetImage('assets/images/$img.png'), context);
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationError = 'Location services disabled');
        }
        return;
      }

      // 2. Check / request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (mounted) {
            setState(() => _locationError = 'Location permission denied');
          }
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => _locationError = 'Location permission permanently denied',
          );
        }
        return;
      }

      // 3. Try last known first for instant display
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
          _locationError = null;
        });
      }

      // 4. Fetch accurate position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _locationError = null;
      });
      _miniMapController?.animateCamera(
        CameraUpdate.newLatLng(_currentLatLng!),
      );

      // Start continuous location stream for always-centered map
      _locationSub?.cancel();
      _locationSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position p) {
            if (!mounted) return;
            final ll = LatLng(p.latitude, p.longitude);
            setState(() => _currentLatLng = ll);
            _miniMapController?.animateCamera(CameraUpdate.newLatLng(ll));
          });
    } catch (e) {
      if (mounted && _currentLatLng == null) {
        setState(() => _locationError = 'Unable to get location');
      }
    }
  }

  Future<void> _loadSavedData() async {
    // Check if a new monthly promo needs to be generated
    final newPromoGenerated =
        await LocalDataService.generateMonthlyPromoIfNeeded();
    if (newPromoGenerated) {
      await LocalDataService.addNotification(
        title: '🎉 New monthly discount!',
        message:
            'You have a new 10% discount available for your next ride. Tap the promo banner on the home screen to apply it!',
        type: 'promo',
      );
    }

    final favorites = await LocalDataService.getFavorites();
    final trips = await LocalDataService.getTripHistory();
    final topDestinations = await LocalDataService.getTopDestinations(limit: 3);
    final notifications = await LocalDataService.getNotifications();
    final user = await UserSession.getUser();
    final hasPromo = await LocalDataService.hasActivePromo();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _recentTrips = trips;
      _topDestinations = topDestinations;
      _notifications = notifications;
      _hasActivePromo = hasPromo;
      _loadingSavedData = false;
      if (user != null) {
        _firstName = user['firstName'] ?? '';
        _lastName = user['lastName'] ?? '';
        final path = user['photoPath'] ?? '';
        _photoPath = path.isNotEmpty ? path : null;
      }
    });
  }

  int get _unreadNotifications {
    return _notifications.where((item) => !item.read).length;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF07080D)
        : const Color(0xFFF2F2F7);

    // Theme color helpers — available for sub-build methods
    // ignore: unused_local_variable
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C1E);
    // ignore: unused_local_variable
    final textSub = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);
    // ignore: unused_local_variable
    final textMuted = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.40);
    // ignore: unused_local_variable
    final textFaint = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.35);
    // ignore: unused_local_variable
    final surface = isDark ? const Color(0xFF161820) : Colors.white;
    // ignore: unused_local_variable
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    // ignore: unused_local_variable
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    // ignore: unused_local_variable
    final iconMuted = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    // ignore: unused_local_variable
    final iconFaint = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.55);
    // ignore: unused_local_variable
    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    // ignore: unused_local_variable
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Mesh gradient background ──
          if (isDark) ...[
            Positioned(top: -60, right: -40, child: _glowOrb(180, _gold, 0.07)),
            Positioned(
              top: 300,
              left: -80,
              child: _glowOrb(260, _goldLight, 0.03),
            ),
            Positioned(
              bottom: 120,
              right: -60,
              child: _glowOrb(200, _gold, 0.04),
            ),
          ],

          // ── Main scroll content ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 800, // pre-render 800px off-screen for buttery scroll
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topPad + 16)),

              // ━━━ TOP BAR: greeting + avatar + bell ━━━
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTopBar(),
                ),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 28)),

              // ━━━ HERO: "Where to?" large CTA card ━━━
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildHeroCTA(),
                ),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 28)),

              // ━━━ CIRCULAR ACTION BUTTONS ━━━
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildCircularActions(),
                ),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 36)),

              // ━━━ FLEET: Full-width stacked cards ━━━
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionHeader('Your Fleet', 'View all', () {
                    Navigator.of(context).push(
                      slideUpFadeRoute(const MapScreen(openPlanOnStart: true)),
                    );
                  }),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _buildFleetStack(screenW)),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 36)),

              // ━━━ SAVED PLACES ━━━
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionHeader('Quick Access', null, null),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildQuickAccessGrid(),
                ),
              ),

              // ━━━ RECENT TRIPS (timeline style) ━━━
              if (_recentTrips.isNotEmpty) ...[
                SliverToBoxAdapter(child: const SizedBox(height: 36)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSectionHeader('Recent Activity', null, null),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildRecentTimeline(),
                  ),
                ),
              ] else if (_loadingSavedData) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _gold.withValues(alpha: 0.5),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ━━━ LIVE MAP CARD ━━━
              SliverToBoxAdapter(child: const SizedBox(height: 36)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionHeader('Live Location', null, null),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: RepaintBoundary(child: _buildLiveMapCard()),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 90 + bottomPad)),
            ],
          ),

          // ── Dock-style bottom navigation ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildDockNav(context, bottomPad),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  W I D G E T S
  // ════════════════════════════════════════════════════

  Widget _glowOrb(double size, Color color, double opacity) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar ───
  Widget _buildTopBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final initials = [
      if (_firstName.isNotEmpty) _firstName[0],
      if (_lastName.isNotEmpty) _lastName[0],
    ].join().toUpperCase();
    final displayInitial = initials.isNotEmpty ? initials : '?';
    final displayName = [
      if (_firstName.isNotEmpty) _firstName,
      if (_lastName.isNotEmpty) _lastName,
    ].join(' ');
    final hasPhoto =
        _photoPath != null &&
        _photoPath!.isNotEmpty &&
        (kIsWeb || File(_photoPath!).existsSync());

    return Row(
      children: [
        // Greeting
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await Navigator.of(
                context,
              ).push(slideFromRightRoute(const AccountScreen()));
              _loadSavedData();
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting().toUpperCase(),
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName.isNotEmpty ? displayName : 'Rider',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Notification bell
        _glassIconButton(
          Icons.notifications_none_rounded,
          onTap: _openNotificationsSheet,
          badge: _unreadNotifications,
        ),
        const SizedBox(width: 12),

        // Avatar
        GestureDetector(
          onTap: () async {
            await Navigator.of(
              context,
            ).push(slideFromRightRoute(const AccountScreen()));
            _loadSavedData();
          },
          child: Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: hasPhoto
                  ? null
                  : const LinearGradient(colors: [_gold, _goldLight]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasPhoto
                ? (kIsWeb
                      ? Image.network(
                          _photoPath!,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          gaplessPlayback: true,
                        )
                      : Image.file(
                          File(_photoPath!),
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          cacheWidth: 200,
                          gaplessPlayback: true,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: child,
                                );
                              },
                        ))
                : Center(
                    child: Text(
                      displayInitial,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _glassIconButton(IconData icon, {VoidCallback? onTap, int badge = 0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Icon(
              icon,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_gold, _goldLight]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ─── Hero CTA Card ───
  Widget _buildHeroCTA() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(scaleExpandRoute(const MapScreen(openPlanOnStart: true))),
      child: ListenableBuilder(
        listenable: _shimmerController,
        builder: (context, child) {
          final v = _shimmerController.value;
          // Traveling glow around the border
          final glowAngle = v * 2 * 3.14159265; // ignore: unused_local_variable
          return Container(
            height: 140,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
            child: CustomPaint(
              painter: _GlowBorderPainter(
                progress: v,
                gold: _gold,
                goldLight: _goldLight,
                isDark: isDark,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF141210), Color(0xFF0C0B09)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [Colors.white, Colors.grey.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(
                        alpha: 0.06 + 0.08 * ((v * 3.14).clamp(0, 1)),
                      ),
                      blurRadius: 30 + 15 * v,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Where to?',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Search destination or tap to ride',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.45),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_gold, _goldLight],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black87,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Circular action buttons ───
  Widget _buildCircularActions() {
    final isDark =
        Theme.of(context).brightness ==
        Brightness.dark; // ignore: unused_local_variable
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleAction(Icons.bolt_rounded, 'Ride', [_gold, _goldLight], () {
          Navigator.of(
            context,
          ).push(slideUpFadeRoute(const MapScreen(openPlanOnStart: true)));
        }),
        _circleAction(Icons.schedule_rounded, 'Schedule', [
          Colors.white,
          Colors.white70,
        ], _openScheduleFlow),
        _circleAction(Icons.people_alt_rounded, _selectedRider, [
          Colors.white,
          Colors.white54,
        ], _openRiderPicker),
        if (_hasActivePromo)
          _circleAction(
            Icons.local_offer_rounded,
            '10% off',
            [_goldLight, _gold],
            () {
              Navigator.of(context).push(
                slideUpFadeRoute(
                  const MapScreen(
                    openPlanOnStart: true,
                    applyPromoDiscount: true,
                  ),
                ),
              );
            },
          )
        else
          _circleAction(Icons.star_rounded, 'Rewards', [
            _goldLight,
            _gold,
          ], () {}),
      ],
    );
  }

  Widget _circleAction(
    IconData icon,
    String label,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  gradient[0].withValues(alpha: isDark ? 0.15 : 0.35),
                  gradient[1].withValues(alpha: isDark ? 0.06 : 0.18),
                ],
              ),
              border: Border.all(
                color: gradient[0].withValues(alpha: isDark ? 0.20 : 0.25),
              ),
            ),
            child: Icon(
              icon,
              color: isDark ? gradient[0] : gradient[0].withValues(alpha: 0.85),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Section header ───
  Widget _buildSectionHeader(
    String title,
    String? action,
    VoidCallback? onAction,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_gold, _goldLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withValues(alpha: 0.15)),
              ),
              child: Text(
                action,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Fleet: Full-width stacked cards ───
  Widget _buildFleetStack(double screenW) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicles = [
      {
        'tier': 'VIP',
        'name': 'Suburban',
        'desc': 'Premium luxury SUV',
        'idx': 0,
        'accent': _gold,
        'icon': Icons.airport_shuttle_rounded,
        'scale': 1.35,
      },
      {
        'tier': 'PREMIUM',
        'name': 'Camry',
        'desc': 'Comfortable sedan',
        'idx': 1,
        'accent': _goldLight,
        'icon': Icons.directions_car_filled_rounded,
        'scale': 1.55,
      },
      {
        'tier': 'COMFORT',
        'name': 'Fusion',
        'desc': 'Affordable & reliable',
        'idx': 2,
        'accent': Colors.white,
        'icon': Icons.local_taxi_rounded,
        'scale': 1.55,
      },
    ];

    return Column(
      children: vehicles.map((v) {
        final accent = v['accent'] as Color;
        final idx = v['idx'] as int;
        final carScale = v['scale'] as double;
        return Padding(
          padding: EdgeInsets.only(
            bottom: idx < 2 ? 14 : 0,
            left: 24,
            right: 24,
          ),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              slideFromRightRoute(
                MapScreen(openPlanOnStart: true, preSelectedRideIndex: idx),
              ),
            ),
            child: Container(
              height: 120,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(20, 14, 0, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.08 : 0.06),
                    isDark ? const Color(0xFF0D0E14) : Colors.white,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? accent.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Text info
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            v['tier'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          v['name'] as String,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v['desc'] as String,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Car image — large with overflow, decoded at scaled resolution
                  SizedBox(
                    width: screenW * 0.38,
                    child: Transform.scale(
                      scale: carScale,
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/images/${(v['name'] as String).toLowerCase()}.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        cacheWidth:
                            (screenW *
                                    0.38 *
                                    carScale *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        errorBuilder: (ctx, err, st) => Icon(
                          v['icon'] as IconData,
                          color: accent,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Quick access grid (Home, Work, places) ───
  Widget _buildQuickAccessGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickAccessTile(
                Icons.home_rounded,
                'Home',
                _homeFavorite?.address ?? 'Add',
                _gold,
                _openOrSaveHomeShortcut,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAccessTile(
                Icons.work_rounded,
                'Work',
                _workFavorite?.address ?? 'Add',
                _goldLight,
                _openOrSaveWorkShortcut,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickAccessTile(
                Icons.location_on_rounded,
                'Enterprise',
                '2930 Pelham Pkwy',
                _gold,
                () => _openMapWithDropoff('2930 Pelham Pkwy, Pelham'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAccessTile(
                Icons.location_on_rounded,
                '159 Greenwich',
                'Greenwich Dr, Pelham',
                Colors.white,
                () => _openMapWithDropoff('159 Greenwich Dr, Pelham'),
              ),
            ),
          ],
        ),
        // Frequent destinations below
        if (_topDestinations.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._topDestinations.take(2).map((d) {
            final shortName = d.address.split(',').first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _openMapWithDropoff(d.address),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          color: _gold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortName,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${d.count} trips',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _quickAccessTile(
    IconData icon,
    String title,
    String subtitle,
    Color accent,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? accent.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? accent.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.40),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recent trips timeline ───
  Widget _buildRecentTimeline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trips = _recentTrips.take(4).toList();
    return Column(
      children: trips.asMap().entries.map((entry) {
        final i = entry.key;
        final trip = entry.value;
        final shortDest = trip.dropoff.split(',').first;
        final isLast = i == trips.length - 1;

        return GestureDetector(
          onTap: () => _openTripReceipt(trip),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dot + line
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_gold, _goldLight],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Trip card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shortDest,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1C1C1E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trip.rideName,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            trip.price,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Live map card ───
  Widget _buildLiveMapCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Stack(
          children: [
            if (_currentLatLng == null)
              Container(
                color: isDark
                    ? const Color(0xFF0D0E14)
                    : const Color(0xFFF0F0F0),
                child: Center(
                  child: _locationError != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3),
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _locationError!,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                setState(() => _locationError = null);
                                _fetchCurrentLocation();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(
                          color: _gold,
                          strokeWidth: 2,
                        ),
                ),
              )
            else
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _miniMapController = controller;
                  try {
                    final sysBright =
                        ui.PlatformDispatcher.instance.platformBrightness;
                    final style = sysBright == Brightness.dark
                        ? _darkMapStyle
                        : _lightMapStyle;
                    // ignore: deprecated_member_use
                    controller.setMapStyle(style);
                  } catch (_) {}
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('current'),
                    position: _currentLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
            // Badge
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D0E14).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live location',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dock-style bottom nav with animated gold pill ───
  Widget _buildDockNav(BuildContext context, double bottomPad) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (icon: Icons.explore_rounded, label: 'Ride'),
      (icon: Icons.calendar_today_rounded, label: 'Schedule'),
      (icon: Icons.person_rounded, label: 'Account'),
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(40, 0, 40, bottomPad + 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161820) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (i) {
          final active = i == _dockIndex;
          return GestureDetector(
            onTap: () => _onDockTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: active ? 20 : 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [_gold, _goldLight])
                    : null,
                borderRadius: BorderRadius.circular(22),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      items[i].icon,
                      key: ValueKey('dock_icon_${i}_$active'),
                      color: active
                          ? Colors.black87
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.35)),
                      size: 20,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: active
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              items[i].label,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _onDockTap(int index) async {
    if (index == _dockIndex) {
      // Already selected — execute action directly
      _executeDockAction(index);
      return;
    }
    setState(() => _dockIndex = index);
    // Small delay for visual feedback before navigation
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _executeDockAction(index);
  }

  void _executeDockAction(int index) async {
    switch (index) {
      case 0:
        await Navigator.of(
          context,
        ).push(slideUpFadeRoute(const MapScreen(openPlanOnStart: true)));
        if (mounted) setState(() => _dockIndex = 0);
        break;
      case 1:
        await _openScheduleSheet();
        // Reset back to Ride after schedule closes
        if (mounted) setState(() => _dockIndex = 0);
        break;
      case 2:
        await Navigator.of(
          context,
        ).push(slideFromRightRoute(const AccountScreen()));
        _loadSavedData();
        if (mounted) setState(() => _dockIndex = 0);
        break;
    }
  }

  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';

  static const _lightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}
]
''';

  void _openScheduleFlow() => _showScheduleSheet();

  Future<void> _openScheduleSheet() => _showScheduleSheet();

  Future<void> _showScheduleSheet() async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ScheduleBottomSheet(isDark: AppColors.of(context).isDark),
    );
    if (result == null || !mounted) return;

    final formattedDate = '${result.month}/${result.day}/${result.year}';
    final formattedTime = TimeOfDay.fromDateTime(result).format(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _gold,
        content: Text(
          'Ride scheduled for $formattedDate at $formattedTime',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).push(
      slideUpFadeRoute(
        MapScreen(openPlanOnStart: true, scheduledDateTime: result),
      ),
    );
  }

  void _openMapWithDropoff(String query) {
    LocalDataService.incrementDestinationUsage(query);
    Navigator.of(context).push(
      slideFromRightRoute(
        MapScreen(openPlanOnStart: true, initialDropoffQuery: query),
      ),
    );
  }

  FavoritePlace? get _homeFavorite {
    for (final favorite in _favorites) {
      if (favorite.label.toLowerCase().trim() == 'home') {
        return favorite;
      }
    }
    return null;
  }

  FavoritePlace? get _workFavorite {
    for (final favorite in _favorites) {
      if (favorite.label.toLowerCase().trim() == 'work') {
        return favorite;
      }
    }
    return null;
  }

  Future<void> _openOrSaveHomeShortcut() async {
    final existingHome = _homeFavorite;
    if (existingHome != null && existingHome.address.trim().isNotEmpty) {
      _openMapWithDropoff(existingHome.address);
      return;
    }

    final address = await _showAddressAutocomplete(
      title: 'Set Home address',
      hint: 'Search your home address',
    );

    if (address == null || address.isEmpty) return;
    await LocalDataService.saveFavorite(
      FavoritePlace(label: 'Home', address: address),
    );
    await _loadSavedData();
  }

  Future<void> _openOrSaveWorkShortcut() async {
    final existingWork = _workFavorite;
    if (existingWork != null && existingWork.address.trim().isNotEmpty) {
      _openMapWithDropoff(existingWork.address);
      return;
    }

    final address = await _showAddressAutocomplete(
      title: 'Set Work address',
      hint: 'Search your work address',
    );

    if (address == null || address.isEmpty) return;
    await LocalDataService.saveFavorite(
      FavoritePlace(label: 'Work', address: address),
    );
    await _loadSavedData();
  }

  /// Full-screen autocomplete address picker using PlacesService.
  Future<String?> _showAddressAutocomplete({
    required String title,
    required String hint,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressAutocompleteSheet(
        title: title,
        hint: hint,
        currentLatLng: _currentLatLng,
      ),
    );
  }

  Future<void> _openRiderPicker() async {
    final c = AppColors.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      enableDrag: true,
      useSafeArea: true,
      builder: (context) {
        final riders = ['You', 'Family', 'Guest'];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose rider',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...riders.map((rider) {
                  final isSelected = rider == _selectedRider;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(rider, style: TextStyle(color: c.textPrimary)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: _gold)
                        : Icon(
                            Icons.radio_button_unchecked,
                            color: c.textTertiary,
                          ),
                    onTap: () => Navigator.of(context).pop(rider),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedRider = selected;
    });
  }

  void _openTripReceipt(TripHistoryItem trip) {
    Navigator.of(
      context,
    ).push(sharedAxisVerticalRoute(TripReceiptScreen(trip: trip)));
  }

  Future<void> _openNotificationsSheet() async {
    final c = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      enableDrag: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: c.isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _notifications.length > 10
                          ? 10
                          : _notifications.length,
                      itemBuilder: (ctx, i) {
                        final item = _notifications[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.type == 'ride'
                                  ? Icons.directions_car_filled_rounded
                                  : item.type == 'promo'
                                  ? Icons.local_offer_rounded
                                  : Icons.notifications_rounded,
                              color: _gold,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.message,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    await LocalDataService.markNotificationsAsRead();
    await _loadSavedData();
  }
}

// ─────────────────────────────────────────────
// Animated glow border painter for Where-to card
// ─────────────────────────────────────────────
class _GlowBorderPainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color goldLight;
  final bool isDark;

  _GlowBorderPainter({
    required this.progress,
    required this.gold,
    required this.goldLight,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    // Base subtle border
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = isDark
          ? gold.withValues(alpha: 0.15)
          : gold.withValues(alpha: 0.25);
    canvas.drawRRect(rrect, basePaint);

    // Traveling glow — sweep gradient rotated by progress
    final center = Offset(
      size.width / 2,
      size.height / 2,
    ); // ignore: unused_local_variable
    final sweepAngle = progress * 2 * 3.14159265;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * 3.14159265,
        colors: [
          gold.withValues(alpha: 0.0),
          gold.withValues(alpha: 0.0),
          goldLight.withValues(alpha: isDark ? 0.8 : 0.9),
          gold.withValues(alpha: isDark ? 0.6 : 0.7),
          gold.withValues(alpha: 0.0),
          gold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.45, 0.55, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, glowPaint);

    // Outer soft glow shadow behind the bright spot
    final glowShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * 3.14159265,
        colors: [
          gold.withValues(alpha: 0.0),
          gold.withValues(alpha: 0.0),
          goldLight.withValues(alpha: isDark ? 0.3 : 0.25),
          gold.withValues(alpha: 0.0),
          gold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, glowShadow);
  }

  @override
  bool shouldRepaint(_GlowBorderPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────
// Schedule bottom sheet with calendar → clock
// ─────────────────────────────────────────────
class _ScheduleBottomSheet extends StatefulWidget {
  final bool isDark;
  const _ScheduleBottomSheet({required this.isDark});

  @override
  State<_ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<_ScheduleBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF5D990);

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeOut;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideOut;
  late final Animation<Offset> _slideIn;

  bool _showingClock = false;
  DateTime _selectedDate = DateTime.now();
  int _selectedHour = TimeOfDay.now().hour;
  int _selectedMinute = (TimeOfDay.now().minute ~/ 5) * 5; // rounded to 5

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.15, 0.0))
        .animate(
          CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
          ),
        );
    _slideIn = Tween<Offset>(begin: const Offset(0.15, 0.0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _goToClock() {
    setState(() => _showingClock = true);
    _animCtrl.forward(from: 0);
  }

  void _goBackToCalendar() {
    setState(() => _showingClock = false);
    _animCtrl.reverse(from: 1);
  }

  void _confirm() {
    final scheduled = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );
    Navigator.of(context).pop(scheduled);
  }

  Color get _bg => widget.isDark ? const Color(0xFF14161E) : Colors.white;
  Color get _surface =>
      widget.isDark ? const Color(0xFF1A1D24) : const Color(0xFFF5F6FA);
  Color get _textPrimary =>
      widget.isDark ? Colors.white : const Color(0xFF1A1D24);
  Color get _textSecondary =>
      widget.isDark ? Colors.white54 : const Color(0xFF6B7280);
  Color get _border => widget.isDark ? Colors.white10 : const Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(
                children: [
                  if (_showingClock)
                    GestureDetector(
                      onTap: _goBackToCalendar,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: _gold,
                          size: 20,
                        ),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _showingClock ? 'Select Time' : 'Schedule a Ride',
                      key: ValueKey(_showingClock),
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _showingClock
                          ? Icons.access_time_filled_rounded
                          : Icons.calendar_month_rounded,
                      key: ValueKey(_showingClock),
                      color: _gold,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _showingClock
                        ? 'Pick your preferred time'
                        : 'Choose a date for your ride',
                    key: ValueKey(_showingClock),
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Content area with transition
              AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) {
                  return SizedBox(
                    height: 320,
                    child: Stack(
                      children: [
                        // Calendar (slides out left, fades out)
                        if (!_showingClock || _animCtrl.isAnimating)
                          SlideTransition(
                            position: _slideOut,
                            child: FadeTransition(
                              opacity: _fadeOut,
                              child: _buildCalendar(),
                            ),
                          ),
                        // Clock (slides in from right, fades in)
                        if (_showingClock)
                          SlideTransition(
                            position: _slideIn,
                            child: FadeTransition(
                              opacity: _fadeIn,
                              child: _buildTimePicker(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Action button
              GestureDetector(
                onTap: _showingClock ? _confirm : _goToClock,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gold, _goldLight]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Row(
                        key: ValueKey(_showingClock),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showingClock
                                ? Icons.check_rounded
                                : Icons.access_time_rounded,
                            color: Colors.black87,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showingClock ? 'Confirm & Book' : 'Select Time',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
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

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final lastDay = firstDay.add(const Duration(days: 30));

    return Theme(
      data: (widget.isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
        colorScheme: widget.isDark
            ? ColorScheme.dark(
                primary: _gold,
                onPrimary: Colors.black,
                surface: _bg,
                onSurface: Colors.white,
              )
            : ColorScheme.light(
                primary: _gold,
                onPrimary: Colors.white,
                surface: _bg,
                onSurface: const Color(0xFF1A1D24),
              ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: _bg,
          headerBackgroundColor: _bg,
          headerForegroundColor: _textPrimary,
          dayForegroundColor: WidgetStatePropertyAll(_textPrimary),
          todayForegroundColor: const WidgetStatePropertyAll(_gold),
          todayBorder: const BorderSide(color: _gold, width: 1),
          yearForegroundColor: WidgetStatePropertyAll(_textPrimary),
          weekdayStyle: TextStyle(
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
          dayStyle: TextStyle(color: _textPrimary),
        ),
      ),
      child: CalendarDatePicker(
        initialDate: _selectedDate,
        firstDate: firstDay,
        lastDate: lastDay,
        onDateChanged: (date) => setState(() => _selectedDate = date),
      ),
    );
  }

  Widget _buildTimePicker() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          // AM/PM indicator
          Text(
            _selectedHour < 12 ? 'AM' : 'PM',
            style: TextStyle(
              color: _gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeDigit(
                value: _selectedHour == 0
                    ? 12
                    : (_selectedHour > 12 ? _selectedHour - 12 : _selectedHour),
                label: 'Hour',
                onUp: () =>
                    setState(() => _selectedHour = (_selectedHour + 1) % 24),
                onDown: () => setState(
                  () => _selectedHour = (_selectedHour - 1 + 24) % 24,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              _timeDigit(
                value: _selectedMinute,
                label: 'Min',
                padZero: true,
                onUp: () => setState(
                  () => _selectedMinute = (_selectedMinute + 5) % 60,
                ),
                onDown: () => setState(
                  () => _selectedMinute = (_selectedMinute - 5 + 60) % 60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // AM / PM toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _amPmChip('AM', _selectedHour < 12, () {
                if (_selectedHour >= 12) setState(() => _selectedHour -= 12);
              }),
              const SizedBox(width: 12),
              _amPmChip('PM', _selectedHour >= 12, () {
                if (_selectedHour < 12) setState(() => _selectedHour += 12);
              }),
            ],
          ),
          const SizedBox(height: 20),
          // Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.schedule_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatTime(),
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeDigit({
    required int value,
    required String label,
    bool padZero = false,
    required VoidCallback onUp,
    required VoidCallback onDown,
  }) {
    final display = padZero
        ? value.toString().padLeft(2, '0')
        : value.toString();
    return Column(
      children: [
        GestureDetector(
          onTap: onUp,
          child: Container(
            width: 70,
            height: 36,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: _gold,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            display,
            key: ValueKey(value),
            style: TextStyle(
              color: _textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onDown,
          child: Container(
            width: 70,
            height: 36,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _gold,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amPmChip(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.15) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _gold : _border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? _gold : _textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _formatTime() {
    final h = _selectedHour == 0
        ? 12
        : (_selectedHour > 12 ? _selectedHour - 12 : _selectedHour);
    final m = _selectedMinute.toString().padLeft(2, '0');
    final ampm = _selectedHour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ─── Address Autocomplete Bottom Sheet ────────────────────────────────

class _AddressAutocompleteSheet extends StatefulWidget {
  final String title;
  final String hint;
  final LatLng? currentLatLng;

  const _AddressAutocompleteSheet({
    required this.title,
    required this.hint,
    this.currentLatLng,
  });

  @override
  State<_AddressAutocompleteSheet> createState() =>
      _AddressAutocompleteSheetState();
}

class _AddressAutocompleteSheetState extends State<_AddressAutocompleteSheet> {
  final _controller = TextEditingController();
  final _places = PlacesService(ApiKeys.webServices);
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _places.autocomplete(
        query,
        latitude: widget.currentLatLng?.latitude,
        longitude: widget.currentLatLng?.longitude,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.iconMuted,
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          const SizedBox(height: 14),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: c.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: c.textTertiary, fontSize: 15),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.textTertiary,
                    size: 22,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() {
                              _suggestions = [];
                              _loading = false;
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: c.textTertiary,
                            size: 20,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Loading indicator
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: const Color(0xFFD4A843),
                ),
              ),
            ),
          // Suggestions list
          Expanded(
            child: _suggestions.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            color: c.textTertiary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _controller.text.isEmpty
                                ? 'Type to search for an address'
                                : 'No results found',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    cacheExtent: 300,
                    padding: EdgeInsets.fromLTRB(12, 4, 12, bottomInset + 20),
                    itemCount: _suggestions.length,
                    separatorBuilder: (context2, idx) =>
                        Divider(color: c.divider, height: 1, indent: 52),
                    itemBuilder: (context, index) {
                      final s = _suggestions[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: c.textSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          s.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: s.distanceMiles != null
                            ? Text(
                                '${s.distanceMiles!.toStringAsFixed(1)} mi away',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () => Navigator.of(context).pop(s.description),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
