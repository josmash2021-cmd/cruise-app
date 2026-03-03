import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/local_data_service.dart';

class CreditCardScreen extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? email;

  const CreditCardScreen({
    super.key,
    this.firstName,
    this.lastName,
    this.email,
  });

  @override
  State<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen> {
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF5D990);

  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_cardNumberCtrl, _expiryCtrl, _cvvCtrl, _nameCtrl, _zipCtrl]) {
      ctrl.addListener(_checkFields);
    }
  }

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  void _checkFields() {
    final ok = _cardNumberCtrl.text.replaceAll(' ', '').length >= 15 &&
        _expiryCtrl.text.length >= 5 &&
        _cvvCtrl.text.length >= 3 &&
        _nameCtrl.text.trim().isNotEmpty &&
        _zipCtrl.text.trim().isNotEmpty;
    if (ok != _canContinue) setState(() => _canContinue = ok);
  }

  void _submit() {
    if (!_canContinue) return;

    final digits = _cardNumberCtrl.text.replaceAll(' ', '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    final brand = LocalDataService.detectCardBrand(digits);

    // Return brand:last4 so caller can persist both
    Navigator.of(context).pop('$brand:$last4');
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
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ──
              Text(
                'Add your card',
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
                'Enter your credit or debit card details.',
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Card fields ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Card number
                      _buildField(
                        c,
                        controller: _cardNumberCtrl,
                        hint: 'Card number',
                        icon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _CardNumberFormatter(),
                          LengthLimitingTextInputFormatter(19),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Expiry + CVV row
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              c,
                              controller: _expiryCtrl,
                              hint: 'MM/YY',
                              icon: Icons.calendar_today_rounded,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ExpiryFormatter(),
                                LengthLimitingTextInputFormatter(5),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildField(
                              c,
                              controller: _cvvCtrl,
                              hint: 'CVV',
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.number,
                              obscure: true,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name on card
                      _buildField(
                        c,
                        controller: _nameCtrl,
                        hint: 'Name on card',
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.name,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Zip code
                      _buildField(
                        c,
                        controller: _zipCtrl,
                        hint: 'ZIP / Postal code',
                        icon: Icons.location_on_outlined,
                        keyboardType: TextInputType.number,
                        formatters: [
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Security note
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 16, color: c.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your card info is encrypted and stored securely.',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Add Card button ──
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      gradient: _canContinue
                          ? const LinearGradient(colors: [_gold, _goldLight])
                          : null,
                      color: _canContinue ? null : c.surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: _canContinue
                            ? const Color(0xFF1A1400)
                            : c.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _canContinue ? _submit : null,
                      child: const Text(
                        'Add Card',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildField(
    AppColors c, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        obscureText: obscure,
        textCapitalization: capitalization,
        style: TextStyle(color: c.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: c.textTertiary, fontSize: 16),
          prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 0),
        ),
      ),
    );
  }
}

/// Formats card number as: 1234 5678 9012 3456
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats expiry as: MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
