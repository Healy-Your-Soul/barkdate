import 'package:flutter/material.dart';

class DogFriendOption {
  final String dogId;
  final String dogName;
  final String? dogBreed;
  final String ownerName;
  final String? photoUrl;

  const DogFriendOption({
    required this.dogId,
    required this.dogName,
    required this.ownerName,
    this.dogBreed,
    this.photoUrl,
  });
}

class DogFriendSelectorDialog extends StatefulWidget {
  final List<DogFriendOption> options;
  final Set<String> initialSelection;

  const DogFriendSelectorDialog({
    super.key,
    required this.options,
    this.initialSelection = const {},
  });

  @override
  State<DogFriendSelectorDialog> createState() => _DogFriendSelectorDialogState();
}

class _DogFriendSelectorDialogState extends State<DogFriendSelectorDialog> {
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initialSelection};
  }

  List<DogFriendOption> get _filteredOptions {
    if (_query.isEmpty) return widget.options;
    final lowerQuery = _query.toLowerCase();
    return widget.options.where((option) {
      return option.dogName.toLowerCase().contains(lowerQuery) ||
          option.ownerName.toLowerCase().contains(lowerQuery) ||
          (option.dogBreed?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  void _toggleSelection(String dogId) {
    setState(() {
      if (_selectedIds.contains(dogId)) {
        _selectedIds.remove(dogId);
      } else {
        _selectedIds.add(dogId);
      }
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog( 
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite dog friends',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the pups you want to invite to your event.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by dog or owner name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: widget.options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No dog friends yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add friends from the feed or playdates to invite them to events.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredOptions.length,
                        itemBuilder: (context, index) {
                          final option = _filteredOptions[index];
                          final isSelected = _selectedIds.contains(option.dogId);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(option.dogId),
                            title: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: option.photoUrl != null && option.photoUrl!.isNotEmpty
                                      ? NetworkImage(option.photoUrl!)
                                      : null,
                                  child: option.photoUrl == null || option.photoUrl!.isEmpty
                                      ? const Icon(Icons.pets, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(option.dogName, style: theme.textTheme.titleMedium),
                                      Row(
                                        children: [
                                          Text(option.ownerName, style: theme.textTheme.bodySmall),
                                          if (option.dogBreed != null && option.dogBreed!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.circle, size: 4),
                                            const SizedBox(width: 6),
                                            Text(option.dogBreed!, style: theme.textTheme.bodySmall),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear'),
                  ),
                  FilledButton.icon(
                    onPressed: widget.options.isEmpty ? null : _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: Text(_selectedIds.isEmpty
                        ? 'Invite selected'
                        : 'Invite ${_selectedIds.length}'),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
