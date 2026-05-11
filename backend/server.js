require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const wpRoutes = require('./routes/wpRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

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

app.get('/health', (req, res) => res.status(200).send('OK'));

app.listen(PORT, () => {
  console.log(`🚀 BFF Server running on port ${PORT}`);
});
