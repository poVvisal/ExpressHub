const express = require('express');
const router = express.Router();

const restaurants = [
  { id: 1, name: "Mario's Kitchen", cuisine: 'Italian', rating: 4.8, deliveryTime: '25-35 min' },
  { id: 2, name: 'Burger Palace', cuisine: 'American', rating: 4.5, deliveryTime: '20-30 min' },
  { id: 3, name: 'Dragon Wok', cuisine: 'Chinese', rating: 4.7, deliveryTime: '30-40 min' },
];

router.get('/', (req, res) => {
  res.json({
    message: 'Discover FoodExpress partner restaurants near you!',
    count: restaurants.length,
    restaurants,
  });
});

router.post('/', (req, res) => {
  const { name, cuisine, rating, deliveryTime } = req.body;
  if (!name || !cuisine) {
    return res.status(400).json({ message: 'Please provide restaurant name and cuisine type.' });
  }
  const restaurant = {
    id: restaurants.length + 1,
    name,
    cuisine,
    rating: rating ? parseFloat(rating) : null,
    deliveryTime: deliveryTime || 'TBD',
  };
  restaurants.push(restaurant);
  res.status(201).json({
    message: `"${name}" is now a FoodExpress partner restaurant. Welcome aboard!`,
    restaurant,
  });
});

module.exports = router;
