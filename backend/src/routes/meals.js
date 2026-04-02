const express = require('express');
const { z } = require('zod');
const Meal = require('../models/Meal');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');

const router = express.Router();

// All meal routes require authentication
router.use(verifyFirebaseToken);

// ─── Zod schemas ─────────────────────────────────────────────────────────────

const ItemCorrectionSchema = z.object({
  itemId:        z.string(),
  name:          z.string().optional(),
  usdaSearchTerm: z.string().optional(),
  usdaFoodId:    z.string().optional(),
  // User-adjusted mass from the NotchedHapticSlider (5g increments)
  userAdjustedMassGrams: z.number().min(0).optional(),
  verificationStatus: z
    .enum(['user_confirmed', 'user_corrected', 'custom_entry'])
    .optional(),
  // Custom nutrition override (last-resort manual entry)
  customNutritionPer100g: z
    .object({
      calories:           z.number().min(0),
      proteinGrams:       z.number().min(0),
      carbohydratesGrams: z.number().min(0),
      fatGrams:           z.number().min(0),
      fiberGrams:         z.number().min(0).optional(),
    })
    .optional(),
});

const CaseFilePatchSchema = z.object({
  mealType: z.enum(['breakfast', 'lunch', 'dinner', 'snack', 'unknown']).optional(),
  notes:    z.string().max(1000).optional(),
  itemCorrections: z.array(ItemCorrectionSchema).optional(),
});

// ─── GET /api/v1/meals/case-files ────────────────────────────────────────────
// Dashboard: aggregated daily totals + Case File list

router.get('/case-files', async (req, res, next) => {
  try {
    const userId = req.userId;
    const { date, q, limit = 20, page = 1 } = req.query;

    const query = { userId };

    if (date) {
      const start = new Date(date);
      start.setHours(0, 0, 0, 0);
      const end = new Date(date);
      end.setHours(23, 59, 59, 999);
      query.loggedAt = { $gte: start, $lte: end };
    }

    if (q) {
      query.$text = { $search: q };
    }

    const skip = (Number(page) - 1) * Number(limit);

    const [caseFiles, total] = await Promise.all([
      Meal.find(query).sort({ loggedAt: -1 }).skip(skip).limit(Number(limit)).lean(),
      Meal.countDocuments(query),
    ]);

    res.json({ caseFiles, pagination: { total, page: Number(page), limit: Number(limit) } });
  } catch (err) {
    next(err);
  }
});

// ─── GET /api/v1/meals/case-files/daily-totals ───────────────────────────────
// Single endpoint for Dashboard progress rings

router.get('/case-files/daily-totals', async (req, res, next) => {
  try {
    const userId = req.userId;

    const date = req.query.date ? new Date(req.query.date) : new Date();
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setHours(23, 59, 59, 999);

    const result = await Meal.aggregate([
      { $match: { userId, loggedAt: { $gte: start, $lte: end }, deletedAt: null } },
      {
        $group: {
          _id: null,
          totalCalories:           { $sum: '$mealTotals.calories' },
          totalProteinGrams:       { $sum: '$mealTotals.proteinGrams' },
          totalCarbohydratesGrams: { $sum: '$mealTotals.carbohydratesGrams' },
          totalFatGrams:           { $sum: '$mealTotals.fatGrams' },
          totalFiberGrams:         { $sum: '$mealTotals.fiberGrams' },
          mealCount:               { $sum: 1 },
        },
      },
    ]);

    const totals = result[0] ?? {
      totalCalories: 0, totalProteinGrams: 0, totalCarbohydratesGrams: 0,
      totalFatGrams: 0, totalFiberGrams: 0, mealCount: 0,
    };

    res.json({ date: date.toISOString().split('T')[0], ...totals });
  } catch (err) {
    next(err);
  }
});

// ─── GET /api/v1/meals/case-files/:id ────────────────────────────────────────

router.get('/case-files/:id', async (req, res, next) => {
  try {
    const meal = await Meal.findOne({ _id: req.params.id });
    if (!meal) {
      return res.status(404).json({ error: { code: 'ERR_CASE_FILE_NOT_FOUND', message: 'Case File not found.' } });
    }
    res.json(meal);
  } catch (err) {
    next(err);
  }
});

// ─── PATCH /api/v1/meals/case-files/:id ──────────────────────────────────────
// Detective UI corrections — item swaps, mass adjustments, custom values

router.patch('/case-files/:id', async (req, res, next) => {
  try {
    const body = CaseFilePatchSchema.parse(req.body);
    const meal = await Meal.findById(req.params.id);
    if (!meal) {
      return res.status(404).json({ error: { code: 'ERR_CASE_FILE_NOT_FOUND', message: 'Case File not found.' } });
    }

    if (body.mealType) meal.mealType = body.mealType;
    if (body.notes !== undefined) meal.notes = body.notes;

    // Apply item-level corrections from Detective UI
    if (body.itemCorrections?.length) {
      for (const correction of body.itemCorrections) {
        const item = meal.detectedItems.find((i) => i.itemId === correction.itemId);
        if (!item) continue;

        if (correction.name)           item.name = correction.name;
        if (correction.usdaSearchTerm) item.usdaSearchTerm = correction.usdaSearchTerm;
        if (correction.usdaFoodId)     item.usdaFoodId = correction.usdaFoodId;
        if (correction.userAdjustedMassGrams != null) {
          item.userAdjustedMassGrams = correction.userAdjustedMassGrams;
        }
        if (correction.verificationStatus) {
          item.verificationStatus = correction.verificationStatus;
        }

        // Custom nutrition override — recalculate totals based on effective mass
        if (correction.customNutritionPer100g) {
          const n = correction.customNutritionPer100g;
          const effectiveMass = correction.userAdjustedMassGrams ?? item.massGrams;
          const multiplier = effectiveMass / 100;

          item.nutritionPer100g = {
            calories:           n.calories,
            proteinGrams:       n.proteinGrams,
            carbohydratesGrams: n.carbohydratesGrams,
            fatGrams:           n.fatGrams,
            fiberGrams:         n.fiberGrams ?? 0,
          };
          item.nutritionTotal = {
            calories:           +(n.calories * multiplier).toFixed(1),
            proteinGrams:       +(n.proteinGrams * multiplier).toFixed(1),
            carbohydratesGrams: +(n.carbohydratesGrams * multiplier).toFixed(1),
            fatGrams:           +(n.fatGrams * multiplier).toFixed(1),
            fiberGrams:         +((n.fiberGrams ?? 0) * multiplier).toFixed(1),
          };
          item.verificationStatus = 'custom_entry';
        }
      }

      // Recompute meal totals
      meal.mealTotals = Meal.computeTotals(meal.detectedItems);
    }

    meal.nutritionDataVerified = meal.detectedItems.every(
      (i) => i.usdaFoodId || i.verificationStatus === 'custom_entry'
    );

    await meal.save();
    res.json(meal);
  } catch (err) {
    next(err);
  }
});

// ─── DELETE /api/v1/meals/case-files/:id ─────────────────────────────────────
// Soft-delete — "File Shredding" animation plays on client

router.delete('/case-files/:id', async (req, res, next) => {
  try {
    const meal = await Meal.findById(req.params.id);
    if (!meal) {
      return res.status(404).json({ error: { code: 'ERR_CASE_FILE_NOT_FOUND', message: 'Case File not found.' } });
    }

    meal.deletedAt = new Date();
    await meal.save();

    res.status(200).json({ message: 'Case File archived. Shredding scheduled.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
