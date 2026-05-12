import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/services/collections_service.dart';

/// Instagram-style bottom sheet — lets the user save a post to one or more
/// collections, create a new collection, or remove from existing ones.
///
/// Usage:
///   await SaveToCollectionSheet.show(context, uid: uid, post: post);
class SaveToCollectionSheet extends StatefulWidget {
  final String uid;
  final String id;
  final String title;
  final String excerpt;
  final String? imageUrl;
  final String author;
  final DateTime publishedAt;

  const SaveToCollectionSheet({
    super.key,
    required this.uid,
    required this.id,
    required this.title,
    required this.excerpt,
    this.imageUrl,
    required this.author,
    required this.publishedAt,
  });

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required String id,
    required String title,
    required String excerpt,
    String? imageUrl,
    required String author,
    required DateTime publishedAt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveToCollectionSheet(
        uid: uid,
        id: id,
        title: title,
        excerpt: excerpt,
        imageUrl: imageUrl,
        author: author,
        publishedAt: publishedAt,
      ),
    );
  }

  @override
  State<SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<SaveToCollectionSheet> {
  List<PostCollection> _collections = [];
  Set<String> _savedIn = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cols = await CollectionsService.instance.getCollections(widget.uid);
    final savedIn = await CollectionsService.instance
        .getCollectionIdsForPost(widget.uid, widget.id);
    if (mounted) setState(() { _collections = cols; _savedIn = savedIn; _loading = false; });
  }

  Future<void> _toggle(PostCollection col) async {
    final inCol = _savedIn.contains(col.id);
    setState(() {
      if (inCol) {
        _savedIn.remove(col.id);
      } else {
        _savedIn.add(col.id);
      }
    });
    if (inCol) {
      await CollectionsService.instance
          .removePostFromCollection(widget.uid, col.id, widget.id);
    } else {
      await CollectionsService.instance
          .addPostToCollection(
            widget.uid, 
            col.id, 
            postId: widget.id,
            title: widget.title,
            imageUrl: widget.imageUrl,
            author: widget.author,
            publishedAt: widget.publishedAt,
          );
    }
  }

  Future<void> _createNew() async {
    final name = await _showNameDialog();
    if (name == null || name.trim().isEmpty) return;
    final colId = await CollectionsService.instance
        .createCollection(widget.uid, name);
    await CollectionsService.instance
        .addPostToCollection(
          widget.uid, 
          colId, 
          postId: widget.id,
          title: widget.title,
          imageUrl: widget.imageUrl,
          author: widget.author,
          publishedAt: widget.publishedAt,
        );
    await _load();
  }

  Future<String?> _showNameDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('New Collection',
            style: GoogleFonts.ebGaramond(fontSize: 20, color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.literata(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Collection name…',
            hintStyle: GoogleFonts.literata(
                color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Create', style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Save to Collection',
                    style: GoogleFonts.ebGaramond(
                        fontSize: 20, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Theme.of(context).colorScheme.outline,
                  iconSize: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            // New collection button
            ListTile(
              leading: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text('New Collection',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: _createNew,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // Existing collections
            if (_collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No collections yet.\nCreate one above!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                      fontStyle: FontStyle.italic),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _collections.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76, endIndent: 16),
                  itemBuilder: (context, i) {
                    final col = _collections[i];
                    final saved = _savedIn.contains(col.id);
                    return ListTile(
                      leading: _CollectionThumb(url: col.coverImageUrl),
                      title: Text(col.name,
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${col.postCount} post${col.postCount == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Theme.of(context).colorScheme.outline),
                      ),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          saved ? Icons.check_circle : Icons.circle_outlined,
                          key: ValueKey(saved),
                          color: saved ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                          size: 24,
                        ),
                      ),
                      onTap: () => _toggle(col),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CollectionThumb extends StatelessWidget {
  final String? url;
  const _CollectionThumb({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        image: url != null
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url == null
          ? Icon(Icons.collections_bookmark_outlined,
              color: Theme.of(context).colorScheme.outline, size: 22)
          : null,
    );
  }
}