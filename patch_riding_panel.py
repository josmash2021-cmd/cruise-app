#!/usr/bin/env python3
import sys

FILE = r'c:\Users\josma\cruise-app\lib\screens\map_screen.dart'

NEW_RIDING_PANEL = r"""  Widget _ridingPanel() {
    final isInTrip = _tripStatus == 'in_trip';
    final isArrived = _tripStatus == 'arrived';
    final price = (_rides.isNotEmpty && _selectedRide < _rides.length)
        ? _rides[_selectedRide].price
        : '';
    final rideName = (_rides.isNotEmpty && _selectedRide < _rides.length)
        ? _rides[_selectedRide].name
        : 'CRUISE';

    return Container(
      key: const ValueKey('riding'),
      height: double.infinity,
      decoration: _panelDecoration,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            const SizedBox(height: 12),

            // Route visual row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C853), shape: BoxShape.circle,
                          ),
                        ),
                        Container(width: 2, height: 22, color: const Color(0xFF9E9E9E)),
                        const Icon(Icons.location_on, color: Color(0xFF1565C0), size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickupAddress.isNotEmpty ? _pickupAddress : 'Your location',
                          style: TextStyle(color: _c.textSecondary, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _dropoffAddress.isNotEmpty ? _dropoffAddress : 'Destination',
                          style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Add or\nChange',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _c.isDark ? _gold : const Color(0xFF1565C0),
                        fontSize: 12, fontWeight: FontWeight.w600, height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: _c.border),
            const SizedBox(height: 10),

            // Driver row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _gold.withValues(alpha: 0.2),
                    child: Text(
                      _driverName.isNotEmpty ? _driverName[0].toUpperCase() : '?',
                      style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_driverName, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded, color: _gold, size: 13),
                            Text(' 4.9', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                          ],
                        ),
                        if (_driverCar.isNotEmpty || _driverPlate.isNotEmpty)
                          Text(
                            [if (_driverCar.isNotEmpty) _driverCar, if (_driverPlate.isNotEmpty) _driverPlate].join(' \u2022 '),
                            style: TextStyle(color: _c.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling driver...'), duration: Duration(seconds: 2)));
                    },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _c.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.phone_rounded, size: 18, color: _c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: _c.border),

            // Rate row (in_trip only)
            if (isInTrip) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text("How's your ride going?", style: TextStyle(color: _c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideRatingScreen(driverName: _driverName, rideName: rideName, price: price.isNotEmpty ? price : r'$0.00')));
                      },
                      child: Row(
                        children: [
                          Text('Rate or tip', style: TextStyle(color: _c.isDark ? _gold : const Color(0xFF1565C0), fontSize: 14, fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right_rounded, size: 18, color: _c.isDark ? _gold : const Color(0xFF1565C0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _c.border),
            ],

            const Spacer(),

            // Bottom: price/ETA + cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isInTrip && price.isNotEmpty) ...[
                    Text(price, style: TextStyle(color: _c.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    if (_tripMiles.isNotEmpty || _tripDuration.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          [if (_tripMiles.isNotEmpty) _tripMiles, if (_tripDuration.isNotEmpty) _tripDuration].join(' \u2022 '),
                          style: TextStyle(color: _c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ] else ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArrived ? '$_driverName is at pickup' : 'ETA $_driverEta',
                            style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          if (!isArrived)
                            Text('$_driverName is on the way', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel ride?'),
                          content: const Text('Are you sure? A cancellation fee may apply.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep ride', style: TextStyle(color: _gold))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel', style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      _rideLifecycleTimer?.cancel();
                      _tripPollTimer?.cancel();
                      setState(() { _driverMarker = null; _rideProgress = 0; });
                      Navigator.of(context).maybePop();
                    },
                    child: Text('Cancel', style: TextStyle(color: _c.textSecondary, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

with open(FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

total = len(lines)
print(f'Total lines: {total}')

start_line = None
end_line = None
brace_depth = 0

for i, line in enumerate(lines):
    if '  Widget _ridingPanel() {' in line and start_line is None:
        start_line = i
        brace_depth = 0
    if start_line is not None:
        brace_depth += line.count('{') - line.count('}')
        if brace_depth == 0 and i > start_line:
            end_line = i
            break

if start_line is None or end_line is None:
    print(f'ERROR: start={start_line} end={end_line}')
    sys.exit(1)

print(f'_ridingPanel: lines {start_line+1} to {end_line+1}')

new_lines = lines[:start_line] + [NEW_RIDING_PANEL] + lines[end_line+1:]

with open(FILE, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f'Done. New total lines: {len(new_lines)}')
