/// Represents a WordPress post returned by the REST API.
class Post {
  final int id;
  final int authorId;
  final String title;
  final String content;
  final String excerpt;
  final String author;
  final String imageUrl;
  final DateTime publishedAt;
  final List<int> categories;
  final List<String> tagNames;
  final String slug;
  final String link;

  const Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.author,
    required this.imageUrl,
    required this.publishedAt,
    required this.categories,
    required this.tagNames,
    required this.slug,
    required this.link,
  });

  /// Safely strips HTML tags from a string for plain-text preview.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .trim();
  }

  /// Clean excerpt for display (no HTML tags).
  String get cleanExcerpt => _stripHtml(excerpt);

  /// Clean title for display.
  String get cleanTitle => _stripHtml(title);

  factory Post.fromJson(Map<String, dynamic> json) {
    // Safely extract author from _embedded
    String authorName = 'Anonymous';
    try {
      final embedded = json['_embedded'] as Map<String, dynamic>?;
      final authorList = embedded?['author'] as List<dynamic>?;
      if (authorList != null && authorList.isNotEmpty) {
        authorName = (authorList[0] as Map<String, dynamic>)['name'] as String? ?? 'Anonymous';
      }
    } catch (_) {}

    // Safely extract featured image URL
    String featuredImage = '';
    try {
      final embedded = json['_embedded'] as Map<String, dynamic>?;
      final mediaList = embedded?['wp:featuredmedia'] as List<dynamic>?;
      if (mediaList != null && mediaList.isNotEmpty) {
        featuredImage = (mediaList[0] as Map<String, dynamic>)['source_url'] as String? ?? '';
      }
    } catch (_) {}

    // Safely extract tags from _embedded
    List<String> tags = [];
    try {
      final embedded = json['_embedded'] as Map<String, dynamic>?;
      final termList = embedded?['wp:term'] as List<dynamic>?;
      if (termList != null && termList.length > 1) {
        final wpTags = termList[1] as List<dynamic>;
        tags = wpTags.map((t) => (t as Map<String, dynamic>)['name'] as String).toList();
      }
    } catch (_) {}

    return Post(
      id: json['id'] as int,
      authorId: json['author'] as int? ?? 0,
      title: (json['title'] as Map<String, dynamic>)['rendered'] as String? ?? '',
      content: (json['content'] as Map<String, dynamic>)['rendered'] as String? ?? '',
      excerpt: (json['excerpt'] as Map<String, dynamic>)['rendered'] as String? ?? '',
      author: authorName,
      imageUrl: featuredImage,
      publishedAt: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      categories: ((json['categories'] as List<dynamic>?) ?? []).cast<int>(),
      tagNames: tags,
      slug: json['slug'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'title': {'rendered': title},
        'content': {'rendered': content},
        'excerpt': {'rendered': excerpt},
        'author': author,
        'imageUrl': imageUrl,
        'date': publishedAt.toIso8601String(),
        'categories': categories,
        'tagNames': tagNames,
        'slug': slug,
        'link': link,
      };

  Post copyWith({
    int? id,
    int? authorId,
    String? title,
    String? content,
    String? excerpt,
    String? author,
    String? imageUrl,
    DateTime? publishedAt,
    List<int>? categories,
    List<String>? tagNames,
    String? slug,
    String? link,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      content: content ?? this.content,
      excerpt: excerpt ?? this.excerpt,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      categories: categories ?? this.categories,
      tagNames: tagNames ?? this.tagNames,
      slug: slug ?? this.slug,
      link: link ?? this.link,
    );
  }

  @override
  bool operator ==(Object other) => other is Post && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
