const express = require('express');
const { z } = require('zod');
const Preset = require('../models/Preset');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// ─── Zod schemas ─────────────────────────────────────────────────────────────

const PresetCreateSchema = z.object({
  name:               z.string().min(1),
  calories:           z.number().min(0),
  proteinGrams:       z.number().min(0),
  carbohydratesGrams: z.number().min(0),
  fatGrams:           z.number().min(0),
  amount:             z.number().min(0.1).default(1),
});

// ─── GET /api/v1/presets ─────────────────────────────────────────────────────

router.get('/', async (req, res, next) => {
  try {
    const userId = req.userId;
    const presets = await Preset.find({ userId }).sort({ createdAt: -1 });
    res.json(presets);
  } catch (err) {
    next(err);
  }
});

// ─── POST /api/v1/presets ────────────────────────────────────────────────────

router.post('/', async (req, res, next) => {
  try {
    const userId = req.userId;
    const body = PresetCreateSchema.parse(req.body);

    const preset = new Preset({
      userId,
      ...body,
    });

    await preset.save();
    res.status(201).json(preset);
  } catch (err) {
    next(err);
  }
});

// ─── DELETE /api/v1/presets/:id ──────────────────────────────────────────────

router.delete('/:id', async (req, res, next) => {
  try {
    const userId = req.userId;
    const preset = await Preset.findOneAndDelete({ _id: req.params.id, userId });

    if (!preset) {
      return res.status(404).json({ error: { code: 'ERR_PRESET_NOT_FOUND', message: 'Preset not found.' } });
    }

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
