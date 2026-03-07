import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/local_data_service.dart';
import 'credit_card_screen.dart';
import 'profile_photo_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  const PaymentMethodScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  static const _gold = Color(0xFFE8C547);

  String? _selectedMethod;

  final List<_PaymentOption> _options = const [
    _PaymentOption(
      id: 'paypal',
      label: 'PayPal',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: Colors.white70,
    ),
    _PaymentOption(
      id: 'cruise_cash',
      label: 'Cruise Cash',
      icon: Icons.monetization_on_rounded,
      iconColor: Color(0xFFE8C547),
    ),
    _PaymentOption(
      id: 'google_pay',
      label: 'Google Pay',
      icon: Icons.g_mobiledata_rounded,
      iconColor: Colors.white,
    ),
    _PaymentOption(
      id: 'credit_card',
      label: 'Credit or debit card',
      icon: Icons.credit_card_rounded,
      iconColor: Color(0xFF6B7280),
    ),
  ];

  void _selectMethod(String id) async {
    setState(() => _selectedMethod = id);

    if (id == 'paypal') {
      await _openPayPal();
      return;
    }

    if (id == 'credit_card') {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        slideFromRightRoute(
          CreditCardScreen(
            firstName: widget.firstName,
            lastName: widget.lastName,
            email: widget.email,
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) {
        // Parse brand:last4 format
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
        if (!mounted) return;
        _goToNextScreen(result);
      }
      return;
    }

    if (id == 'google_pay') {
      // TODO: Complete Google Pay setup via Stripe
      _showSetupSnack('Google Pay linked successfully');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _goToNextScreen(id);
      return;
    }

    if (id == 'cruise_cash') {
      _showSetupSnack('Cruise Cash activated');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _goToNextScreen(id);
      return;
    }
  }

  void _goToNextScreen(String method) {
    Navigator.of(context).push(
      slideFromRightRoute(
        ProfilePhotoScreen(
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          phone: widget.phone,
          paymentMethod: method,
        ),
      ),
    );
  }

  void _skipPayment() {
    Navigator.of(context).push(
      slideFromRightRoute(
        ProfilePhotoScreen(
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          phone: widget.phone,
          paymentMethod: 'none',
        ),
      ),
    );
  }

  void _showSetupSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE8C547),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openPayPal() async {
    // Try to open PayPal app first
    final paypalAppUri = Uri.parse('paypal://home');
    final paypalWebUri = Uri.parse('https://www.paypal.com/signin');

    try {
      final launched = await launchUrl(
        paypalAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(paypalWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(paypalWebUri, mode: LaunchMode.externalApplication);
    }

    // After returning from PayPal, mark as set up
    if (!mounted) return;
    _showSetupSnack('PayPal linked successfully');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _goToNextScreen('paypal');
  }

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
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: c.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ──
              Text(
                'How would you like\nto pay?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You'll only be charged after the ride.",
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Payment options ──
              ...List.generate(_options.length, (i) {
                final opt = _options[i];
                final selected = _selectedMethod == opt.id;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _selectMethod(opt.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _gold.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: selected
                              ? Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: opt.iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                opt.icon,
                                color: opt.iconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.chevron,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < _options.length - 1)
                      Divider(color: c.divider, height: 1),
                  ],
                );
              }),

              const Spacer(),

              // ── Footer note ──
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "If there's ever a problem with your payment, we'll retry with other backup payment methods in your account so you can continue using Cruise.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textTertiary,
                    height: 1.5,
                  ),
                ),
              ),

              // ── Set up later ──
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Center(
                  child: GestureDetector(
                    onTap: _skipPayment,
                    child: Text(
                      'Set up later',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                        decoration: TextDecoration.underline,
                        decorationColor: _gold,
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
}

class _PaymentOption {
  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _PaymentOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.iconColor,
  });
}
