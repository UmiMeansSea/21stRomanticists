import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:romanticists_app/providers/search_provider.dart';
import 'package:romanticists_app/widgets/post_card.dart';
import 'package:romanticists_app/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Container(
          height: 45,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: search.onSearchChanged,
            style: GoogleFonts.literata(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search poets, prose, tags...',
              hintStyle: GoogleFonts.literata(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 15,
                fontStyle: FontStyle.italic
              ),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      search.onSearchChanged('');
                    },
                  )
                : null,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'TOP'),
            Tab(text: 'ACCOUNTS'),
            Tab(text: 'TAGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TopResults(search: search),
          _AccountResults(search: search),
          _TagResults(search: search),
        ],
      ),
    );
  }
}

class _TopResults extends StatelessWidget {
  final SearchProvider search;
  const _TopResults({required this.search});

  @override
  Widget build(BuildContext context) {
    if (search.isLoading) return const _SearchSkeleton();
    
    if (search.postResults.isEmpty && search.userResults.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: search.postResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FeedCard(item: search.postResults[index]),
        );
      },
    );
  }
}

class _AccountResults extends StatelessWidget {
  final SearchProvider search;
  const _AccountResults({required this.search});

  @override
  Widget build(BuildContext context) {
    if (search.isLoading) return const _SearchSkeleton();
    if (search.userResults.isEmpty) return _EmptyState();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: search.userResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = search.userResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null 
              ? Text(user.displayName[0].toUpperCase(), 
                  style: GoogleFonts.ebGaramond(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
              : null,
          ),
          title: Text(user.displayName, style: GoogleFonts.ebGaramond(fontSize: 17, fontWeight: FontWeight.w600)),
          subtitle: Text('@${user.username}', style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/user/${user.id}?name=${user.displayName}'),
        );
      },
    );
  }
}

class _TagResults extends StatelessWidget {
  final SearchProvider search;
  const _TagResults({required this.search});

  @override
  Widget build(BuildContext context) {
    if (search.isLoading) return const _SearchSkeleton();
    if (search.tagResults.isEmpty) return _EmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: search.tagResults.length,
      itemBuilder: (context, index) {
        final tag = search.tagResults[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tag, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text('#$tag', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
          onTap: () => context.push('/tag/$tag'),
        );
      },
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: PostCardSkeleton(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: GoogleFonts.ebGaramond(fontSize: 20, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
