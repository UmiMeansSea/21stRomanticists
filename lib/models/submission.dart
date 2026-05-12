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
enum SubmissionStatus { pending, approved, rejected, draft }

extension SubmissionStatusExt on SubmissionStatus {
  String get value {
    switch (this) {
      case SubmissionStatus.approved:
        return 'approved';
      case SubmissionStatus.rejected:
        return 'rejected';
      case SubmissionStatus.draft:
        return 'draft';
      case SubmissionStatus.pending:
        return 'pending';
    }
  }

  static SubmissionStatus fromString(String value) {
    if (value == 'approved') return SubmissionStatus.approved;
    if (value == 'rejected') return SubmissionStatus.rejected;
    if (value == 'draft') return SubmissionStatus.draft;
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
  final List<String> tags;       // up to 3 user-defined tags
  final String? imageUrl;        // optional cover image
  final int? wpId;               // WordPress post ID for migrated content
  final String? wpLink;          // Original WP link
  final int likeCount;
  final int commentCount;
  final int reshareCount;
  final int viewCount;
  final bool isLiked;            // Local status for current user
  final bool isReshared;         // Local status for current user

  /// Short preview of the content for feeds and bookmarks.
  String get excerpt {
    if (content.length <= 150) return content;
    return '${content.substring(0, 147)}...';
  }

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
    this.tags = const [],
    this.imageUrl,
    this.wpId,
    this.wpLink,
    this.likeCount = 0,
    this.commentCount = 0,
    this.reshareCount = 0,
    this.viewCount = 0,
    this.isLiked = false,
    this.isReshared = false,
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
      tags: ((json['tags'] as List<dynamic>?) ?? []).cast<String>(),
      imageUrl: json['imageUrl'] as String?,
      wpId: json['wpId'] as int?,
      wpLink: json['wpLink'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      reshareCount: json['reshareCount'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        // [FIX] Always write userId so getUserSubmissions can always find this
        // document. Anonymous posts hide the authorName, not the userId field.
        'userId': userId,
        'authorName': isAnonymous ? 'Anonymous' : authorName,
        'title': title,
        'category': category.name,
        'content': content,
        'isAnonymous': isAnonymous,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'status': status.value,
        'tags': tags,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (wpId != null) 'wpId': wpId,
        if (wpLink != null) 'wpLink': wpLink,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'reshareCount': reshareCount,
        'viewCount': viewCount,
      };

  Map<String, dynamic> toMap() => toJson();

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
    List<String>? tags,
    String? imageUrl,
    int? wpId,
    String? wpLink,
    int? likeCount,
    int? commentCount,
    int? reshareCount,
    int? viewCount,
    bool? isLiked,
    bool? isReshared,
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
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      wpId: wpId ?? this.wpId,
      wpLink: wpLink ?? this.wpLink,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      reshareCount: reshareCount ?? this.reshareCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isReshared: isReshared ?? this.isReshared,
    );
  }
}
