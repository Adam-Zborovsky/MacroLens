const express = require('express');
const { z } = require('zod');
const User = require('../models/User');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// ─── TDEE calculation (Mifflin-St Jeor) ──────────────────────────────────────

function computeTDEE({ massKilograms, heightCentimeters, ageYears, biologicalSex, activityMultiplier }) {
  if (!massKilograms || !heightCentimeters || !ageYears || !biologicalSex) return null;

  let bmr;
  if (biologicalSex === 'male') {
    bmr = 10 * massKilograms + 6.25 * heightCentimeters - 5 * ageYears + 5;
  } else {
    bmr = 10 * massKilograms + 6.25 * heightCentimeters - 5 * ageYears - 161;
  }

  return Math.round(bmr * (activityMultiplier ?? 1.55));
}

function computeMacroTargets(tdee, phase, macroSplit) {
  const phaseAdjustments = { bulk: 1.1, cut: 0.8, maintain: 1.0 };
  const targetCalories = Math.round(tdee * (phaseAdjustments[phase] ?? 1.0));

  const { proteinRatio = 0.3, carbohydratesRatio = 0.4, fatRatio = 0.3 } = macroSplit ?? {};

  return {
    calories:           targetCalories,
    proteinGrams:       Math.round((targetCalories * proteinRatio) / 4),
    carbohydratesGrams: Math.round((targetCalories * carbohydratesRatio) / 4),
    fatGrams:           Math.round((targetCalories * fatRatio) / 9),
  };
}

// ─── Zod schemas ─────────────────────────────────────────────────────────────

const MetricsPatchSchema = z.object({
  biometrics: z
    .object({
      massKilograms:      z.number().min(0).optional(),
      heightCentimeters:  z.number().min(0).optional(),
      ageYears:           z.number().min(0).optional(),
      biologicalSex:      z.enum(['male', 'female', 'prefer_not_to_say']).optional(),
      activityMultiplier: z.number().optional(),
    })
    .optional(),
  currentPhase: z.enum(['bulk', 'cut', 'maintain']).optional(),
  macroSplit: z
    .object({
      proteinRatio:       z.number().min(0).max(1),
      carbohydratesRatio: z.number().min(0).max(1),
      fatRatio:           z.number().min(0).max(1),
    })
    .optional(),
  dailyTargets: z
    .object({
      calories:           z.number().min(0),
      proteinGrams:       z.number().min(0),
      carbohydratesGrams: z.number().min(0),
      fatGrams:           z.number().min(0),
    })
    .optional(),
});

// ─── GET /api/v1/users/me ─────────────────────────────────────────────────────

router.get('/me', async (req, res, next) => {
  try {
    const userId = req.userId;
    const user = await User.findById(userId).select('-password');
    if (!user) {
      return res.status(404).json({ error: { code: 'ERR_USER_NOT_FOUND', message: 'User not found.' } });
    }
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// ─── PATCH /api/v1/users/metrics ─────────────────────────────────────────────
// Goals & Profile — Calibration Hub screen

router.patch('/metrics', async (req, res, next) => {
  try {
    const userId = req.userId;
    const body = MetricsPatchSchema.parse(req.body);

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: { code: 'ERR_USER_NOT_FOUND', message: 'User profile not found.' } });
    }

    if (body.biometrics) {
      Object.assign(user.biometrics, body.biometrics);
    }
    if (body.currentPhase) user.currentPhase = body.currentPhase;
    if (body.macroSplit)   Object.assign(user.macroSplit, body.macroSplit);

    if (body.dailyTargets) {
      user.dailyTargets = body.dailyTargets;
    } else {
      // Recompute TDEE and targets after any metric change if manual targets are NOT provided
      const tdee = computeTDEE(user.biometrics);
      if (tdee) {
        user.dailyTargets = computeMacroTargets(tdee, user.currentPhase, user.macroSplit);
      }
    }

    user.isOnboarded = true;
    await user.save();

    res.json(user);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
