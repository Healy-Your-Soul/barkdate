import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barkdate/services/dog_sharing_service.dart';

/// Dialog to manage sharing a dog profile with other users (many-to-many ownership).
/// Supports:
///  - Generating a time‑limited share link
///  - Copying the link to clipboard
///  - Listing existing shared users & access levels
///  - Revoking a user's access
/// (Future) Adding a user directly by ID / email (left as TODO until lookup UX exists)
class DogShareDialog extends StatefulWidget {
	final String dogId;
	final String dogName;

	const DogShareDialog({super.key, required this.dogId, required this.dogName});

	static Future<void> open(BuildContext context, {required String dogId, required String dogName}) async {
		await showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			backgroundColor: Colors.transparent,
			builder: (ctx) => FractionallySizedBox(
				heightFactor: 0.85,
				child: DogShareDialog(dogId: dogId, dogName: dogName),
			),
		);
	}

	@override
	State<DogShareDialog> createState() => _DogShareDialogState();
}

class _DogShareDialogState extends State<DogShareDialog> {
	bool _loading = false;
	bool _generating = false;
	String? _currentLink;
	List<Map<String, dynamic>> _sharedUsers = [];
	String? _error;
	String _selectedAccessLevel = 'co_owner';

	// Access level options
	final Map<String, String> _accessLevels = {
		'co_owner': 'Co-Owner',
		'caregiver': 'Caregiver', 
		'dogwalker': 'Dog Walker',
	};

	final Map<String, String> _accessDescriptions = {
		'co_owner': 'Full access: view, edit, playdates, and share',
		'caregiver': 'Care access: view, edit, and playdates',
		'dogwalker': 'Walker access: view and playdates only',
	};

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() {
			_loading = true;
			_error = null;
		});
		try {
			final users = await DogSharingService.getDogSharedUsers(widget.dogId);
			if (mounted) {
				setState(() => _sharedUsers = users);
			}
		} catch (e) {
			if (mounted) setState(() => _error = e.toString());
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _generateLink() async {
		setState(() => _generating = true);
		try {
			final link = await DogSharingService.generateShareLink(widget.dogId, widget.dogName, accessLevel: _selectedAccessLevel);
			await Clipboard.setData(ClipboardData(text: link));
			if (mounted) {
				setState(() => _currentLink = link);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('${_accessLevels[_selectedAccessLevel]} share link copied to clipboard')),
				);
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed: $e')),
				);
			}
		} finally {
			if (mounted) setState(() => _generating = false);
		}
	}

	Future<void> _removeUser(String userId) async {
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('Remove Access'),
				content: const Text('This user will lose access to this dog.'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
					TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
				],
			),
		);
		if (confirmed != true) return;
		try {
			await DogSharingService.removeUserAccess(widget.dogId, userId);
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Access removed')),
				);
			}
			_load();
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed: $e')),
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		return Material(
			color: Colors.transparent,
			child: Container(
				decoration: BoxDecoration(
					color: theme.colorScheme.surface,
					borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
				),
				child: SafeArea(
					top: false,
					child: Padding(
						padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Center(
									child: Container(
										width: 44,
										height: 4,
										decoration: BoxDecoration(
											color: theme.colorScheme.outlineVariant.withOpacity(.4),
											borderRadius: BorderRadius.circular(4),
										),
									),
								),
								const SizedBox(height: 16),
								Text('Share ${widget.dogName}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
								const SizedBox(height: 4),
								Text('Choose access level and generate a 7‑day link to share.', style: theme.textTheme.bodySmall),
								const SizedBox(height: 20),
								// Access level selector
								Card(
									elevation: 0,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outline.withOpacity(.15))),
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text('Access Level', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
												const SizedBox(height: 12),
												..._accessLevels.entries.map((entry) => 
													RadioListTile<String>(
														title: Text(entry.value),
														subtitle: Text(_accessDescriptions[entry.key]!, style: theme.textTheme.bodySmall),
														value: entry.key,
														groupValue: _selectedAccessLevel,
														onChanged: (value) => setState(() => _selectedAccessLevel = value!),
														contentPadding: EdgeInsets.zero,
													),
												),
											],
										),
									),
								),
								const SizedBox(height: 16),
								// Generate link section
								Card(
									elevation: 0,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outline.withOpacity(.15))),
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(
													children: [
														Expanded(
															child: Text(_currentLink == null ? 'Generate a share link' : _currentLink!,
																	maxLines: 2,
																	overflow: TextOverflow.ellipsis,
																	style: theme.textTheme.bodyMedium?.copyWith(
																		color: _currentLink == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
																	)),
														),
														const SizedBox(width: 12),
														ElevatedButton.icon(
															onPressed: _generating ? null : _generateLink,
															icon: _generating
																	? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
																	: const Icon(Icons.link),
															label: Text(_currentLink == null ? 'Generate' : 'Copy'),
															style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
														),
													],
												),
												const SizedBox(height: 4),
												if (_currentLink == null)
													Text('Valid for 7 days • ${_accessLevels[_selectedAccessLevel]} access level', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6))),
											],
										),
									),
								),
								const SizedBox(height: 24),
								Expanded(
									child: _loading
											? const Center(child: CircularProgressIndicator())
											: _error != null
													? Center(child: Text('Error: $_error'))
													: _sharedUsers.isEmpty
															? Center(
																	child: Column(
																		mainAxisAlignment: MainAxisAlignment.center,
																		children: [
																			Icon(Icons.group_outlined, size: 48, color: theme.colorScheme.outline),
																			const SizedBox(height: 12),
																			const Text('No shared users yet'),
																			const SizedBox(height: 4),
																			Text('Generate a link & send it to a friend', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6))),
																		],
																	),
																)
															: RefreshIndicator(
																	onRefresh: _load,
																	child: ListView.builder(
																		itemCount: _sharedUsers.length,
																		itemBuilder: (context, i) {
																			final u = _sharedUsers[i];
																			final user = u['users'] ?? {}; // via joined select alias
																			final displayName = user['name'] ?? user['email'] ?? 'User';
																			final accessLevel = u['ownership_type'] ?? 'view';
																			final accessLabel = _accessLevels[accessLevel] ?? accessLevel;
																			return ListTile(
																				contentPadding: EdgeInsets.zero,
																				leading: CircleAvatar(child: Text(displayName.toString().substring(0, 1).toUpperCase())),
																				title: Text(displayName),
																				subtitle: Text('Access: $accessLabel'),
																				trailing: IconButton(
																					icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
																					tooltip: 'Remove access',
																					onPressed: () => _removeUser(u['user_id'] as String),
																				),
																			);
																		},
																	),
																),
								),
								const SizedBox(height: 8),
								// Close button
								SizedBox(
									width: double.infinity,
									child: OutlinedButton(
										onPressed: () => Navigator.pop(context),
										child: const Text('Done'),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

