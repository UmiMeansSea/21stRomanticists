import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/image_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  File? _imageFile;
  String? _currentPhotoUrl;
  bool _loading = false;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    // Initialize ALL controllers eagerly so the build never crashes
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _currentPhotoUrl = user?.photoURL;
    // Then populate username/bio from Firestore asynchronously
    _loadFirestoreData();
  }

  Future<void> _loadFirestoreData() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final info = await FirebaseService.instance.getUserPublicInfo(uid);
    if (info != null && mounted) {
      setState(() {
        _usernameController.text = info['username'] ?? '';
        _bioController.text = info['bio'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
          ),
        ],
      );
      
      if (croppedFile != null) {
        setState(() => _imageFile = File(croppedFile.path));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      String? photoUrl = _currentPhotoUrl;

      // 1. Upload image if changed
      if (_imageFile != null) {
        final compressed = await ImageService.compressImage(_imageFile!, quality: 60, maxWidth: 512);
        photoUrl = await FirebaseService.instance.uploadProfilePicture(uid, compressed);
      }

      // 2. Update Firestore
      await FirebaseService.instance.updateUserProfile(uid, {
        'displayName': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'photoURL': photoUrl,
      });

      // 3. Update Auth Profile
      await auth.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.ebGaramond(fontSize: 22)),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: Text('SAVE', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Picker
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        image: _imageFile != null 
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : (_currentPhotoUrl != null 
                              ? DecorationImage(image: NetworkImage(_currentPhotoUrl!), fit: BoxFit.cover)
                              : null),
                      ),
                      child: (_imageFile == null && _currentPhotoUrl == null)
                          ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.outline)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.surface, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Name
              _ProfileTextField(
                label: 'FULL NAME',
                controller: _nameController,
                hint: 'Your display name',
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 24),
              
              // Username
              _ProfileTextField(
                label: 'USERNAME',
                controller: _usernameController,
                hint: 'unique_handle',
                prefix: '@',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Username is required';
                  if (v.length < 3) return 'Too short';
                  if (RegExp(r'[^a-zA-Z0-9_]').hasMatch(v)) return 'Letters, numbers, and underscores only';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Bio
              _ProfileTextField(
                label: 'BIO',
                controller: _bioController,
                hint: 'Tell the world your poetic story...',
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.prefix,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.literata(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
