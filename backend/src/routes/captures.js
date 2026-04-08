const express = require('express');
const { z } = require('zod');
const path = require('path');
const fs = require('fs').promises;
const Capture = require('../models/Capture');
const Meal    = require('../models/Meal');
const { AnalyzerService } = require('../services/analyzer');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

const analyzer = new AnalyzerService();

const CaptureCreateSchema = z.object({
  imageBase64:  z.string().optional(),
  imagesBase64: z.array(z.string()).optional(),
  mimeType:     z.string().optional(),
  sessionGroupId: z.string().optional(),
});

// ─── POST /api/v1/captures ───────────────────────────────────────────────────

router.post('/', async (req, res, next) => {
  try {
    const userId = req.userId;
    const { imageBase64, imagesBase64, mimeType, sessionGroupId } = CaptureCreateSchema.parse(req.body);

    const imagesToProcess = imagesBase64 || (imageBase64 ? [imageBase64] : []);
    if (imagesToProcess.length === 0) {
      return res.status(400).json({ error: { message: 'No images provided' } });
    }

    // 1. Create directory for Docker volume if it doesn't exist
    const uploadDir = path.join(__dirname, '../../uploads');
    await fs.mkdir(uploadDir, { recursive: true });

    // 2. Save each image to disk
    const localPaths = [];
    for (const [idx, base64Data] of imagesToProcess.entries()) {
      const fileName = `specimen_${Date.now()}_${userId.toString().substring(0, 5)}_${idx}.jpg`;
      const filePath = path.join(uploadDir, fileName);
      const imageBuffer = Buffer.from(base64Data, 'base64');
      await fs.writeFile(filePath, imageBuffer);
      localPaths.push(`uploads/${fileName}`);
    }

    // 3. Create database record
    const capture = await Capture.create({
      userId,
      mimeType: mimeType || 'image/jpeg',
      analysisStatus: 'analyzing',
      sessionGroupId,
      localPaths,
    });

    // 4. Run AI analysis
    try {
      console.log(`[ANALYSIS] Starting analysis for user ${userId} and capture ${capture._id} (Count: ${imagesToProcess.length})`);
      const geminiData = await analyzer.analyzeCapture(imagesToProcess, mimeType);
      
      console.log(`[ANALYSIS] Gemini data received. Mapping to schema (transient)...`);
      const mealData = AnalyzerService.mapToMealSchema(geminiData, userId, capture._id);
      
      capture.analysisStatus = 'completed';
      await capture.save();

      console.log(`[ANALYSIS] Capture ${capture._id} analyzed. Returning data for confirmation.`);
      res.status(201).json({ capture, caseFile: mealData });
    } catch (analysisErr) {
      console.error(`[ANALYSIS_ERROR] Capture ${capture._id} failed:`, analysisErr);
      capture.analysisStatus = 'failed';
      capture.analysisError = {
        code: analysisErr.code || 'ERR_ANALYSIS_FAILED',
        message: analysisErr.message,
      };
      await capture.save();
      
      if (analysisErr.status === 422) {
        return res.status(422).json({
          error: {
            code: analysisErr.code,
            message: analysisErr.message,
          }
        });
      }
      throw analysisErr;
    }
  } catch (err) {
    next(err);
  }
});

module.exports = router;
