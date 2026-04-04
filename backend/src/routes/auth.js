const express = require('express');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const User = require('../models/User');

const router = express.Router();

const AuthSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

// ─── POST /api/v1/auth/signup ────────────────────────────────────────────────

router.post('/signup', async (req, res, next) => {
  try {
    const { email, password } = AuthSchema.parse(req.body);

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: { code: 'ERR_USER_EXISTS', message: 'User already exists.' } });
    }

    const user = await User.create({ email, password });

    const token = jwt.sign({ userId: user._id.toString() }, process.env.JWT_SECRET || 'dev-secret', { expiresIn: '7d' });

    res.status(201).json({ token, user: { id: user._id, email: user.email } });
  } catch (err) {
    next(err);
  }
});

// ─── POST /api/v1/auth/login ─────────────────────────────────────────────────

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = AuthSchema.parse(req.body);

    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ error: { code: 'ERR_INVALID_CREDENTIALS', message: 'Invalid email or password.' } });
    }

    const token = jwt.sign({ userId: user._id.toString() }, process.env.JWT_SECRET || 'dev-secret', { expiresIn: '7d' });

    res.json({ token, user: { id: user._id, email: user.email } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
