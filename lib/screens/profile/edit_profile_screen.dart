import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  
  double _ntrpRating = 3.0;
  String _skillLevel = 'intermediate';
  String _playingStyle = 'all-court';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      _displayNameController = TextEditingController(text: user.displayName);
      _cityController = TextEditingController(text: user.city);
      _stateController = TextEditingController(text: user.state);
      _ntrpRating = user.ntrpRating;
      _skillLevel = user.skillLevel;
      _playingStyle = user.playingStyle;
    } else {
      _displayNameController = TextEditingController();
      _cityController = TextEditingController();
      _stateController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  if (image != null) {
                    setState(() {
                      _imageFile = File(image.path);
                      _removePhoto = false;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  if (image != null) {
                    setState(() {
                      _imageFile = File(image.path);
                      _removePhoto = false;
                    });
                  }
                },
              ),
              if (_imageFile != null || 
                  Provider.of<UserProvider>(context, listen: false).currentUser?.photoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageFile = null;
                      _removePhoto = true;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authService = AuthService();
      final currentUser = userProvider.currentUser;
      
      print('Starting profile update...');
      print('Current user ID: ${currentUser?.id}');
      
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      String? photoUrl = currentUser.photoUrl;

      // Upload image to Firebase Storage if changed
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profiles')
            .child('${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(_imageFile!);
        photoUrl = await uploadTask.ref.getDownloadURL();
      }

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'displayName': _displayNameController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'ntrpRating': _ntrpRating,
        'skillLevel': _skillLevel,
        'playingStyle': _playingStyle,
        // Temporarily comment out timestamp to test
        // 'lastActive': FieldValue.serverTimestamp(),
      };

      print('Update data prepared: $updateData');

      // Handle photo updates
      if (_imageFile != null) {
        // New photo was selected
        updateData['photoUrl'] = photoUrl;
        print('Adding photo URL to update: $photoUrl');
      } else if (_removePhoto && currentUser.photoUrl != null) {
        // User chose to remove their photo
        updateData['photoUrl'] = FieldValue.delete();
        print('Removing photo URL from profile');
      }

      // Update user document in Firestore
      print('Calling updateUserProfile with userId: ${currentUser.id}');
      
      // First, let's try a simple direct update to test
      try {
        print('Testing direct Firestore update...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .update({'testField': 'testValue'});
        print('Direct test update succeeded!');
      } catch (testError) {
        print('Direct test update failed: $testError');
      }
      
      await authService.updateUserProfile(currentUser.id, updateData);
      print('updateUserProfile completed successfully');

      // Reload user data in provider
      await userProvider.loadCurrentUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('Error in _saveProfile: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primaryGreen,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (!_removePhoto && user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!) as ImageProvider
                              : null),
                      child: (_imageFile == null && (_removePhoto || user?.photoUrl == null))
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your city';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your state';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Skill Level Section
              const Text(
                'Skill Level',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // NTRP Rating Slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NTRP Rating'),
                      Text(
                        _ntrpRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _ntrpRating,
                    min: 1.0,
                    max: 7.0,
                    divisions: 12,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (value) {
                      setState(() {
                        _ntrpRating = value;
                        // Update skill level based on NTRP
                        if (value < 2.5) {
                          _skillLevel = 'beginner';
                        } else if (value < 3.5) {
                          _skillLevel = 'intermediate';
                        } else if (value < 4.5) {
                          _skillLevel = 'advanced';
                        } else {
                          _skillLevel = 'expert';
                        }
                      });
                    },
                  ),
                  Center(
                    child: Text(
                      _getSkillLevelDescription(_ntrpRating),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Playing Style
              const Text(
                'Playing Style',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _playingStyle,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports_tennis),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'baseline',
                    child: Text('Baseline Player'),
                  ),
                  DropdownMenuItem(
                    value: 'serve-and-volley',
                    child: Text('Serve and Volley'),
                  ),
                  DropdownMenuItem(
                    value: 'all-court',
                    child: Text('All-Court Player'),
                  ),
                  DropdownMenuItem(
                    value: 'counterpuncher',
                    child: Text('Counter Puncher'),
                  ),
                  DropdownMenuItem(
                    value: 'aggressive',
                    child: Text('Aggressive Baseliner'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _playingStyle = value!;
                  });
                },
              ),

              const SizedBox(height: 32),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSkillLevelDescription(double ntrp) {
    if (ntrp < 2.0) return 'Just starting to play tennis';
    if (ntrp < 2.5) return 'Beginner - Learning basic strokes';
    if (ntrp < 3.0) return 'Advanced Beginner - Developing consistency';
    if (ntrp < 3.5) return 'Intermediate - Comfortable with all strokes';
    if (ntrp < 4.0) return 'Advanced Intermediate - Good technique and strategy';
    if (ntrp < 4.5) return 'Advanced - Strong player with reliable shots';
    if (ntrp < 5.0) return 'Expert - Tournament level player';
    return 'Professional level player';
  }
}