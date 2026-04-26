const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');

const app = express();

// Disable the X-Powered-By header to prevent fingerprinting
app.disable('x-powered-by');

// Use Helmet to set various security headers
app.use(helmet());

// Configure CORS to only allow requests from specific origins
const allowedOrigins = [
  'http://localhost:3000',
  // Add your production frontend URL here
  // 'https://your-frontend-domain.com', 
];

const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) === -1) {
      const msg = 'The CORS policy for this site does not allow access from the specified Origin.';
      return callback(new Error(msg), false);
    }
    return callback(null, true);
  },
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'frontend')));

// ── Status endpoints (updated originals) ─────────────────────────────────────
app.get('/api/status', (req, res) => {
  res.json({
    message: 'Hello! Welcome to FoodExpress — your hunger ends here!',
    status: 'online',
    method: 'GET',
  });
});

app.post('/api/status', (req, res) => {
  res.json({
    message: 'FoodExpress received your POST! The order pipeline is open and ready.',
    status: 'received',
    method: 'POST',
  });
});

app.put('/api/status', (req, res) => {
  res.json({
    message: 'FoodExpress updated! Your delivery details have been refreshed.',
    status: 'updated',
    method: 'PUT',
  });
});

// ── Feature routes ────────────────────────────────────────────────────────────
const menuRoutes = require('./backend/routes/menu');
const orderRoutes = require('./backend/routes/orders');
const restaurantRoutes = require('./backend/routes/restaurants');

app.use('/api/menu', menuRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/restaurants', restaurantRoutes);

// ── Fallback: serve frontend for any unmatched non-API route ─────────────────
app.get('/{*path}', (req, res) => {
  res.sendFile(path.join(__dirname, 'frontend', 'index.html'));
});

app.listen(5000, () => {
  console.log('FoodExpress server is running on http://localhost:5000');
});