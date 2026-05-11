import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/image_service.dart';

enum UploadStatus { idle, uploading, success, error }

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
      String? imageUrl = submission.imageUrl;

      if (imageFile != null) {
        // Compress image first
        final compressed = await ImageService.compressImage(imageFile, quality: 75, maxWidth: 1080);
        // Upload image to Cloudinary
        imageUrl = await FirebaseService.instance.uploadSubmissionImage(uid, compressed);
      }

      final updatedSubmission = Submission(
        id: submission.id,
        userId: submission.userId,
        authorName: submission.authorName,
        title: submission.title,
        content: submission.content,
        submittedAt: submission.submittedAt,
        status: submission.status,
        category: submission.category,
        tags: submission.tags,
        isAnonymous: submission.isAnonymous,
        imageUrl: imageUrl,
        wpId: submission.wpId,
        wpLink: submission.wpLink,
      );

      if (isUpdate && updatedSubmission.id != null) {
        await FirebaseService.instance.updateSubmission(updatedSubmission.id!, updatedSubmission);
      } else {
        await FirebaseService.instance.submitWork(updatedSubmission);
      }

      _status = UploadStatus.success;
      notifyListeners();

      // Reset after a few seconds so the success message disappears
      Future.delayed(const Duration(seconds: 3), () {
        if (_status == UploadStatus.success) {
          reset();
        }
      });
    } catch (e) {
      _status = UploadStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      
      // Auto-reset error after a while
      Future.delayed(const Duration(seconds: 5), () {
        if (_status == UploadStatus.error) {
          reset();
        }
      });
    }
  }
}
