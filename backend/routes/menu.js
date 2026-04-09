const express = require('express');
const router = express.Router();

const menuItems = [
  { id: 1, name: 'Margherita Pizza', price: 12.99, category: 'Pizza' },
  { id: 2, name: 'Double Cheeseburger', price: 9.99, category: 'Burger' },
  { id: 3, name: 'Spicy Chicken Wings', price: 7.99, category: 'Sides' },
  { id: 4, name: 'Caesar Salad', price: 6.49, category: 'Salads' },
  { id: 5, name: 'Chocolate Lava Cake', price: 4.99, category: 'Desserts' },
];

router.get('/', (req, res) => {
  res.json({
    message: "Here's today's FoodExpress menu — dig in!",
    count: menuItems.length,
    items: menuItems,
  });
});

router.post('/', (req, res) => {
  const { name, price, category } = req.body;
  if (!name || price === undefined || !category) {
    return res.status(400).json({ message: 'Please provide name, price, and category for the new menu item.' });
  }
  const newItem = { id: menuItems.length + 1, name, price: parseFloat(price), category };
  menuItems.push(newItem);
  res.status(201).json({
    message: `"${name}" has been added to the FoodExpress menu. Yum!`,
    item: newItem,
  });
});

module.exports = router;
