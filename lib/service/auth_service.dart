import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AuthService {
  // Sign in the user
  Future<void> loginUser(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        Fluttertoast.showToast(msg: "Login successful");
      } else {
        Fluttertoast.showToast(msg: "Invalid credentials");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Login failed: $e");
    }
  }

  // Register a new user
  Future<void> registerUser(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        Fluttertoast.showToast(msg: "Registration successful");
      } else {
        Fluttertoast.showToast(msg: "Registration failed");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Registration failed: $e");
    }
  }

  // Sign out the user
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      Fluttertoast.showToast(msg: "Logged out successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Logout failed: $e");
    }
  }

  // Check if the user is logged in
  bool isUserLoggedIn() {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null;
  }
}
