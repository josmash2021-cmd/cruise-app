import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
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
                  const SizedBox(width: 12),
                  Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.divider, height: 1),

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(c, 'Last Updated'),
                    _paragraph(c, 'February 27, 2026'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '1. Acceptance of Terms'),
                    _paragraph(c,
                        'By downloading, accessing, or using the Cruise application ("App"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use the App. These Terms constitute a legally binding agreement between you and Cruise Technologies, Inc. ("Cruise", "we", "us", or "our").'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '2. Eligibility'),
                    _paragraph(c,
                        'You must be at least 18 years old to create an account and use Cruise services. By using the App, you represent and warrant that you meet this age requirement and have the legal capacity to enter into these Terms.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '3. Account Registration'),
                    _paragraph(c,
                        'To access certain features of the App, you must register for an account. You agree to:\n\n'
                        '• Provide accurate, current, and complete information during registration.\n'
                        '• Maintain and promptly update your account information.\n'
                        '• Keep your account credentials confidential.\n'
                        '• Accept responsibility for all activities that occur under your account.\n'
                        '• Notify us immediately of any unauthorized use of your account.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '4. Services Description'),
                    _paragraph(c,
                        'Cruise provides a technology platform that connects riders with independent transportation providers ("Drivers"). We are a technology services company and do not provide transportation services. All rides are performed by independent Drivers who are not employees of Cruise.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '5. Ride Booking & Cancellation'),
                    _paragraph(c,
                        'When you request a ride through the App, you agree to:\n\n'
                        '• Be present at your specified pickup location.\n'
                        '• Provide accurate pickup and drop-off information.\n'
                        '• Treat Drivers with respect and courtesy.\n\n'
                        'Cancellation fees may apply if you cancel a ride after a Driver has been assigned to your request. The specific cancellation policy and fees will be displayed in the App.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '6. Payments & Pricing'),
                    _paragraph(c,
                        'By using Cruise, you agree to pay all applicable fares, fees, and charges associated with your rides. Pricing is determined based on factors including distance, time, demand, and vehicle type.\n\n'
                        '• Fares are estimated before you confirm a ride.\n'
                        '• Actual fares may vary from estimates due to route changes, traffic, or other factors.\n'
                        '• Payment will be processed through your selected payment method.\n'
                        '• Tips are optional but appreciated by Drivers.\n'
                        '• Tolls, surcharges, and applicable taxes may be added to your fare.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '7. Payment Methods'),
                    _paragraph(c,
                        'Cruise accepts the following payment methods:\n\n'
                        '• Credit and debit cards (Visa, Mastercard, American Express)\n'
                        '• Google Pay\n'
                        '• PayPal\n'
                        '• Cruise Cash (prepaid balance)\n\n'
                        'You authorize Cruise to charge your selected payment method for all rides and services used.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '8. User Conduct'),
                    _paragraph(c,
                        'While using the App and during rides, you agree not to:\n\n'
                        '• Violate any applicable laws or regulations.\n'
                        '• Harass, threaten, or discriminate against Drivers or other users.\n'
                        '• Damage or deface any vehicle.\n'
                        '• Transport illegal substances or prohibited items.\n'
                        '• Use the App for any fraudulent or unauthorized purpose.\n'
                        '• Attempt to circumvent any security features of the App.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '9. Safety'),
                    _paragraph(c,
                        'Your safety is our priority. Cruise implements various safety features including:\n\n'
                        '• Driver background checks.\n'
                        '• Real-time ride monitoring.\n'
                        '• In-app emergency assistance.\n'
                        '• Trip sharing with trusted contacts.\n'
                        '• GPS tracking of all rides.\n\n'
                        'Please always wear your seatbelt during rides and report any safety concerns through the App.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '10. Privacy'),
                    _paragraph(c,
                        'Your privacy is important to us. Our collection and use of personal information is governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the App, you consent to our collection and use of your data as described in the Privacy Policy.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '11. Intellectual Property'),
                    _paragraph(c,
                        'The Cruise name, logo, and all related marks, images, and content displayed in the App are the exclusive property of Cruise Technologies, Inc. You may not copy, modify, distribute, or create derivative works based on our intellectual property without our express written consent.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '12. Limitation of Liability'),
                    _paragraph(c,
                        'To the maximum extent permitted by law, Cruise shall not be liable for:\n\n'
                        '• Any indirect, incidental, special, or consequential damages.\n'
                        '• Loss of data, revenue, or profits.\n'
                        '• Damages arising from your use of or inability to use the App.\n'
                        '• Actions or omissions of Drivers or third parties.\n\n'
                        'Our total liability shall not exceed the amount paid by you for rides in the 12 months preceding the claim.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '13. Indemnification'),
                    _paragraph(c,
                        'You agree to indemnify and hold harmless Cruise, its affiliates, officers, directors, employees, and agents from any claims, damages, losses, or expenses arising from your use of the App, violation of these Terms, or violation of any rights of a third party.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '14. Termination'),
                    _paragraph(c,
                        'We reserve the right to suspend or terminate your account at any time, with or without cause, including if we believe you have violated these Terms. You may delete your account at any time through the App settings. Upon termination, your right to use the App will immediately cease.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '15. Dispute Resolution'),
                    _paragraph(c,
                        'Any disputes arising from or relating to these Terms or your use of the App shall be resolved through binding arbitration in accordance with the rules of the American Arbitration Association. You agree to waive your right to participate in a class action lawsuit or class-wide arbitration.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '16. Modifications'),
                    _paragraph(c,
                        'Cruise reserves the right to modify these Terms at any time. We will notify you of material changes through the App or via email. Your continued use of the App after such modifications constitutes acceptance of the updated Terms.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '17. Governing Law'),
                    _paragraph(c,
                        'These Terms shall be governed by and construed in accordance with the laws of the State of California, without regard to its conflict of law provisions.'),
                    const SizedBox(height: 20),

                    _sectionTitle(c, '18. Contact Us'),
                    _paragraph(c,
                        'If you have any questions about these Terms, please contact us at:\n\n'
                        'Cruise Technologies, Inc.\n'
                        'Email: legal@cruiseapp.com\n'
                        'Support: support@cruiseapp.com'),
                    const SizedBox(height: 40),

                    // ── Acceptance notice ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'By creating an account or using the Cruise app, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
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
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _paragraph(AppColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: c.textSecondary,
        height: 1.6,
      ),
    );
  }
}
