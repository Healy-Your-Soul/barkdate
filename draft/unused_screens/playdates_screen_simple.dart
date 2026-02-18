import 'package:flutter/material.dart';

class PlaydatesScreen extends StatefulWidget {
  final int? initialTabIndex;
  final String? highlightPlaydateId;

  const PlaydatesScreen(
      {Key? key, this.initialTabIndex, this.highlightPlaydateId})
      : super(key: key);

  @override
  State<PlaydatesScreen> createState() => _PlaydatesScreenState();
}

class _PlaydatesScreenState extends State<PlaydatesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playdates')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Playdates Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Temporary placeholder - Full implementation in progress',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
