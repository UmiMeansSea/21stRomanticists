import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/firebase_service.dart';

/// Full submission form for poems and prose.
/// Calls [FirebaseService.instance.submitWork] on submit.
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

  SubmissionCategory _category = SubmissionCategory.poems;
  bool _isAnonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final submission = Submission(
      authorName: _isAnonymous ? 'Anonymous' : _authorController.text.trim(),
      title: _titleController.text.trim(),
      category: _category,
      content: _contentController.text.trim(),
      isAnonymous: _isAnonymous,
      submittedAt: DateTime.now(),
    );

    try {
      await FirebaseService.instance.submitWork(submission);
      if (mounted) {
        _formKey.currentState?.reset();
        _authorController.clear();
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _isAnonymous = false;
          _category = SubmissionCategory.poems;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your work has been submitted for review.',
              style: GoogleFonts.literata(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseServiceException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submission failed: ${e.message}',
              style: GoogleFonts.literata(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred. Please try again.',
              style: GoogleFonts.literata(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submit Your Work'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Share Your Voice',
                style: GoogleFonts.ebGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit your poems and prose for the editors to review.',
                style: GoogleFonts.literata(
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              const _SectionDivider(),
              const SizedBox(height: 28),

              // ── Anonymous toggle ─────────────────────────────────
              _buildAnonymousToggle(),
              const SizedBox(height: 24),

              // ── Author name ──────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: _isAnonymous
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Author Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const ValueKey('authorField'),
                            controller: _authorController,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.literata(fontSize: 16),
                            decoration: _inputDec('Your name'),
                            validator: (v) {
                              if (_isAnonymous) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your name or toggle Anonymous.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),

              // ── Title ────────────────────────────────────────────
              _FieldLabel('Title'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.ebGaramond(fontSize: 20),
                decoration: _inputDec('Give your piece a title'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a title.';
                  }
                  if (v.trim().length < 3) {
                    return 'Title must be at least 3 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Category ──────────────────────────────────────────
              _FieldLabel('Category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<SubmissionCategory>(
                initialValue: _category,
                style: GoogleFonts.literata(
                    fontSize: 16, color: AppColors.onSurface),
                dropdownColor: AppColors.surfaceContainerLow,
                decoration: _inputDec(''),
                items: SubmissionCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.label),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 24),

              // ── Content ───────────────────────────────────────────
              _FieldLabel('Your Work'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contentController,
                maxLines: null,
                minLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.literata(fontSize: 16, height: 1.75),
                decoration: _inputDec(
                  'Write or paste your poem or prose here…',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Content cannot be empty.';
                  }
                  if (v.trim().split('\n').length < 2 &&
                      v.trim().split(' ').length < 10) {
                    return 'Please provide more content (at least a few lines).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 36),

              // ── Submit button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Submit for Review',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Submissions are reviewed before publication.',
                  style: GoogleFonts.literata(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

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
                Text(
                  'Submit Anonymously',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your name will not appear with the piece.',
                  style: GoogleFonts.literata(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.literata(
        fontSize: 15,
        color: AppColors.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Field label ─────────────────────────────────────────────────────────────

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
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

// ─── Section divider ─────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 0.4, color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '✦',
            style: GoogleFonts.ebGaramond(
              fontSize: 14,
              color: AppColors.outline,
            ),
          ),
        ),
        Expanded(child: Container(height: 0.4, color: AppColors.outlineVariant)),
      ],
    );
  }
}
