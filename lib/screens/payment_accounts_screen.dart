import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/local_data_service.dart';
import 'credit_card_screen.dart';

/// Screen where users can link / manage their payment accounts
/// (Google Pay, PayPal) and manage saved cards.
class PaymentAccountsScreen extends StatefulWidget {
  const PaymentAccountsScreen({super.key});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen> {
  static const _gold = Color(0xFFD4A843);

  // Linked state – persisted via LocalDataService / SharedPreferences.
  bool _googlePayLinked = false;
  bool _paypalLinked = false;
  String? _savedCardLast4;
  String? _savedCardBrand;

  @override
  void initState() {
    super.initState();
    _loadLinkedState();
  }

  Future<void> _loadLinkedState() async {
    final linked = await LocalDataService.getLinkedPaymentMethods();
    final cardLast4 = await LocalDataService.getCreditCardLast4();
    final cardBrand = await LocalDataService.getCreditCardBrand();
    if (!mounted) return;
    setState(() {
      _googlePayLinked = linked.contains('google_pay');
      _paypalLinked = linked.contains('paypal');
      if (linked.contains('credit_card') && cardLast4 != null) {
        _savedCardLast4 = cardLast4;
        _savedCardBrand = cardBrand;
      }
    });
  }

  // ── External app launchers ──

  Future<void> _linkGooglePay() async {
    // Open the Google Pay / Google Wallet app on the device
    await _launchGooglePayWallet();
    if (!mounted) return;
    _askLinkedConfirmation('Google Pay', () async {
      await LocalDataService.linkPaymentMethod('google_pay');
      setState(() => _googlePayLinked = true);
      _showSnack('Google Pay linked successfully');
    });
  }

  /// Opens the Google Pay / Google Wallet app on the device.
  Future<void> _launchGooglePayWallet() async {
    const walletIntentUri =
        'intent://pay.google.com/#Intent;scheme=https;package=com.google.android.apps.walletnfcrel;end';
    const gpayAppUri = 'https://pay.google.com/gp/w/home';
    const playStoreUri =
        'https://play.google.com/store/apps/details?id=com.google.android.apps.walletnfcrel';

    try {
      final launched = await launchUrl(
        Uri.parse(walletIntentUri),
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    try {
      final launched = await launchUrl(
        Uri.parse(gpayAppUri),
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    try {
      await launchUrl(
        Uri.parse(playStoreUri),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Google Pay is not available on this device.');
    }
  }

  Future<void> _linkPayPal() async {
    await _launchExternal('paypal://home', 'https://www.paypal.com/signin');
    if (!mounted) return;
    _askLinkedConfirmation('PayPal', () async {
      await LocalDataService.linkPaymentMethod('paypal');
      setState(() => _paypalLinked = true);
      _showSnack('PayPal linked successfully');
    });
  }

  Future<void> _linkCreditCard() async {
    final result = await Navigator.of(context).push<String>(
      slideFromRightRoute(const CreditCardScreen()),
    );
    if (!mounted || result == null || result.isEmpty) return;
    // result = "brand:last4" e.g. "visa:4242"
    String brand = 'card';
    String last4 = result;
    if (result.contains(':')) {
      final parts = result.split(':');
      brand = parts[0];
      last4 = parts[1];
    }
    await LocalDataService.linkPaymentMethod('credit_card');
    await LocalDataService.saveCreditCardLast4(last4);
    await LocalDataService.saveCreditCardBrand(brand);
    setState(() {
      _savedCardLast4 = last4;
      _savedCardBrand = brand;
    });
    _showSnack('${_capitalizedBrand(brand)} •••• $last4 added');
  }

  String _capitalizedBrand(String? brand) {
    switch (brand) {
      case 'visa': return 'Visa';
      case 'mastercard': return 'Mastercard';
      case 'amex': return 'Amex';
      case 'discover': return 'Discover';
      case 'diners': return 'Diners Club';
      case 'jcb': return 'JCB';
      default: return 'Card';
    }
  }

  void _askLinkedConfirmation(String name, VoidCallback onConfirm) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Did you complete setup?', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('Confirm that you linked your $name account.', style: TextStyle(color: c.textSecondary, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not yet', style: TextStyle(color: c.textTertiary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text("Yes, it's linked", style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(String appUri, String webUri) async {
    try {
      final launched = await launchUrl(
        Uri.parse(appUri),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(Uri.parse(webUri), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(webUri), mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFD4A843),
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──

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
              // ── Back ──
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Payment accounts',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: c.textPrimary, height: 1.2, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Link your accounts so you can pay faster.',
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Google Pay ──
              _accountTile(
                c: c,
                logoWidget: _googlePayLogo(),
                label: 'Google Pay',
                linked: _googlePayLinked,
                onTap: _linkGooglePay,
              ),
              Divider(color: c.divider, height: 1),

              // ── PayPal ──
              _accountTile(
                c: c,
                logoWidget: _paypalLogo(),
                label: 'PayPal',
                linked: _paypalLinked,
                onTap: _linkPayPal,
              ),
              Divider(color: c.divider, height: 1),

              // ── Credit / Debit Card ──
              _accountTile(
                c: c,
                logoWidget: _cardBrandLogo(_savedCardBrand),
                label: _savedCardLast4 != null
                    ? '${_capitalizedBrand(_savedCardBrand)} •••• $_savedCardLast4'
                    : 'Credit or debit card',
                linked: _savedCardLast4 != null,
                onTap: _linkCreditCard,
              ),

              const Spacer(),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Text(
                  'Your payment information is securely encrypted and stored. '
                  'Cruise never sees your card details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: c.textTertiary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Brand logos ──

  Widget _googlePayLogo() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Image.asset('assets/images/google_g.png', fit: BoxFit.contain),
      ),
    );
  }

  Widget _paypalLogo() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset('assets/images/paypal_logo.png', fit: BoxFit.contain),
      ),
    );
  }

  Widget _cardBrandLogo(String? brand) {
    final Map<String, ({String letter, Color color, bool italic})> brands = {
      'visa': (letter: 'V', color: const Color(0xFF1A1F71), italic: true),
      'mastercard': (letter: 'M', color: const Color(0xFFEB001B), italic: false),
      'amex': (letter: 'A', color: const Color(0xFF006FCF), italic: false),
      'discover': (letter: 'D', color: const Color(0xFFFF6000), italic: false),
      'diners': (letter: 'D', color: const Color(0xFF0079BE), italic: false),
      'jcb': (letter: 'J', color: const Color(0xFF0B7CBE), italic: false),
    };
    final info = brands[brand];
    if (info == null) {
      return Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF6B7280).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.credit_card_rounded, color: Color(0xFF6B7280), size: 22),
      );
    }
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Center(
        child: Text(
          info.letter,
          style: TextStyle(
            color: info.color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: info.italic ? FontStyle.italic : FontStyle.normal,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  Widget _accountTile({
    required AppColors c,
    required Widget logoWidget,
    required String label,
    required bool linked,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            logoWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary,
                ),
              ),
            ),
            if (linked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A843).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Added',
                  style: TextStyle(color: Color(0xFFD4A843), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
