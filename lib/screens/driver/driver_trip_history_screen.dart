import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Trip history screen with filterable past rides list.
class DriverTripHistoryScreen extends StatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  State<DriverTripHistoryScreen> createState() => _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState extends State<DriverTripHistoryScreen> {
  static const _gold = Color(0xFFD4A843);
  static const _card = Color(0xFF1C1C1E);
  static const _surface = Color(0xFF141414);

  int _selectedFilter = 0; // 0=All, 1=Completed, 2=Cancelled
  final _filters = ['All', 'Completed', 'Cancelled'];

  final _trips = [
    {
      'rider': 'Sarah M.',
      'pickup': '1423 Elm Street',
      'dropoff': '789 Broadway Ave',
      'fare': 24.50,
      'distance': 4.2,
      'duration': 12,
      'date': 'Today, 2:45 PM',
      'status': 'completed',
      'rating': 5,
      'tip': 3.00,
    },
    {
      'rider': 'James K.',
      'pickup': '550 Market St',
      'dropoff': '2100 Mission Blvd',
      'fare': 18.75,
      'distance': 3.1,
      'duration': 9,
      'date': 'Today, 1:20 PM',
      'status': 'completed',
      'rating': 4,
      'tip': 0.0,
    },
    {
      'rider': 'Maria L.',
      'pickup': '320 Oak Lane',
      'dropoff': '1500 Pine Street',
      'fare': 0.0,
      'distance': 0.0,
      'duration': 0,
      'date': 'Today, 11:30 AM',
      'status': 'cancelled',
      'rating': 0,
      'tip': 0.0,
    },
    {
      'rider': 'David R.',
      'pickup': '890 Park Ave',
      'dropoff': '445 Lake Shore Dr',
      'fare': 15.25,
      'distance': 2.4,
      'duration': 7,
      'date': 'Yesterday, 5:15 PM',
      'status': 'completed',
      'rating': 5,
      'tip': 5.00,
    },
    {
      'rider': 'Emily W.',
      'pickup': '2200 Sunset Blvd',
      'dropoff': '100 Ocean Ave',
      'fare': 42.00,
      'distance': 8.3,
      'duration': 22,
      'date': 'Yesterday, 3:40 PM',
      'status': 'completed',
      'rating': 5,
      'tip': 8.00,
    },
    {
      'rider': 'Carlos P.',
      'pickup': '100 Main St',
      'dropoff': '500 Harbor Blvd',
      'fare': 28.50,
      'distance': 5.1,
      'duration': 14,
      'date': 'Yesterday, 1:10 PM',
      'status': 'completed',
      'rating': 4,
      'tip': 2.00,
    },
    {
      'rider': 'Lisa T.',
      'pickup': '775 Oak Drive',
      'dropoff': '200 Vine St',
      'fare': 0.0,
      'distance': 0.0,
      'duration': 0,
      'date': 'Dec 15, 9:20 AM',
      'status': 'cancelled',
      'rating': 0,
      'tip': 0.0,
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 0) return _trips;
    final status = _selectedFilter == 1 ? 'completed' : 'cancelled';
    return _trips.where((t) => t['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
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
              title: const Text('Trip History',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
          ),

          // ── Summary ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _summStat('${_trips.where((t) => t['status'] == 'completed').length}', 'Completed', const Color(0xFFD4A843)),
                    _dividerVert(),
                    _summStat('${_trips.where((t) => t['status'] == 'cancelled').length}', 'Cancelled', Colors.white.withValues(alpha: 0.5)),
                    _dividerVert(),
                    _summStat(
                      '\$${_trips.where((t) => t['status'] == 'completed').fold<double>(0, (a, t) => a + (t['fare'] as num).toDouble()).toStringAsFixed(0)}',
                      'Total',
                      _gold,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Filter ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: List.generate(3, (i) {
                    final sel = i == _selectedFilter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFilter = i);
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
                            _filters[i],
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
            ),
          ),

          // ── Trip list ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          children: [
                            Icon(Icons.history_rounded,
                                color: Colors.white.withValues(alpha: 0.1), size: 60),
                            const SizedBox(height: 16),
                            Text('No trips found',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _tripCard(_filtered[i], i),
                      childCount: _filtered.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _tripCard(Map<String, dynamic> trip, int index) {
    final completed = trip['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: completed
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTripDetails(trip),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: (completed ? _gold : Colors.white).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (trip['rider'] as String)[0],
                          style: TextStyle(
                            color: completed ? _gold : Colors.white.withValues(alpha: 0.5),
                            fontSize: 20, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip['rider'] as String,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(trip['date'] as String,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (completed)
                          Text('\$${(trip['fare'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(color: _gold, fontSize: 20,
                                  fontWeight: FontWeight.w900))
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Cancelled',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        if (completed && (trip['tip'] as num) > 0) ...[
                          const SizedBox(height: 3),
                          Text('+\$${(trip['tip'] as num).toStringAsFixed(2)} tip',
                              style: const TextStyle(
                                  color: Color(0xFFD4A843), fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
                if (completed) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _miniInfo(Icons.route_rounded,
                            '${(trip['distance'] as num).toStringAsFixed(1)} mi'),
                        const SizedBox(width: 20),
                        _miniInfo(Icons.schedule_rounded,
                            '${trip['duration']} min'),
                        const Spacer(),
                        Row(
                          children: List.generate(5, (j) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: j < (trip['rating'] as int)
                                ? _gold
                                : Colors.white.withValues(alpha: 0.1),
                          )),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _summStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dividerVert() {
    return Container(
      width: 1, height: 36, color: Colors.white.withValues(alpha: 0.06),
    );
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    final completed = trip['status'] == 'completed';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
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
              Text(completed ? 'Trip Details' : 'Cancelled Trip',
                  style: const TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),

              // Route
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _detailRoute(Icons.circle, 8, const Color(0xFFD4A843),
                        'PICKUP', trip['pickup'] as String),
                    Padding(
                      padding: const EdgeInsets.only(left: 3.5),
                      child: Container(
                          width: 1, height: 20, color: Colors.white12),
                    ),
                    _detailRoute(Icons.location_on_rounded, 14, Colors.white.withValues(alpha: 0.5),
                        'DROPOFF', trip['dropoff'] as String),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (completed) ...[
                Row(
                  children: [
                    _detailStat('Fare', '\$${(trip['fare'] as num).toStringAsFixed(2)}'),
                    _detailStat('Distance', '${(trip['distance'] as num).toStringAsFixed(1)} mi'),
                    _detailStat('Duration', '${trip['duration']} min'),
                    if ((trip['tip'] as num) > 0)
                      _detailStat('Tip', '\$${(trip['tip'] as num).toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRoute(IconData icon, double size, Color color,
      String label, String text) {
    return Row(
      children: [
        SizedBox(width: 8, child: Icon(icon, size: size, color: color)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12)),
        ],
      ),
    );
  }
}
