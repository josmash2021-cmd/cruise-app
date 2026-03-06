import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Document management screen – driver's license, insurance, registration.
class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  static const _gold = Color(0xFFE8C547);
  static const _card = Color(0xFF1C1C1E);
  static const _surface = Color(0xFF141414);

  final _documents = [
    {
      'title': "Driver's License",
      'icon': Icons.badge_rounded,
      'status': 'approved',
      'expiry': 'Mar 15, 2026',
      'number': 'DL-****-5678',
      'uploaded': 'Jan 10, 2024',
    },
    {
      'title': 'Vehicle Insurance',
      'icon': Icons.security_rounded,
      'status': 'approved',
      'expiry': 'Jun 30, 2025',
      'number': 'INS-****-9012',
      'uploaded': 'Jan 10, 2024',
    },
    {
      'title': 'Vehicle Registration',
      'icon': Icons.description_rounded,
      'status': 'approved',
      'expiry': 'Dec 31, 2025',
      'number': 'REG-****-3456',
      'uploaded': 'Jan 10, 2024',
    },
    {
      'title': 'Background Check',
      'icon': Icons.verified_user_rounded,
      'status': 'approved',
      'expiry': 'N/A',
      'number': 'BGC-****-7890',
      'uploaded': 'Jan 5, 2024',
    },
    {
      'title': 'Profile Photo',
      'icon': Icons.camera_alt_rounded,
      'status': 'approved',
      'expiry': 'N/A',
      'number': '',
      'uploaded': 'Jan 5, 2024',
    },
    {
      'title': 'Vehicle Photos',
      'icon': Icons.photo_library_rounded,
      'status': 'pending',
      'expiry': 'N/A',
      'number': '',
      'uploaded': 'Not uploaded',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final approvedCount = _documents.where((d) => d['status'] == 'approved').length;
    final total = _documents.length;
    final progress = approvedCount / total;

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
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: const Text('Documents',
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
                  // ── Progress card ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_gold.withValues(alpha: 0.15), Colors.transparent],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _gold.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 56, height: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 56, height: 56,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                                      valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                                      strokeWidth: 4,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(color: _gold,
                                        fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Document Status',
                                      style: TextStyle(color: Colors.white,
                                          fontSize: 17, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$approvedCount of $total documents approved',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Document list ──
                  ..._documents.map((doc) => _documentCard(doc)),
                  const SizedBox(height: 24),

                  // ── Upload new ──
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _showUploadSheet();
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 20),
                      label: const Text('Upload New Document',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: BorderSide(color: _gold.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    final status = doc['status'] as String;
    final isApproved = status == 'approved';
    final isPending = status == 'pending';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (isApproved) {
      statusColor = const Color(0xFFE8C547);
      statusText = 'Approved';
      statusIcon = Icons.check_circle_rounded;
    } else if (isPending) {
      statusColor = const Color(0xFFF5D990);
      statusText = 'Pending';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = Colors.white.withValues(alpha: 0.5);
      statusText = 'Rejected';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDocDetails(doc),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(doc['icon'] as IconData, color: _gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title'] as String,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if ((doc['expiry'] as String) != 'N/A')
                        Text('Expires: ${doc['expiry']}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12))
                      else
                        Text('Uploaded: ${doc['uploaded']}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(color: statusColor,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDocDetails(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(doc['icon'] as IconData, color: _gold, size: 30),
              ),
              const SizedBox(height: 16),
              Text(doc['title'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              if ((doc['number'] as String).isNotEmpty)
                _detailRow('Document #', doc['number'] as String),
              _detailRow('Expiry', doc['expiry'] as String),
              _detailRow('Uploaded', doc['uploaded'] as String),
              _detailRow('Status', (doc['status'] as String).toUpperCase()),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showUploadSheet();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Update',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: BorderSide(color: _gold.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Close',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              const Text('Upload Document',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              _uploadOption(ctx, Icons.camera_alt_rounded, 'Take Photo',
                  'Use your camera'),
              const SizedBox(height: 12),
              _uploadOption(ctx, Icons.photo_library_rounded, 'Choose from Gallery',
                  'Select from photos'),
              const SizedBox(height: 12),
              _uploadOption(ctx, Icons.insert_drive_file_rounded, 'Upload File',
                  'PDF, JPG, PNG'),
              const SizedBox(height: 20),
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

  Widget _uploadOption(BuildContext ctx, IconData icon, String title,
      String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(ctx);
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Document upload coming soon!'),
              backgroundColor: _gold,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _gold, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}
