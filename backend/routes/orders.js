const express = require('express');
const router = express.Router();

const orders = [];
let nextId = 1;

router.get('/', (req, res) => {
  res.json({
    message: orders.length
      ? 'FoodExpress active orders retrieved!'
      : 'No orders yet — the kitchen is waiting!',
    count: orders.length,
    orders,
  });
});

router.post('/', (req, res) => {
  const { item, quantity, address } = req.body;
  if (!item || !quantity || !address) {
    return res.status(400).json({ message: 'Please provide item, quantity, and delivery address.' });
  }
  const order = {
    id: nextId++,
    item,
    quantity: parseInt(quantity),
    address,
    status: 'Preparing',
    placedAt: new Date().toISOString(),
  };
  orders.push(order);
  res.status(201).json({
    message: `Order #${order.id} placed! Your food is being prepared. Hold tight!`,
    order,
  });
});

router.get('/:id', (req, res) => {
  const order = orders.find(o => o.id === parseInt(req.params.id));
  if (!order) {
    return res.status(404).json({ message: `Order #${req.params.id} not found. Did it fly away?` });
  }
  res.json({ message: `Order #${order.id} found! Here are the details.`, order });
});

router.put('/:id', (req, res) => {
  const order = orders.find(o => o.id === parseInt(req.params.id));
  if (!order) {
    return res.status(404).json({ message: `Order #${req.params.id} not found. Nothing to update.` });
  }
  const { status } = req.body;
  if (!status) {
    return res.status(400).json({ message: 'Please provide a new status for the order.' });
  }
  order.status = status;
  res.json({
    message: `Order #${order.id} updated to "${order.status}". Your delivery is on its way!`,
    order,
  });
});

router.delete('/:id', (req, res) => {
  const index = orders.findIndex(o => o.id === parseInt(req.params.id));
  if (index === -1) {
    return res.status(404).json({ message: `Order #${req.params.id} not found. Nothing to cancel.` });
  }
  const [cancelled] = orders.splice(index, 1);
  res.json({
    message: `Order #${cancelled.id} has been cancelled. We're sorry to see it go!`,
    order: cancelled,
  });
});

module.exports = router;
