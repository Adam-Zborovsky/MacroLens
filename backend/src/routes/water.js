const express = require('express');
const router = express.Router();
const WaterLog = require('../models/WaterLog');
const { verifyToken } = require('../middleware/auth');

// @route   GET /api/v1/water
// @desc    Get all water logs for the current user for today
// @access  Private
router.get('/', verifyToken, async (req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const logs = await WaterLog.find({
      userId: req.userId,
      loggedAt: { $gte: startOfDay, $lte: endOfDay },
    }).sort({ loggedAt: -1 });

    res.json(logs);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// @route   POST /api/v1/water
// @desc    Add a water log
// @access  Private
router.post('/', verifyToken, async (req, res) => {
  const { amountMl, loggedAt } = req.body;

  try {
    const newLog = new WaterLog({
      userId: req.userId,
      amountMl,
      loggedAt: loggedAt || Date.now(),
    });

    const log = await newLog.save();
    res.json(log);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// @route   DELETE /api/v1/water/:id
// @desc    Delete a water log
// @access  Private
router.delete('/:id', verifyToken, async (req, res) => {
  try {
    const log = await WaterLog.findById(req.params.id);

    if (!log) {
      return res.status(404).json({ msg: 'Log not found' });
    }

    // Check user
    if (log.userId.toString() !== req.userId) {
      return res.status(401).json({ msg: 'User not authorized' });
    }

    await log.deleteOne();

    res.json({ msg: 'Log removed' });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ msg: 'Log not found' });
    }
    res.status(500).send('Server Error');
  }
});

module.exports = router;
