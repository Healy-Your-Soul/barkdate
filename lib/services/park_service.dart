import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:barkdate/models/featured_park.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Service layer for dog parks & featured parks.
/// Provides:
///  * Featured parks CRUD (add + list active)
///  * Nearby parks (currently derives from featured parks until dedicated table exists)
///  * Distance utilities
///  * Fallback mock data when Supabase not reachable / empty
class ParkService {
	static final _client = SupabaseConfig.client;

	/// Fetch active featured parks from Supabase. Falls back to mock data if none.
	static Future<List<FeaturedPark>> getFeaturedParks() async {
		try {
			final rows = await _client
					.from('featured_parks')
					.select('*')
					.eq('is_active', true)
					.order('rating', ascending: false) as List<dynamic>;

			if (rows.isNotEmpty) {
				return rows.map((e) => FeaturedPark.fromJson(e)).toList();
			}
			// Fallback mock if table empty
			return _mockFeaturedParks();
		} catch (e) {
			debugPrint('ParkService.getFeaturedParks error: $e');
			return _mockFeaturedParks();
		}
	}

	/// Insert a new featured park. Returns inserted park id (if available).
	static Future<String?> addFeaturedPark(FeaturedPark park) async {
		try {
			final insertData = {
				'name': park.name,
				'description': park.description,
				'latitude': park.latitude,
				'longitude': park.longitude,
				'amenities': park.amenities,
				'address': park.address,
				'rating': park.rating,
				'review_count': park.reviewCount,
				'photo_urls': park.photoUrls,
				'is_active': park.isActive,
			}..removeWhere((k, v) => v == null);

			final res = await _client
					.from('featured_parks')
					.insert(insertData)
					.select('id')
					.maybeSingle();
			return res?['id']?.toString();
		} catch (e) {
			debugPrint('ParkService.addFeaturedPark error: $e');
			rethrow;
		}
	}

	/// Get nearby parks ordered by distance.
	/// Uses PostGIS spatial queries on the server for 20-40x faster performance.
	/// Returns parks within radius_km sorted by distance with real-time active dog counts.
	static Future<List<Map<String, dynamic>>> getNearbyParks({
		required double latitude,
		required double longitude,
		double radiusKm = 25,
	}) async {
		try {
			debugPrint('🚀 Calling PostGIS RPC get_nearby_parks...');
			// Call PostGIS-powered RPC function for server-side spatial filtering
			final response = await _client.rpc(
				'get_nearby_parks',
				params: {
					'user_lat': latitude,
					'user_lng': longitude,
					'radius_km': radiusKm,
				},
			) as List<dynamic>;

			debugPrint('✅ PostGIS RPC SUCCESS: Got ${response.length} parks');
			// Convert response to expected format
			return response.map<Map<String, dynamic>>((row) {
				return {
					'id': row['id'],
					'name': row['name'],
					'description': row['description'],
					'latitude': row['latitude'],
					'longitude': row['longitude'],
					'address': row['address'],
					'distance': row['distance_km'], // Already calculated server-side
					'rating': row['rating']?.toDouble() ?? 0.0,
					'amenities': row['amenities'] ?? [],
					'active_dogs': row['active_dogs'] ?? 0,
				};
			}).toList();
		} catch (e) {
			debugPrint('❌ PostGIS RPC FAILED: $e');
			debugPrint('⚠️ Falling back to client-side filtering...');
			// Fallback to client-side filtering if RPC fails (backwards compatibility)
			return _getNearbyParksClientSide(
				latitude: latitude,
				longitude: longitude,
				radiusKm: radiusKm,
			);
		}
	}

	/// Fallback client-side distance filtering (legacy method for backwards compatibility).
	/// Used only if PostGIS RPC fails.
	static Future<List<Map<String, dynamic>>> _getNearbyParksClientSide({
		required double latitude,
		required double longitude,
		double radiusKm = 25,
	}) async {
		final featured = await getFeaturedParks();
		final List<Map<String, dynamic>> mapped = [];
		for (final park in featured) {
			final distKm = _distanceKm(latitude, longitude, park.latitude, park.longitude);
			if (distKm <= radiusKm) {
				mapped.add({
					'id': park.id,
					'name': park.name,
					'description': park.description,
					'latitude': park.latitude,
					'longitude': park.longitude,
					'address': park.address ?? 'Dog park',
					'distance': distKm,
					'rating': park.rating ?? 0.0,
					'amenities': park.amenities,
					// Simulated active dogs (legacy fallback)
					'active_dogs': (park.id.hashCode.abs() % 7) + 1,
				});
			}
		}
		mapped.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
		return mapped;
	}

	/// Simple Haversine distance in KM.
	static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
		const R = 6371.0; // km
		final dLat = _deg2rad(lat2 - lat1);
		final dLon = _deg2rad(lon2 - lon1);
		final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
				math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
						math.sin(dLon / 2) * math.sin(dLon / 2);
		final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
		return R * c;
	}

	static double _deg2rad(double d) => d * math.pi / 180.0;

	static List<FeaturedPark> _mockFeaturedParks() {
		return [
			FeaturedPark(
				id: 'mock_central',
				name: 'Central Bark Park',
				description: 'Large open space with separate small dog area.',
				latitude: 40.7829,
				longitude: -73.9654,
				amenities: const ['Fenced Area', 'Water Station', 'Waste Bags', 'Shade/Trees'],
				address: 'Central Park, NY',
				rating: 4.7,
				reviewCount: 132,
				photoUrls: const [],
				createdAt: DateTime.now(),
			),
			FeaturedPark(
				id: 'mock_river',
				name: 'Riverside Dog Run',
				description: 'Riverside trail with agility equipment.',
				latitude: 40.7489,
				longitude: -73.9857,
				amenities: const ['Agility Equipment', 'Water Station', 'Benches'],
				address: 'Riverside, NY',
				rating: 4.5,
				reviewCount: 88,
				photoUrls: const [],
				createdAt: DateTime.now(),
			),
			FeaturedPark(
				id: 'mock_beach',
				name: 'Sunset Beach Park',
				description: 'Beachside play zone – great at sunset.',
				latitude: 40.7614,
				longitude: -73.9776,
				amenities: const ['Water Station', 'Shade/Trees'],
				address: 'Beach Rd, NY',
				rating: 4.3,
				reviewCount: 54,
				photoUrls: const [],
				createdAt: DateTime.now(),
			),
		];
	}
}

