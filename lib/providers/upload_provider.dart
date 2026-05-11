import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/image_service.dart';

enum UploadStatus { idle, uploading, success, error }

/// Handles background submission uploads so the UI is never blocked.
///
/// Strategy:
/// - NEW posts with an image: pre-allocate a Firestore doc ID, then
///   run image upload and the initial doc write in parallel using
///   [Future.wait]. Once both complete, patch the doc with the image URL.
/// - UPDATES: upload image first (we need the URL), then patch.
/// - NEW posts without image: single Firestore write.
class UploadProvider extends ChangeNotifier {
  UploadStatus _status = UploadStatus.idle;
  String? _errorMessage;

  UploadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  void reset() {
    _status = UploadStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Kicks off a non-blocking upload. Call-and-forget — the caller should
  /// NOT await this. Navigation can happen immediately after calling.
  Future<void> startUpload({
    required String uid,
    required Submission submission,
    File? imageFile,
    bool isUpdate = false,
  }) async {
    _status = UploadStatus.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isUpdate && submission.id != null) {
        // ── UPDATE path ─────────────────────────────────────────────────────
        // Must resolve the image URL before patching the doc.
        String? imageUrl = submission.imageUrl;
        if (imageFile != null) {
          // [Technique: background compress] ImageService uses compute() internally
          final compressed = await ImageService.compressImage(imageFile, quality: 75, maxWidth: 1080);
          imageUrl = await FirebaseService.instance.uploadSubmissionImage(uid, compressed);
        }
        final updated = submission.copyWith(imageUrl: imageUrl);
        await FirebaseService.instance.updateSubmission(submission.id!, updated);

      } else if (imageFile != null) {
        // ── NEW POST with image — run in parallel ────────────────────────────
        // Pre-allocate a Firestore document ID so we can write the doc and
        // upload the image at the same time.
        final docRef = FirebaseFirestore.instance.collection('submissions').doc();

        // [Technique: background compress] runs in a background isolate
        final compressed = await ImageService.compressImage(imageFile, quality: 75, maxWidth: 1080);

        // [Technique: Future.wait] kick off upload + placeholder write together
        final placeholderSub = submission.copyWith(id: docRef.id, imageUrl: null);

        final results = await Future.wait([
          // Task A: Upload the image to Cloudinary
          FirebaseService.instance.uploadSubmissionImage(uid, compressed),
          // Task B: Write the text document to Firestore immediately (no image yet)
          docRef.set(placeholderSub.toJson()).then((_) => ''),
        ]);

        // Patch the doc with the resolved image URL
        final imageUrl = results[0];
        await docRef.update({'imageUrl': imageUrl});

      } else {
        // ── NEW POST, no image — simple write ────────────────────────────────
        await FirebaseService.instance.submitWork(submission);
      }

      _status = UploadStatus.success;
      notifyListeners();

      // Auto-dismiss success indicator after 3 s
      Future.delayed(const Duration(seconds: 3), () {
        if (_status == UploadStatus.success) reset();
      });
    } catch (e) {
      _status = UploadStatus.error;
      _errorMessage = e.toString();
      notifyListeners();

      // Auto-dismiss error after 5 s
      Future.delayed(const Duration(seconds: 5), () {
        if (_status == UploadStatus.error) reset();
      });
    }
  }
}
