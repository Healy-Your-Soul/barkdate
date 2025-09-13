import 'package:flutter/material.dart';

class PlaydatesScreenMinimal extends StatefulWidget {
  final int? initialTabIndex;
  final String? highlightPlaydateId;

  const PlaydatesScreenMinimal({Key? key, this.initialTabIndex, this.highlightPlaydateId}) : super(key: key);

  @override
  State<PlaydatesScreenMinimal> createState() => _PlaydatesScreenMinimalState();
}

class _PlaydatesScreenMinimalState extends State<PlaydatesScreenMinimal> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playdates')),
      body: const Center(child: Text('Playdates Screen')),
    );
  }
}
