import 'dart:io';
import 'package:img_picker/img_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get the current authenticated user
  User? get currentUser => _client.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // AUTHENTICATION METHODS

  Future<void> registerUser(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Create an empty profile entry when user registers
        await _client.from('profiles').insert({
          'id': response.user!.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print("Error during registration: $e");
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> loginUser(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error during login: $e");
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logoutUser() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print("Error during logout: $e");
      throw Exception('Logout failed: $e');
    }
  }

  // PROFILE METHODS

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return response;
    } catch (e) {
      print("Error fetching profile: $e");
      return null; // Return null instead of throwing to handle new users gracefully
    }
  }

  Future<void> updateUserProfile({
    String? fullName,
    String? phoneNumber,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final updateData = {
        'updated_at': DateTime.now().toIso8601String(),
        if (fullName != null) 'full_name': fullName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _client.from('profiles').upsert({
        'id': currentUser!.id,
        ...updateData,
      });

      print('Profile updated successfully');
    } catch (e) {
      print("Error updating profile: $e");
      throw Exception('Error updating profile: $e');
    }
  }

  Future<String?> uploadProfileImage(XFile image) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final userId = currentUser!.id;
      final fileName =
          'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(image.path);

      await _client.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Set to true to replace if file exists
            ),
          );

      final imageUrl = _client.storage.from('avatars').getPublicUrl(fileName);

      // Update the profile with the new avatar URL
      await updateUserProfile(avatarUrl: imageUrl);

      return imageUrl;
    } catch (e) {
      print("Error uploading profile image: $e");
      throw Exception('Error uploading profile image: $e');
    }
  }

  // ITEM METHODS (YOUR EXISTING CODE)

  Future<String?> uploadImage(XFile image) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }
      final userId = currentUser!.id;
      final fileName =
          'user_$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(image.path);
      await _client.storage.from('images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      final imageUrl = _client.storage.from('images').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      print("Error uploading image: $e");
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> addItem({
    required String title,
    required String description,
    required String location,
    required String dateLost,
    required String imageUrl,
    required String email,
    required String phoneNo,
    String category = 'lost', // Added category parameter with default value
  }) async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }
      await _client.from('items').insert({
        'title': title,
        'description': description,
        'location': location,
        'date_lost': dateLost,
        'image_url': imageUrl,
        'email': email,
        'phone_no': phoneNo,
        'user_id': currentUser!.id, // Use user_id instead of id
        'created_at': DateTime.now().toIso8601String(),
        'category': category, // Added category field
      });
      print('Item added successfully');
    } catch (e) {
      print("Error adding item: $e");
      throw Exception('Error adding item: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    try {
      final response = await _client
          .from('items')
          .select()
          .order('created_at', ascending: false);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print("Error fetching items: $e");
      throw Exception('Error fetching items: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserItems() async {
    try {
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }
      final response = await _client
          .from('items')
          .select()
          .eq('user_id', currentUser!.id) // Use user_id instead of id
          .order('created_at', ascending: false);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print("Error fetching user items: $e");
      throw Exception('Error fetching user items: $e');
    }
  }
}
