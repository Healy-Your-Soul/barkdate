import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/dog.dart';

class CatchScreen extends StatefulWidget {
  const CatchScreen({super.key});

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen> {
  int currentIndex = 0;
  final dogs = SampleData.nearbyDogs;

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= dogs.length) {
      return _buildNoMoreDogsScreen(context);
    }

    final currentDog = dogs[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Catch',
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
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        // Dog photo
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(currentDog.photos.first),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Dog info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentDog.name,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currentDog.breed}, ${currentDog.age} years old',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${currentDog.distanceKm.toStringAsFixed(1)} miles away',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline button
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _onDecline(),
                      icon: Icon(
                        Icons.close,
                        size: 30,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                  // Accept button
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _onAccept(currentDog),
                      icon: Icon(
                        Icons.favorite,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMoreDogsScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Catch',
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No more dogs nearby!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for new friends',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Feed'),
            ),
          ],
        ),
      ),
    );
  }

  void _onAccept(Dog dog) {
    setState(() => currentIndex++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You matched with ${dog.name}! 💕'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onDecline() {
    setState(() => currentIndex++);
  }
}