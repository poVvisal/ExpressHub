const express = require('express');
const cors = require('cors');
const app = express();
const port = 3000;

// --- Security Enhancements ---

// 1. Disable the X-Powered-By header to prevent technology fingerprinting
app.disable('x-powered-by');

// 2. Configure CORS to only allow requests from a specific whitelist of origins
const whitelist = [
    'http://localhost:8080', // Your local frontend development server
    'http://your-frontend-domain.com', // Your production frontend domain
    'http://another-trusted-domain.com'
];

const corsOptions = {
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin) return callback(null, true);
        
        if (whitelist.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    }
};

// Enable CORS with the secure options
app.use(cors(corsOptions));

// --- End of Security Enhancements ---

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('frontend')); // Serve static files from the 'frontend' directory

// API Routes
const menuRoutes = require('./backend/routes/menu');
const orderRoutes = require('./backend/routes/orders');
const restaurantRoutes = require('./backend/routes/restaurants');

app.use('/api/menu', menuRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/restaurants', restaurantRoutes);

// Root endpoint
app.get('/', (req, res) => {
    res.sendFile(__dirname + '/frontend/index.html');
});

// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});