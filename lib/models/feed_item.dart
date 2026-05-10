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
    return FeedItem(
      uniqueId: 'wp_${post.id}',
      authorFirebaseId: '', // WP author IDs are integers — not Firebase UIDs
      authorName: post.author,
      title: post.cleanTitle,
      excerpt: post.cleanExcerpt,
      imageUrl: post.imageUrl.isEmpty ? null : post.imageUrl,
      publishedAt: post.publishedAt,
      isSubmission: false,
      categoryLabel: categoryLabel,
      wpPost: post,
    );
  }

  factory FeedItem.fromSubmission(Submission s) {
    final raw = s.content;
    final excerpt = raw.length > 220 ? '${raw.substring(0, 220)}…' : raw;
    return FeedItem(
      uniqueId: s.wpId != null ? 'wp_${s.wpId}' : 'sub_${s.id}',
      authorFirebaseId: s.userId ?? '',
      authorName: s.isAnonymous ? 'Anonymous' : s.authorName,
      title: s.title,
      excerpt: excerpt,
      imageUrl: s.imageUrl,
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
}
