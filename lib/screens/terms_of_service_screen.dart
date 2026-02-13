import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_typography.dart';

/// Terms of Service screen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bark! Terms of Service',
              style: AppTypography.h1().copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: January 2026',
              style: AppTypography.bodySmall().copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              'Welcome to Bark!',
              'These Terms of Service ("Terms") govern your use of Bark! ("the App"), a social platform for dog owners to connect, schedule playdates, and build a community around their pets.',
            ),
            
            _buildSection(
              '1. Acceptance of Terms',
              'By downloading, installing, or using the App, you agree to be bound by these Terms. If you do not agree to these Terms, please do not use the App.',
            ),
            
            _buildSection(
              '2. Eligibility',
              'You must be at least 18 years old to use the App. By using the App, you represent and warrant that you are at least 18 years of age.',
            ),
            
            _buildSection(
              '3. Account Registration',
              'To use certain features of the App, you must create an account. You agree to:\n\n• Provide accurate, current, and complete information\n• Maintain the security of your password\n• Promptly update any information that changes\n• Accept responsibility for all activities under your account',
            ),
            
            _buildSection(
              '4. User Conduct',
              'You agree not to:\n\n• Use the App for any unlawful purpose\n• Harass, abuse, or harm other users\n• Post false or misleading information\n• Impersonate any person or entity\n• Upload harmful content or malware\n• Interfere with the App\'s operation\n• Collect personal data from other users without consent',
            ),
            
            _buildSection(
              '5. Dog & Pet Safety',
              'When arranging playdates through the App:\n\n• You are solely responsible for your pet\'s behavior\n• Ensure your pet is properly vaccinated and healthy\n• Meet in safe, appropriate locations\n• Supervise your pet at all times during interactions\n• We are not liable for any incidents during playdates',
            ),
            
            _buildSection(
              '6. Content & Intellectual Property',
              'You retain ownership of content you post. By posting, you grant us a license to use, display, and distribute your content within the App. You may not post content that infringes on others\' intellectual property rights.',
            ),
            
            _buildSection(
              '7. Privacy',
              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.',
            ),
            
            _buildSection(
              '8. Termination',
              'We may suspend or terminate your account at any time for violations of these Terms or for any other reason at our discretion.',
            ),
            
            _buildSection(
              '9. Disclaimers',
              'THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE CONTINUOUS, UNINTERRUPTED ACCESS TO THE APP.',
            ),
            
            _buildSection(
              '10. Limitation of Liability',
              'To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.',
            ),
            
            _buildSection(
              '11. Changes to Terms',
              'We may update these Terms from time to time. We will notify you of significant changes through the App or via email.',
            ),
            
            _buildSection(
              '12. Contact Us',
              'If you have questions about these Terms, please contact us at:\n\nsupport@barkdate.app',
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.h3().copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.bodyMedium().copyWith(
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
