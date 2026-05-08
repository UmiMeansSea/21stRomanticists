import 'package:cloud_firestore/cloud_firestore.dart';

/// The two literary categories a user can submit under.
enum SubmissionCategory { poems, prose }

extension SubmissionCategoryExt on SubmissionCategory {
  String get label {
    switch (this) {
      case SubmissionCategory.poems:
        return 'Poems';
      case SubmissionCategory.prose:
        return 'Prose';
    }
  }

  static SubmissionCategory fromString(String value) {
    if (value == 'prose') return SubmissionCategory.prose;
    return SubmissionCategory.poems;
  }
}

/// The moderation status of a submission.
enum SubmissionStatus { pending, approved, rejected }

extension SubmissionStatusExt on SubmissionStatus {
  String get value {
    switch (this) {
      case SubmissionStatus.approved:
        return 'approved';
      case SubmissionStatus.rejected:
        return 'rejected';
      case SubmissionStatus.pending:
        return 'pending';
    }
  }

  static SubmissionStatus fromString(String value) {
    if (value == 'approved') return SubmissionStatus.approved;
    if (value == 'rejected') return SubmissionStatus.rejected;
    return SubmissionStatus.pending;
  }
}

/// A user-submitted piece of writing stored in Firestore.
class Submission {
  final String? id;
  final String? userId;          // Firebase Auth UID — null for anonymous
  final String authorName;
  final String title;
  final SubmissionCategory category;
  final String content;
  final bool isAnonymous;
  final DateTime submittedAt;
  final SubmissionStatus status;

  const Submission({
    this.id,
    this.userId,
    required this.authorName,
    required this.title,
    required this.category,
    required this.content,
    required this.isAnonymous,
    required this.submittedAt,
    this.status = SubmissionStatus.pending,
  });

  // ─── Firestore ─────────────────────────────────────────────────────────────

  factory Submission.fromJson(Map<String, dynamic> json, {String? id}) {
    return Submission(
      id: id,
      userId: json['userId'] as String?,
      authorName: json['authorName'] as String? ?? 'Anonymous',
      title: json['title'] as String? ?? '',
      category: SubmissionCategoryExt.fromString(
        json['category'] as String? ?? 'poems',
      ),
      content: json['content'] as String? ?? '',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      submittedAt: json['submittedAt'] is Timestamp
          ? (json['submittedAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
              DateTime.now(),
      status: SubmissionStatusExt.fromString(
        json['status'] as String? ?? 'pending',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        if (userId != null) 'userId': userId,
        'authorName': isAnonymous ? 'Anonymous' : authorName,
        'title': title,
        'category': category.name,
        'content': content,
        'isAnonymous': isAnonymous,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'status': status.value,
      };

  Submission copyWith({
    String? id,
    String? userId,
    String? authorName,
    String? title,
    SubmissionCategory? category,
    String? content,
    bool? isAnonymous,
    DateTime? submittedAt,
    SubmissionStatus? status,
  }) {
    return Submission(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
    );
  }
}
