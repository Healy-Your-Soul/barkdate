import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<FAQSection> _faqSections = [
    FAQSection(
      title: 'Getting Started',
      questions: [
        FAQItem(
          question: 'How do I create an account?',
          answer: 'To create an account, tap "Sign Up" on the login screen, enter your details, and follow the setup process to create profiles for you and your dog.',
        ),
        FAQItem(
          question: 'How do I add my dog\'s profile?',
          answer: 'During the initial setup, you\'ll be prompted to add your dog\'s profile. You can also add additional dogs later by going to Profile > My Dogs > Add Dog.',
        ),
        FAQItem(
          question: 'How do I find other dogs and owners?',
          answer: 'Use the "Catch" feature to swipe through nearby dogs, or browse the Feed to see dogs in your area. You can also use the Map to see dogs at nearby parks.',
        ),
      ],
    ),
    FAQSection(
      title: 'Using the App',
      questions: [
        FAQItem(
          question: 'How do I schedule a playdate?',
          answer: 'Once you\'ve matched with another dog or sent a "Bark", you can message the owner and suggest a playdate. Use the calendar icon in the chat to propose a time and location.',
        ),
        FAQItem(
          question: 'How do I join a group?',
          answer: 'You can find local dog groups in the Social Feed or through the Map feature. Tap "Join" on any group that interests you, and you\'ll be added to their activities.',
        ),
        FAQItem(
          question: 'How do I report a user?',
          answer: 'If you encounter inappropriate behavior, tap the three dots menu on any profile or message, select "Report", choose a reason, and submit your report. We take all reports seriously.',
        ),
      ],
    ),
    FAQSection(
      title: 'Account Settings',
      questions: [
        FAQItem(
          question: 'How do I change my password?',
          answer: 'Go to Settings > Account > Profile, then tap "Change Password". You\'ll need to enter your current password and choose a new one.',
        ),
        FAQItem(
          question: 'How do I update my profile information?',
          answer: 'Go to your Profile tab, tap the edit icon, and update any information you\'d like to change. Don\'t forget to save your changes!',
        ),
        FAQItem(
          question: 'How do I delete my account?',
          answer: 'Account deletion is permanent and cannot be undone. Please contact our support team at support@barkdate.com if you\'d like to proceed with deleting your account.',
        ),
      ],
    ),
    FAQSection(
      title: 'Safety & Privacy',
      questions: [
        FAQItem(
          question: 'Is my location information safe?',
          answer: 'We only share your general area (within a few kilometers) with other users, never your exact location. You can control location sharing in Settings > Privacy.',
        ),
        FAQItem(
          question: 'How do I block someone?',
          answer: 'Tap the three dots menu on any profile or in a chat, then select "Block". Blocked users won\'t be able to see your profile or contact you.',
        ),
        FAQItem(
          question: 'What should I do before meeting someone?',
          answer: 'Always meet in public places like dog parks. Let a friend know where you\'re going. Trust your instincts - if something doesn\'t feel right, don\'t hesitate to leave.',
        ),
      ],
    ),
    FAQSection(
      title: 'Premium Features',
      questions: [
        FAQItem(
          question: 'What does Premium include?',
          answer: 'Premium includes unlimited playdates, advanced search filters, priority support, exclusive events, and the ability to see who liked your dog\'s profile.',
        ),
        FAQItem(
          question: 'How do I upgrade to Premium?',
          answer: 'Go to Profile > Go Premium to see all available plans and upgrade. You can choose monthly or yearly billing.',
        ),
        FAQItem(
          question: 'Can I cancel my Premium subscription?',
          answer: 'Yes, you can cancel anytime through your device\'s app store settings. Your Premium features will remain active until the end of your billing period.',
        ),
      ],
    ),
  ];

  List<FAQSection> get _filteredSections {
    if (_searchQuery.isEmpty) return _faqSections;
    
    return _faqSections.map((section) {
      final filteredQuestions = section.questions.where((question) =>
        question.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        question.answer.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
      
      return FAQSection(
        title: section.title,
        questions: filteredQuestions,
      );
    }).where((section) => section.questions.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Help',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar (simplified)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search for answers',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          
          // FAQ Content
          Expanded(
            child: _filteredSections.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSections.length + 1, // +1 for contact card
                    itemBuilder: (context, index) {
                      if (index == _filteredSections.length) {
                        // Contact card at the end
                        return _buildContactCard();
                      }
                      final section = _filteredSections[index];
                      return _buildFAQSection(section);
                    },
                  ),
          ),
        ],
      ),
      ), // Close GestureDetector
    );
  }
  
  Widget _buildContactCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.support_agent,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still need help?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'support@barkdate.com',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact: support@barkdate.com')),
              );
            },
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords or browse the categories below.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(FAQSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...section.questions.map((question) => _buildFAQItem(question)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFAQItem(FAQItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          item.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            item.answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class FAQSection {
  final String title;
  final List<FAQItem> questions;

  FAQSection({required this.title, required this.questions});
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}
