import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class DogSearchSheet extends StatefulWidget {
  final List<String> excludedDogIds;

  const DogSearchSheet({
    super.key,
    this.excludedDogIds = const [],
  });

  @override
  State<DogSearchSheet> createState() => _DogSearchSheetState();
}

class _DogSearchSheetState extends State<DogSearchSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Dog> _friendsDogs = [];
  List<Dog> _publicDogs = [];
  Set<String> _selectedDogIds = {}; // Use a set to track selections
  List<Dog> _selectedDogs = []; // Return full objects
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDogs([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Call the RPC function we created
      final response = await SupabaseConfig.client.rpc(
        'search_dogs_for_playdate',
        params: {
          'search_query': query?.isEmpty == true ? null : query,
          'user_id': userId,
          'limit_count': 50,
        },
      );

      final List<dynamic> data = response as List<dynamic>;
      final allDogs = data.map((json) {
        return _mapToDog(json);
      }).toList();

      setState(() {
        // Filter based on 'is_friend' from RPC response
        _friendsDogs = data
            .where((d) => d['is_friend'] == true)
            .map((json) => _mapToDog(json))
            .where((d) => !widget.excludedDogIds.contains(d.id))
            .toList();

        _publicDogs = data
            .where((d) => d['is_friend'] == false)
            .map((json) => _mapToDog(json))
            .where((d) => !widget.excludedDogIds.contains(d.id))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading dogs: $e');
      setState(() => _error = 'Failed to load dogs');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Dog _mapToDog(Map<String, dynamic> json) {
    return Dog(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      breed: json['breed'] ?? 'Unknown',
      age: 0, // RPC doesn't return age, default to 0
      size: 'medium', // Default
      gender: 'unknown',
      bio: json['owner_name'] != null
          ? 'Owner: ${json['owner_name']}'
          : 'No bio', // Store owner name in bio for display
      photos: json['avatar_url'] != null ? [json['avatar_url']] : [],
      ownerName: json['owner_name'] ?? 'Unknown',
      distanceKm: 0,
      isMatched: false,
    );
  }

  void _onSearch(String value) {
    // Debounce can be added here
    _loadDogs(value);
  }

  void _toggleSelection(Dog dog) {
    setState(() {
      if (_selectedDogIds.contains(dog.id)) {
        _selectedDogIds.remove(dog.id);
        _selectedDogs.removeWhere((d) => d.id == dog.id);
      } else {
        _selectedDogIds.add(dog.id);
        _selectedDogs.add(dog);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with Done button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const Text(
                    'Invite Dogs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedDogs),
                    child: Text(
                      'Done (${_selectedDogIds.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by name...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'Friends'),
                Tab(text: 'All Dogs'),
              ],
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDogList(_friendsDogs, 'No friends found'),
                            _buildDogList(_publicDogs, 'No dogs found'),
                          ],
                        ),
            ),
          ],
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildDogList(List<Dog> dogs, String emptyMessage) {
    if (dogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dogs.length,
      itemBuilder: (context, index) {
        final dog = dogs[index];
        final isSelected = _selectedDogIds.contains(dog.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _toggleSelection(dog),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.05)
                    : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: dog.photos.isNotEmpty
                        ? NetworkImage(dog.photos.first)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: dog.photos.isEmpty
                        ? const Icon(Icons.pets, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dog.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${dog.breed} • Owner: ${dog.ownerName}', // Using ownerName field
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
