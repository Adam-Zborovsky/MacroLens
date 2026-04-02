const express = require('express');
const { z } = require('zod');
const Capture = require('../models/Capture');
const Meal    = require('../models/Meal');
const { AnalyzerService } = require('../services/analyzer');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');

const router = express.Router();
const analyzer = new AnalyzerService();

// All capture routes require authentication
router.use(verifyFirebaseToken);

// ─── Zod schema for capture submission ───────────────────────────────────────

const CaptureSubmitSchema = z.object({
  // Base64-encoded image data (mobile sends this directly)
  imageBase64: z.string().min(100, 'ERR_IMAGE_EMPTY: No image data provided'),
  mimeType: z
    .enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
    .default('image/jpeg'),
  sessionGroupId: z.string().uuid().optional(),
});

// ─── POST /api/v1/captures ───────────────────────────────────────────────────
// Accepts a base64 image, creates a Capture record, triggers Gemini analysis,
// and returns a completed Case File (Meal). Optimistic UI: responds with
// capture.analysisStatus='analyzing' immediately, then streams/updates.

router.post('/', async (req, res, next) => {
  try {
    const body = CaptureSubmitSchema.parse(req.body);
    const userId = req.userId;

    // 1. Create Capture record in 'analyzing' state — Optimistic UI
    const capture = await Capture.create({
      userId,
      imageUrl:       `pending:base64`, // Replace with pre-signed URL logic
      imageMimeType:  body.mimeType,
      analysisStatus: 'analyzing',
      analysisStartedAt: new Date(),
      sessionGroupId: body.sessionGroupId ?? null,
    });

    // 2. Run Gemini analysis
    let geminiData;
    try {
      geminiData = await analyzer.analyzeCapture(body.imageBase64, body.mimeType);
    } catch (analysisErr) {
      await Capture.findByIdAndUpdate(capture._id, {
        analysisStatus: 'failed',
        analysisCompletedAt: new Date(),
        'analysisError.code':    analysisErr.code || 'ERR_UNKNOWN',
        'analysisError.message': analysisErr.message,
      });
      return next(analysisErr);
    }

    // 3. Map and persist the Case File
    const mealData = AnalyzerService.mapToMealSchema(geminiData, userId, capture._id);
    const meal = await Meal.create(mealData);

    // 4. Finalize Capture record
    await Capture.findByIdAndUpdate(capture._id, {
      analysisStatus:       'completed',
      resultMealId:         meal._id,
      analysisCompletedAt:  new Date(),
      analysisLatencyMs:    geminiData.analysisLatencyMs,
      geminiRawResponse:    geminiData,
    });

    res.status(201).json({
      captureId:       capture._id,
      analysisLatencyMs: geminiData.analysisLatencyMs,
      caseFile: meal,
    });
  } catch (err) {
    next(err);
  }
});

// ─── GET /api/v1/captures/:id ─────────────────────────────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const capture = await Capture.findById(req.params.id).populate('resultMealId');
    if (!capture) {
      return res.status(404).json({ error: { code: 'ERR_CAPTURE_NOT_FOUND', message: 'Capture record not found.' } });
    }
    res.json(capture);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
