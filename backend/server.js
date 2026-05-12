require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const wpRoutes = require('./routes/wpRoutes');
const searchService = require('./searchService');

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Search Engine
searchService.initialize();

// Security
app.use(helmet());

// Compression
app.use(compression());

// Rate Limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', apiLimiter);

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/wp', wpRoutes);

app.get('/api/search', (req, res) => {
  const query = req.query.q;
  if (!query) return res.status(400).json({ error: 'Query parameter "q" is required' });
  
  const results = searchService.search(query);
  res.json(results);
});

app.get('/health', (req, res) => res.status(200).send('OK'));

// Export for Vercel
module.exports = app;

// Only listen if running directly (not as a serverless function)
if (process.env.NODE_ENV !== 'production' || !process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`🚀 BFF Server running on port ${PORT}`);
  });
}
