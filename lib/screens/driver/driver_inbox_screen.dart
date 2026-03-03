import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Driver Inbox – tabs: All, Messages, Alerts, Updates, Deals
class DriverInboxScreen extends StatefulWidget {
  const DriverInboxScreen({super.key});

  @override
  State<DriverInboxScreen> createState() => _DriverInboxScreenState();
}

class _DriverInboxScreenState extends State<DriverInboxScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _card = Color(0xFF1C1C1E);

  late final TabController _tabCtrl;

  // Simulated inbox items
  final _items = <_InboxItem>[
    _InboxItem(
      type: InboxType.alert,
      title: 'New earning opportunity',
      body: 'Surge pricing is active in your area. Go online to earn more!',
      time: '10 min ago',
      icon: Icons.trending_up_rounded,
      iconColor: Color(0xFF4CAF50),
      unread: true,
    ),
    _InboxItem(
      type: InboxType.message,
      title: 'Support',
      body: 'Your document verification has been approved. You\'re all set!',
      time: '2h ago',
      icon: Icons.support_agent_rounded,
      iconColor: Color(0xFF2196F3),
      unread: true,
    ),
    _InboxItem(
      type: InboxType.update,
      title: 'App update available',
      body: 'Version 2.4.1 includes bug fixes and performance improvements.',
      time: '5h ago',
      icon: Icons.system_update_rounded,
      iconColor: Color(0xFF9C27B0),
      unread: false,
    ),
    _InboxItem(
      type: InboxType.deal,
      title: 'Fuel discount unlocked',
      body: 'Save 5% at participating stations with your Cruise Level rewards.',
      time: 'Yesterday',
      icon: Icons.local_gas_station_rounded,
      iconColor: Color(0xFFFF9800),
      unread: false,
    ),
    _InboxItem(
      type: InboxType.alert,
      title: 'Weekly summary',
      body: 'You completed 23 trips and earned \$487.50 this week. Great job!',
      time: 'Mon',
      icon: Icons.bar_chart_rounded,
      iconColor: Color(0xFFD4A843),
      unread: false,
    ),
    _InboxItem(
      type: InboxType.message,
      title: 'Cruise Team',
      body: 'Welcome to Cruise! Check out driver tips to maximize your earnings.',
      time: 'Last week',
      icon: Icons.campaign_rounded,
      iconColor: Color(0xFF00BCD4),
      unread: false,
    ),
    _InboxItem(
      type: InboxType.update,
      title: 'New feature: Cruise Level',
      body: 'Earn points on every trip and unlock exclusive rewards. Tap to learn more.',
      time: 'Last week',
      icon: Icons.workspace_premium_rounded,
      iconColor: Color(0xFFD4A843),
      unread: false,
    ),
    _InboxItem(
      type: InboxType.deal,
      title: 'Refer a friend',
      body: 'Invite friends to drive and earn \$100 for each referral who completes 25 trips.',
      time: '2 weeks ago',
      icon: Icons.card_giftcard_rounded,
      iconColor: Color(0xFFE91E63),
      unread: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<_InboxItem> _filtered(int tabIndex) {
    switch (tabIndex) {
      case 1: return _items.where((i) => i.type == InboxType.message).toList();
      case 2: return _items.where((i) => i.type == InboxType.alert).toList();
      case 3: return _items.where((i) => i.type == InboxType.update).toList();
      case 4: return _items.where((i) => i.type == InboxType.deal).toList();
      default: return _items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Inbox',
                      style: TextStyle(color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        for (final i in _items) {
                          i.unread = false;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Mark all read',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab bar ──
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: [
                  _tabChip('All', _items.where((i) => i.unread).length),
                  _tabChip('Messages', _items.where((i) => i.type == InboxType.message && i.unread).length),
                  _tabChip('Alerts', _items.where((i) => i.type == InboxType.alert && i.unread).length),
                  _tabChip('Updates', 0),
                  _tabChip('Deals', 0),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Content ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: List.generate(5, (tabIndex) {
                  final items = _filtered(tabIndex);
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded,
                              color: Colors.white.withValues(alpha: 0.15), size: 56),
                          const SizedBox(height: 12),
                          Text('No messages',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _buildItem(items[i]),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: 18, height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(_InboxItem item) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => item.unread = false);
        _showItemDetail(item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.unread ? Colors.white.withValues(alpha: 0.06) : _card,
          borderRadius: BorderRadius.circular(16),
          border: item.unread
              ? Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.title,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: item.unread ? FontWeight.w800 : FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (item.unread)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.body,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(item.time,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetail(_InboxItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(item.title,
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(item.time,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            const SizedBox(height: 16),
            Text(item.body,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

enum InboxType { message, alert, update, deal }

class _InboxItem {
  final InboxType type;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color iconColor;
  bool unread;

  _InboxItem({
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.unread,
  });
}
