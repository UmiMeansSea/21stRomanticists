import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/services/collections_service.dart';

/// Shows all posts saved to a specific collection.
class CollectionDetailScreen extends StatefulWidget {
  final String uid;
  final String collectionId;
  final String collectionName;

  const CollectionDetailScreen({
    super.key,
    required this.uid,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await CollectionsService.instance
        .getPostsInCollection(widget.uid, widget.collectionId);
    if (mounted) setState(() { _posts = posts; _loading = false; });
  }

  Future<void> _removePost(Map<String, dynamic> post) async {
    final postId = post['postId'] as int?;
    if (postId == null) return;
    await CollectionsService.instance.removePostFromCollection(
        widget.uid, widget.collectionId, postId);
    setState(() => _posts.remove(post));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          widget.collectionName,
          style: GoogleFonts.ebGaramond(
              fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.primary),
        ),
        centerTitle: true,
        actions: [
          if (_posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_posts.length} saved',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.collections_bookmark_outlined,
                          size: 56,
                          color: AppColors.outline.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('This collection is empty',
                          style: GoogleFonts.ebGaramond(
                              fontSize: 20, color: AppColors.onSurface)),
                      const SizedBox(height: 8),
                      Text('Save posts from the feed to add them here.',
                          style: GoogleFonts.literata(
                              fontSize: 13,
                              color: AppColors.outline,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) =>
                        _CollectionPostTile(
                      data: _posts[i],
                      onRemove: () => _removePost(_posts[i]),
                    ),
                  ),
                ),
    );
  }
}

class _CollectionPostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRemove;
  const _CollectionPostTile({required this.data, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Untitled';
    final author = data['author'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final postId = data['postId'] as int?;

    return Dismissible(
      key: ValueKey(data['postId']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onRemove(),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        title: Text(
          title,
          style: GoogleFonts.ebGaramond(
              fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          author,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
        onTap: () {
          if (postId != null) context.push('/post/$postId');
        },
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 60, height: 60,
        color: AppColors.surfaceContainerHigh,
        child: const Icon(Icons.auto_stories_outlined,
            color: AppColors.outline, size: 24),
      );
}
