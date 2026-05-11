import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';

/// Write & publish screen — posts go live immediately (status: approved).
class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();

  SubmissionCategory _category = SubmissionCategory.poems;
  bool _isAnonymous = false;
  bool _submitting = false;

  // ── Tags (max 3) ──────────────────────────────────────────────────────────
  final List<String> _tags = [];

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isEmpty) return;
    if (_tags.length >= 3) {
      _showSnack('Maximum 3 tags allowed.', isError: true);
      return;
    }
    if (_tags.contains(tag)) {
      _tagController.clear();
      return;
    }
    setState(() => _tags.add(tag));
    _tagController.clear();
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  // ── Cover image ───────────────────────────────────────────────────────────
  File? _imageFile;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) {
      final cropped = await _cropImage(picked.path);
      if (cropped != null) {
        setState(() => _imageFile = File(cropped.path));
      } else {
        // If they cancel cropping, we can still use the image or ask them to crop.
        // The user said "let the option of image cropping", which implies it should be possible.
        // But they also said "lock the cropping to that". 
        // So I will require cropping or at least use the uncropped one if they skip.
        setState(() => _imageFile = File(picked.path));
      }
    }
  }

  Future<CroppedFile?> _cropImage(String path) async {
    return await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressQuality: 85,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Cover Image',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
          activeControlsWidgetColor: AppColors.accent,
        ),
        IOSUiSettings(
          title: 'Crop Cover Image',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
  }

  void _removeImage() => setState(() => _imageFile = null);

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;

    setState(() => _submitting = true);

    try {
      // Upload cover image first if selected
      String? imageUrl;
      if (_imageFile != null && uid != null) {
        imageUrl = await FirebaseService.instance
            .uploadSubmissionImage(uid, _imageFile!);
      }

      final submission = Submission(
        userId: uid,
        authorName: _isAnonymous
            ? 'Anonymous'
            : (auth.user?.displayName ?? _authorController.text.trim()),
        title: _titleController.text.trim(),
        category: _category,
        content: _contentController.text.trim(),
        isAnonymous: _isAnonymous,
        submittedAt: DateTime.now(),
        tags: List.from(_tags),
        imageUrl: imageUrl,
      );

      await FirebaseService.instance.submitWork(submission);

      if (mounted) {
        // Update local feed for instant visibility
        context.read<PostsProvider>().addSubmissionLocally(submission);
        
        // Precache the new image if it exists for a jank-free transition
        if (imageUrl != null && mounted) {
          precacheImage(CachedNetworkImageProvider(imageUrl), context);
        }
        
        context.read<PostsProvider>().refresh(); // Still refresh background
        _reset();
        _showSnack('❆ Your work is now live!');
      }
    } on FirebaseServiceException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('Publish failed: ${e.message}', isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('An unexpected error occurred.', isError: true);
      }
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _authorController.clear();
    _titleController.clear();
    _contentController.clear();
    _tagController.clear();
    setState(() {
      _isAnonymous = false;
      _category = SubmissionCategory.poems;
      _tags.clear();
      _imageFile = null;
      _submitting = false;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.literata(color: AppColors.background)),
        backgroundColor: isError ? AppColors.error : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('THE ROMANTICISTS',
            style: GoogleFonts.ebGaramond(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            )),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // ── Header ─────────────────────────────────────────────────
                  Text('Share Your Voice',
                      style: GoogleFonts.ebGaramond(
                          fontSize: 32, fontWeight: FontWeight.w500, height: 1.15)),
                  const SizedBox(height: 6),
                  Text(
                    'Your work publishes instantly to the community.',
                    style: GoogleFonts.literata(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 28),
                  const _SectionDivider(),
                  const SizedBox(height: 28),

                  // ── Author name / Anonymous toggle ─────────────────────────
                  if (auth.user != null) ...[
                    _buildLoggedInAuthorLabel(auth.user!),
                  ] else ...[
                    _buildAnonymousToggle(),
                    const SizedBox(height: 24),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _isAnonymous
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Author Name'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  key: const ValueKey('authorField'),
                                  controller: _authorController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.literata(fontSize: 16),
                                  decoration: _dec('Your name'),
                                  validator: (v) {
                                    if (_isAnonymous) return null;
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter your name or toggle Anonymous.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                    ),
                  ],

                  // ── Title ───────────────────────────────────────────────────
                  const _FieldLabel('Title'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.ebGaramond(fontSize: 20),
                    decoration: _dec('Give your piece a title'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter a title.';
                      if (v.trim().length < 3) return 'Title must be at least 3 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Category ────────────────────────────────────────────────
                  const _FieldLabel('Category'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SubmissionCategory>(
                    value: _category,
                    style: GoogleFonts.literata(fontSize: 16, color: AppColors.onSurface),
                    dropdownColor: AppColors.surfaceContainerLow,
                    decoration: _dec(''),
                    items: SubmissionCategory.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _category = v); },
                  ),
                  const SizedBox(height: 24),

                  // ── Cover image ─────────────────────────────────────────────
                  const _FieldLabel('Cover Image (optional)'),
                  const SizedBox(height: 10),
                  _buildImagePicker(),
                  const SizedBox(height: 24),

                  // ── Tags (max 3) ─────────────────────────────────────────────
                  Row(
                    children: [
                      const _FieldLabel('Tags'),
                      const SizedBox(width: 6),
                      Text('(max 3)',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.outline, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTagInput(),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _tags
                          .map((t) => _TagChip(tag: t, onRemove: () => _removeTag(t)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Content ─────────────────────────────────────────────────
                  const _FieldLabel('Your Work'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 10,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.literata(fontSize: 16, height: 1.8),
                    decoration: _dec('Write or paste your poem or prose here…'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Content cannot be empty.';
                      if (v.trim().split('\n').length < 2 && v.trim().split(' ').length < 10) {
                        return 'Please provide more content (at least a few lines).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: AppColors.onPrimary, strokeWidth: 2))
                          : Text('Publish Now',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ─── Input Decorator ───────────────────────────────────────────────────────
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.literata(color: AppColors.onSurfaceVariant),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      );

  // ─── Cover image picker ────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    if (_imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              _imageFile!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.outline.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text('Add cover image',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.outline)),
          ],
        ),
      ),
    );
  }

  // ─── Tag input ─────────────────────────────────────────────────────────────

  Widget _buildTagInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _tagController,
            style: GoogleFonts.inter(fontSize: 14),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _addTag(),
            decoration: _dec('e.g. romance, sonnets, nature').copyWith(
              hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _addTag,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _tags.length >= 3
                  ? AppColors.surfaceContainerHigh
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.add,
                color: _tags.length >= 3
                    ? AppColors.outline
                    : AppColors.onPrimary,
                size: 20),
          ),
        ),
      ],
    );
  }

  // ─── Anonymous toggle ──────────────────────────────────────────────────────

  Widget _buildLoggedInAuthorLabel(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.surfaceContainerHigh,
              backgroundImage: user.photoURL != null ? CachedNetworkImageProvider(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, size: 14) : null,
            ),
            const SizedBox(width: 10),
            Text(
              _isAnonymous ? 'Posting Anonymously' : 'Posting as ${user.displayName ?? 'Romanticist'}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Switch(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
        if (_isAnonymous)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 38),
            child: Text(
              'Your identity will be hidden.',
              style: GoogleFonts.literata(
                fontSize: 12,
                color: AppColors.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnonymousToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publish Anonymously',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text('Your name will not appear with the piece.',
                    style: GoogleFonts.literata(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;
  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$tag',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.onSurfaceVariant),
    );
  }
}

// ─── Section divider ──────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 0.4, color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('✦',
              style: GoogleFonts.ebGaramond(fontSize: 14, color: AppColors.outline)),
        ),
        Expanded(child: Container(height: 0.4, color: AppColors.outlineVariant)),
      ],
    );
  }
}
