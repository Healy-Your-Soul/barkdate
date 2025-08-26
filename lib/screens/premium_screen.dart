import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Go Premium',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.tertiary,
                          Theme.of(context).colorScheme.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.star,
                      size: 50,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upgrade for More',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get the most out of BarkDate with premium features designed for serious dog lovers',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Features list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Features',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.all_inclusive,
                    title: 'Unlimited Playdates',
                    description: 'Schedule as many playdates as you want with no restrictions',
                    gradient: [Colors.blue, Colors.cyan],
                  ),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.tune,
                    title: 'Advanced Search Filters',
                    description: 'Find the perfect playmates with detailed breed, age, and personality filters',
                    gradient: [Colors.purple, Colors.pink],
                  ),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.event_available,
                    title: 'Exclusive Events',
                    description: 'Access to premium dog meetups and special community events',
                    gradient: [Colors.orange, Colors.red],
                  ),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.support_agent,
                    title: 'Priority Support',
                    description: 'Get help when you need it with dedicated premium customer support',
                    gradient: [Colors.green, Colors.teal],
                  ),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.visibility_off,
                    title: 'Ad-Free Experience',
                    description: 'Enjoy BarkDate without any interruptions or advertisements',
                    gradient: [Colors.indigo, Colors.blue],
                  ),
                  
                  _buildFeatureItem(
                    context,
                    icon: Icons.insights,
                    title: 'Profile Insights',
                    description: 'See who viewed your dog\'s profile and get detailed interaction stats',
                    gradient: [Colors.amber, Colors.orange],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Pricing section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$9.99',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        '/month',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cancel anytime',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleUpgrade(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Start Your Premium Journey',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: () => _showFreeTrialDialog(context),
                    child: Text(
                      'Start 7-Day Free Trial',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Testimonials section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Premium Users Say',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTestimonial(
                    context,
                    name: 'Sarah & Buddy',
                    text: 'Premium filters helped us find the perfect playmates. Worth every penny!',
                    rating: 5,
                  ),
                  
                  _buildTestimonial(
                    context,
                    name: 'Mike & Cooper',
                    text: 'The exclusive events are amazing. My dog has made so many new friends!',
                    rating: 5,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Terms and conditions apply. Subscription automatically renews unless canceled.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonial(
    BuildContext context, {
    required String name,
    required String text,
    required int rating,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                rating,
                (index) => Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$text"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text('This would normally handle the payment process. For this demo, we\'ll just show this dialog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Welcome to Premium! 🌟'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showFreeTrialDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('7-Day Free Trial'),
        content: const Text('Start your free trial and experience all premium features. No commitment required!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Free trial started! Enjoy premium features 🎉'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Start Trial'),
          ),
        ],
      ),
    );
  }
}