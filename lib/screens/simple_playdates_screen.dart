import 'package:flutter/material.dart';

class SimplePlaydatesScreen extends StatelessWidget {
  final int? initialTabIndex;
  final String? highlightPlaydateId;

  const SimplePlaydatesScreen({
    super.key,
    this.initialTabIndex,
    this.highlightPlaydateId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playdates'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64),
            SizedBox(height: 16),
            Text(
              'Playdates Feature',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Coming soon with full functionality!'),
          ],
        ),
      ),
    );
  }
}
