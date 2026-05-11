import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/submission.dart';

/// Unified feed item that wraps either a WordPress [Post] or a Firestore
/// community [Submission]. The home screen works exclusively with [FeedItem].
class FeedItem {
  final String uniqueId;
  /// Firebase UID for submissions; empty string for WP posts (WP uses int IDs
  /// that never match Firebase UIDs, so they're never "followed").
  final String authorFirebaseId;
  final String authorName;
  final String title;
  final String excerpt;
  final String? imageUrl;
  final DateTime publishedAt;
  final bool isSubmission;
  final String categoryLabel;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int reshareCount;
  final int viewCount;
  final bool isLiked;
  final bool isReshared;

  // Originals for navigation / detail screens
  final Post? wpPost;
  final Submission? submission;

  const FeedItem({
    required this.uniqueId,
    required this.authorFirebaseId,
    required this.authorName,
    required this.title,
    required this.excerpt,
    this.imageUrl,
    required this.publishedAt,
    required this.isSubmission,
    this.categoryLabel = '',
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.reshareCount = 0,
    this.viewCount = 0,
    this.isLiked = false,
    this.isReshared = false,
    this.wpPost,
    this.submission,
  });

  factory FeedItem.fromPost(Post post, {String categoryLabel = ''}) {
    final title = _sanitize(post.cleanTitle);
    final excerpt = _sanitize(post.cleanExcerpt);
    
    final imageUrl = _sanitizeUrl(post.imageUrl);
    
    return FeedItem(
      uniqueId: 'wp_${post.id}',
      authorFirebaseId: '', // WP author IDs are integers — not Firebase UIDs
      authorName: post.author,
      title: title,
      excerpt: excerpt,
      imageUrl: imageUrl,
      publishedAt: post.publishedAt,
      isSubmission: false,
      categoryLabel: categoryLabel,
      tags: post.tagNames,
      wpPost: post,
    );
  }

  factory FeedItem.fromSubmission(Submission s) {
    final raw = s.content;
    final excerpt = _sanitize(raw.length > 220 ? '${raw.substring(0, 220)}…' : raw);
    final title = _sanitize(s.title);
    final imageUrl = _sanitizeUrl(s.imageUrl);

    return FeedItem(
      uniqueId: s.wpId != null ? 'wp_${s.wpId}' : 'sub_${s.id}',
      authorFirebaseId: s.userId ?? '',
      authorName: s.isAnonymous ? 'Anonymous' : s.authorName,
      title: title,
      excerpt: excerpt,
      imageUrl: imageUrl,
      publishedAt: s.submittedAt,
      isSubmission: true,
      categoryLabel: s.category.label,
      tags: s.tags,
      likeCount: s.likeCount,
      commentCount: s.commentCount,
      reshareCount: s.reshareCount,
      viewCount: s.viewCount,
      isLiked: s.isLiked,
      isReshared: s.isReshared,
      submission: s,
    );
  }

  Map<String, dynamic> toJson() => {
    'uniqueId': uniqueId,
    'authorFirebaseId': authorFirebaseId,
    'authorName': authorName,
    'title': title,
    'excerpt': excerpt,
    'imageUrl': imageUrl,
    'publishedAt': publishedAt.toIso8601String(),
    'isSubmission': isSubmission,
    'categoryLabel': categoryLabel,
    'tags': tags,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'reshareCount': reshareCount,
    'viewCount': viewCount,
    'isLiked': isLiked,
    'isReshared': isReshared,
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      uniqueId: json['uniqueId'] as String? ?? '',
      authorFirebaseId: json['authorFirebaseId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ?? DateTime.now(),
      isSubmission: json['isSubmission'] as bool? ?? false,
      categoryLabel: json['categoryLabel'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      reshareCount: json['reshareCount'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      isReshared: json['isReshared'] as bool? ?? false,
    );
  }

  static String _sanitize(String text) {
    final lower = text.trim().toLowerCase();
    if (lower == 'no pic' || lower == 'no_pic') return '';
    return text;
  }

  static String? _sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final lower = url.trim().toLowerCase();
    if (lower == 'no pic' || lower == 'no_pic') return null;
    return url;
  }
}
