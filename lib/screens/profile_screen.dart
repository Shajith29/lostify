import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:img_picker/img_picker.dart';
import 'package:lostify/screens/home_screen.dart';
import 'package:lostify/service/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isInitialSetup;

  const ProfileScreen({Key? key, this.isInitialSetup = false})
      : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker(); // Correct initialization

  bool _isLoading = false;
  bool _isImageUploading = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (!widget.isInitialSetup) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final profileData = await _supabaseService.getUserProfile();
      if (profileData != null) {
        setState(() {
          _nameController.text = profileData['full_name'] ?? '';
          _phoneController.text = profileData['phone_number'] ?? '';
          _bioController.text = profileData['bio'] ?? '';
          _avatarUrl = profileData['avatar_url'];
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      Fluttertoast.showToast(msg: "Error loading profile");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _supabaseService.updateUserProfile(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
      );

      Fluttertoast.showToast(msg: "Profile updated successfully!");

      if (widget.isInitialSetup) {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => HomeScreen()));
      }
    } catch (e) {
      print("Error updating profile: $e");
      Fluttertoast.showToast(msg: "Error updating profile");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      setState(() => _isImageUploading = true);

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        print("Image selected: ${image.path}");
        try {
          final imageUrl = await _supabaseService.uploadProfileImage(image);
          if (imageUrl != null) {
            setState(() => _avatarUrl = imageUrl);
            Fluttertoast.showToast(msg: "Profile picture updated!");
          } else {
            print("Image URL returned as null");
            Fluttertoast.showToast(msg: "Failed to get image URL");
          }
        } catch (uploadError) {
          print("Specific upload error: $uploadError");
          Fluttertoast.showToast(msg: "Error uploading: $uploadError");
        }
      } else {
        print("No image selected");
      }
    } catch (e) {
      print("General error in _uploadAvatar: $e");
      Fluttertoast.showToast(msg: "Error selecting image: $e");
    } finally {
      setState(() => _isImageUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isInitialSetup ? "Complete Your Profile" : "Edit Profile"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _uploadAvatar,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              image: _avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _avatarUrl == null
                                ? Icon(Icons.person,
                                    size: 60, color: Colors.grey[400])
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: _isImageUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(widget.isInitialSetup
                          ? "Complete Setup"
                          : "Save Changes"),
                    ),
                    if (widget.isInitialSetup) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomeScreen()));
                        },
                        child: const Text("Skip for now"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
