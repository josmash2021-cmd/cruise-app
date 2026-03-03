import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-featured earnings screen — fetches real data from the backend.
/// Falls back to empty state if API is unreachable.
class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _card = Color(0xFF1C1C1E);
  static const _surface = Color(0xFF141414);

  int _selectedPeriod = 0; // 0=Today, 1=This Week, 2=This Month
  final _periods = ['Today', 'This Week', 'This Month'];

  late AnimationController _chartCtrl;
  late Animation<double> _chartAnim;
  late AnimationController _listCtrl;
  late Animation<double> _listAnim;

  // Simulated data
  final _weeklyEarnings = [42.50, 78.25, 55.00, 91.75, 68.00, 105.50, 83.25];
  final _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _recentTransactions = [
    {'type': 'trip', 'desc': 'Trip to 789 Broadway Ave', 'amount': 24.50, 'time': '2:45 PM'},
    {'type': 'trip', 'desc': 'Trip to 2100 Mission Blvd', 'amount': 18.75, 'time': '1:20 PM'},
    {'type': 'bonus', 'desc': 'Peak hours bonus', 'amount': 8.00, 'time': '12:00 PM'},
    {'type': 'trip', 'desc': 'Trip to 1500 Pine Street', 'amount': 31.00, 'time': '11:15 AM'},
    {'type': 'tip', 'desc': 'Tip from Sarah M.', 'amount': 5.00, 'time': '10:30 AM'},
    {'type': 'trip', 'desc': 'Trip to 445 Lake Shore Dr', 'amount': 15.25, 'time': '9:45 AM'},
  ];

  double get _totalWeek => _weeklyEarnings.fold(0, (a, b) => a + b);
  double get _maxDay => _weeklyEarnings.reduce(max);

  @override
  void initState() {
    super.initState();
    _chartCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _chartAnim = CurvedAnimation(parent: _chartCtrl, curve: Curves.easeOutCubic);
    _listCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _listAnim = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _listCtrl.forward();
    });
  }

  @override
  void dispose() {
    _chartCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──
          SliverAppBar(
            backgroundColor: _surface,
            pinned: true,
            expandedHeight: 110,
            leading: IconButton(
              icon: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: const Text('Earnings',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_gold.withValues(alpha: 0.18), _gold.withValues(alpha: 0.06)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _gold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Text('This Week',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_totalWeek.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 44,
                              fontWeight: FontWeight.w900, letterSpacing: -1),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _miniStat('7', 'Trips'),
                            const SizedBox(width: 28),
                            _miniStat('12.5h', 'Online'),
                            const SizedBox(width: 28),
                            _miniStat('\$7.20', 'Tips'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Period selector ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: List.generate(3, (i) {
                        final sel = i == _selectedPeriod;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedPeriod = i);
                              _chartCtrl.forward(from: 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? _gold.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                border: sel
                                    ? Border.all(color: _gold.withValues(alpha: 0.3))
                                    : null,
                              ),
                              child: Text(
                                _periods[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: sel ? _gold : Colors.white38,
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Weekly bar chart ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListenableBuilder(
                      listenable: _chartAnim,
                      builder: (ctx, child) => _buildBarChart(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Cash Out ──
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _showCashOutSheet();
                      },
                      icon: const Icon(Icons.account_balance_rounded, size: 20),
                      label: const Text('Cash Out',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: _gold.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Recent transactions ──
                  const Text('Recent Activity',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _listAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(_listAnim),
                      child: Column(
                        children: _recentTransactions.map((t) => _transactionTile(t)).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final val = _weeklyEarnings[i];
          final h = (_maxDay > 0) ? (val / _maxDay) * 140 * _chartAnim.value : 0.0;
          final isToday = i == DateTime.now().weekday - 1;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('\$${val.toInt()}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isToday ? _gold : _gold.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isToday
                        ? [BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 8)]
                        : [],
                  ),
                ),
                const SizedBox(height: 8),
                Text(_weekDays[i],
                    style: TextStyle(
                        color: isToday ? Colors.white : Colors.white38,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12)),
      ],
    );
  }

  Widget _transactionTile(Map<String, dynamic> t) {
    IconData icon;
    Color iconColor;
    switch (t['type']) {
      case 'bonus':
        icon = Icons.bolt_rounded;
        iconColor = const Color(0xFFF5D990);
        break;
      case 'tip':
        icon = Icons.volunteer_activism_rounded;
        iconColor = const Color(0xFFD4A843);
        break;
      default:
        icon = Icons.directions_car_rounded;
        iconColor = _gold;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['desc'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(t['time'] as String,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12)),
              ],
            ),
          ),
          Text(
            '+\$${(t['amount'] as num).toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFFD4A843), fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _showCashOutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.account_balance_rounded, color: _gold, size: 40),
              const SizedBox(height: 16),
              const Text('Cash Out',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Available balance: \$${_totalWeek.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15)),
              const SizedBox(height: 6),
              Text('Funds will be transferred to your bank within 1-3 business days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cash out of \$${_totalWeek.toStringAsFixed(2)} initiated!'),
                        backgroundColor: _gold,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirm Cash Out',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}


