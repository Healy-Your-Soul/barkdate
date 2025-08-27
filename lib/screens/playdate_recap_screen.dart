import 'package:flutter/material.dart';
import 'package:barkdate/models/playdate.dart';

class PlaydateRecapScreen extends StatefulWidget {
  final Playdate playdate;
  const PlaydateRecapScreen({super.key, required this.playdate});

  @override
  State<PlaydateRecapScreen> createState() => _PlaydateRecapScreenState();
}

class _PlaydateRecapScreenState extends State<PlaydateRecapScreen> {
  int _experience = 0;
  int _place = 0;
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // TODO: Persist to Supabase tables (playdate_reviews, place_ratings)
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for the recap!')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _ratingRow(String label, int current, void Function(int) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: List.generate(5, (i) {
            final v = i + 1;
            final selected = v == current;
            return ChoiceChip(
              label: Text('$v star${v > 1 ? 's' : ''}'),
              selected: selected,
              onSelected: (_) => onSelect(v),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.playdate;
    return Scaffold(
      appBar: AppBar(title: const Text('Playdate Recap')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.pets)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.invitedDogName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(p.location, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                ]),
              ),
            ]),
            const SizedBox(height: 24),
            _ratingRow('How was your playdate?', _experience, (v) => setState(() => _experience = v)),
            const SizedBox(height: 24),
            _ratingRow('How would you rate the place?', _place, (v) => setState(() => _place = v)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Share your thoughts about the playdate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_experience == 0 || _place == 0 || _submitting) ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


