const express = require('express');
const { z } = require('zod');
const Meal = require('../models/Meal');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// ─── Zod schemas ─────────────────────────────────────────────────────────────

const ItemCorrectionSchema = z.object({
  itemId:        z.string(),
  name:          z.string().optional(),
  massGrams:     z.number().min(0).optional(),
  verificationStatus: z.string().optional(),
});

const MealPatchSchema = z.object({
  detectedItems: z.array(ItemCorrectionSchema).optional(),
  nutritionDataVerified: z.boolean().optional(),
});

// ─── GET /api/v1/meals ───────────────────────────────────────────────────────

router.get('/', async (req, res, next) => {
  try {
    const userId = req.userId;
    const meals = await Meal.find({ userId }).sort({ loggedAt: -1 });
    res.json(meals);
  } catch (err) {
    next(err);
  }
});

// ─── PATCH /api/v1/meals/:id ─────────────────────────────────────────────────

router.patch('/:id', async (req, res, next) => {
  try {
    const userId = req.userId;
    const body = MealPatchSchema.parse(req.body);
    const meal = await Meal.findOne({ _id: req.params.id, userId });
    
    if (!meal) {
      return res.status(404).json({ error: { code: 'ERR_MEAL_NOT_FOUND', message: 'Meal not found.' } });
    }

    if (body.detectedItems) {
      for (const correction of body.detectedItems) {
        const item = meal.detectedItems.find(i => i.itemId === correction.itemId);
        if (item) {
          if (correction.name) item.name = correction.name;
          if (correction.massGrams !== undefined) item.massGrams = correction.massGrams;
          if (correction.verificationStatus) item.verificationStatus = correction.verificationStatus;
        }
      }
    }

    if (body.nutritionDataVerified !== undefined) {
      meal.nutritionDataVerified = body.nutritionDataVerified;
    }

    await meal.save();
    res.json(meal);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
