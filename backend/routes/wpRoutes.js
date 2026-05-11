const express = require('express');
const axios = require('axios');
const Redis = require('ioredis');

const router = express.Router();

// Initialize Redis Client with fallback
let redis;
try {
  redis = new Redis(process.env.REDIS_URL, {
    maxRetriesPerRequest: 1,
    retryStrategy: () => null // Disable auto-retry if it fails once
  });
  redis.on('error', (err) => console.log('Redis error, continuing without cache:', err.message));
} catch (e) {
  console.log('Redis initialization failed, continuing without cache');
}

const CACHE_TTL = parseInt(process.env.CACHE_TTL_SECONDS) || 300;

function stripWordPressPost(wpPost) {
  return {
    id: wpPost.id,
    date: wpPost.date,
    title: { rendered: wpPost.title?.rendered },
    content: { rendered: wpPost.content?.rendered },
    excerpt: { rendered: wpPost.excerpt?.rendered },
    jetpack_featured_media_url: wpPost.jetpack_featured_media_url || null,
    categories: wpPost.categories,
    tags: wpPost.tags,
  };
}

router.get('/posts', async (req, res) => {
  const page = req.query.page || 1;
  const categories = req.query.categories || '';
  const cacheKey = `wp_posts_page_${page}_cat_${categories}`;

  try {
    // 1. Try Cache
    if (redis && redis.status === 'ready') {
      const cachedData = await redis.get(cacheKey);
      if (cachedData) {
        console.log(`[Redis] Cache Hit for ${cacheKey}`);
        return res.status(200).json(JSON.parse(cachedData));
      }
    }

    // 2. Fetch from WP
    console.log(`[WP] Cache Miss for ${cacheKey}. Fetching...`);
    const wpUrl = `${process.env.WP_BASE_URL}/posts`;
    const response = await axios.get(wpUrl, {
      params: { page, categories, _embed: 1 }
    });

    const strippedPosts = response.data.map(stripWordPressPost);

    // 3. Save to Cache
    if (redis && redis.status === 'ready') {
      await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(strippedPosts));
    }

    return res.status(200).json(strippedPosts);
  } catch (error) {
    console.error('Error:', error.message);
    if (error.response) return res.status(error.response.status).json(error.response.data);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

module.exports = router;
