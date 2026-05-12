const MiniSearch = require('minisearch');
const admin = require('firebase-admin');
const axios = require('axios');

class SearchService {
  constructor() {
    this.miniSearch = new MiniSearch({
      fields: ['title', 'content', 'username', 'tags', 'displayName'], // fields to index for full-text search
      storeFields: ['id', 'type', 'title', 'username', 'displayName', 'photoUrl', 'excerpt', 'jetpack_featured_media_url', 'tags'], // fields to return with search results
      searchOptions: {
        boost: { title: 2, username: 2, displayName: 2 },
        fuzzy: 0.2,
        prefix: true
      }
    });

    this.isInitialized = false;
    this.syncInterval = 10 * 60 * 1000; // 10 minutes
  }

  async initialize() {
    if (this.isInitialized) return;

    // Initialize Firebase Admin if not already initialized
    if (admin.apps.length === 0) {
      try {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
      } catch (error) {
        console.error('Failed to initialize Firebase Admin in SearchService:', error.message);
        return;
      }
    }

    await this.syncIndex();
    
    // Set up periodic sync
    setInterval(() => this.syncIndex(), this.syncInterval);
    
    this.isInitialized = true;
    console.log('🚀 SearchService initialized and indexed.');
  }

  async syncIndex() {
    try {
      console.log('[SearchService] Syncing index...');
      const db = admin.firestore();
      
      // 1. Fetch Users
      const usersSnap = await db.collection('users').get();
      const users = usersSnap.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          type: 'user',
          username: data.username || '',
          displayName: data.displayName || '',
          photoUrl: data.photoUrl || '',
          content: data.bio || '', // Use bio as content for search
        };
      });

      // 2. Fetch Submissions (Approved)
      const subSnap = await db.collection('submissions').where('status', '==', 'approved').get();
      const submissions = subSnap.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          type: 'post',
          title: data.title || '',
          content: data.content || '',
          username: data.authorName || 'Anonymous',
          tags: (data.tags || []).join(' '),
          excerpt: data.excerpt || '',
          jetpack_featured_media_url: data.coverUrl || null,
        };
      });

      // 3. Fetch WordPress Posts (First 100 for indexing)
      let wpPosts = [];
      try {
        const wpUrl = `${process.env.WP_BASE_URL}/posts?per_page=100`;
        const wpRes = await axios.get(wpUrl);
        wpPosts = wpRes.data.map(post => ({
          id: `wp_${post.id}`,
          type: 'post',
          title: post.title?.rendered || '',
          content: post.content?.rendered || '',
          excerpt: post.excerpt?.rendered || '',
          username: 'WordPress Author',
          tags: (post.tags || []).join(' '), // Simplified tags for indexing
          jetpack_featured_media_url: post.jetpack_featured_media_url || null,
        }));
      } catch (err) {
        console.error('WP index sync failed:', err.message);
      }

      // Merge and Index
      const allDocs = [...users, ...submissions, ...wpPosts];
      this.miniSearch.removeAll();
      this.miniSearch.addAll(allDocs);
      
      console.log(`[SearchService] Index updated: ${allDocs.length} items.`);
    } catch (error) {
      console.error('Sync error:', error);
    }
  }

  search(query) {
    if (!query || query.length < 2) return { users: [], posts: [], tags: [] };
    
    const results = this.miniSearch.search(query);
    
    const users = [];
    const posts = [];
    const tagsSet = new Set();

    results.forEach(res => {
      if (res.type === 'user') {
        users.push(res);
      } else {
        posts.push(res);
        if (res.tags) {
          res.tags.split(' ').forEach(t => {
            if (t.toLowerCase().includes(query.toLowerCase())) tagsSet.add(t);
          });
        }
      }
    });

    return {
      users: users.slice(0, 10),
      posts: posts.slice(0, 20),
      tags: Array.from(tagsSet).slice(0, 10)
    };
  }
}

module.exports = new SearchService();
