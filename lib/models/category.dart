/// Represents a WordPress category.
class Category {
  final int id;
  final String name;
  final String slug;
  final int count;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The three known categories on the site.
class KnownCategories {
  static const all = Category(id: 0, name: 'All', slug: 'all', count: 0);
  static const poems = Category(id: 1, name: 'Poems', slug: 'poems', count: 0);
  static const prose = Category(id: 2, name: 'Prose', slug: 'prose', count: 0);
  static const anonymous = Category(id: 3, name: 'Anonymous', slug: 'anonymous', count: 0);
}
