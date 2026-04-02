const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * Capture — the raw image submission before AI analysis.
 * A Capture transitions through states:
 *   pending → analyzing → completed | failed
 * On completion, a Meal (Case File) document is created and linked.
 */
const CaptureSchema = new Schema(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },

    // Pre-signed S3/GCS URL — the image asset
    imageUrl: {
      type: String,
      required: true,
    },
    imageMimeType: {
      type: String,
      enum: ['image/jpeg', 'image/png', 'image/webp', 'image/heic'],
      default: 'image/jpeg',
    },
    imageSizeBytes: { type: Number, default: null },

    analysisStatus: {
      type: String,
      enum: ['pending', 'analyzing', 'completed', 'failed'],
      default: 'pending',
      index: true,
    },

    // Populated once analysis completes
    resultMealId: {
      type: Schema.Types.ObjectId,
      ref: 'Meal',
      default: null,
    },

    // Gemini raw response — stored for auditability and re-analysis
    geminiRawResponse: {
      type: Schema.Types.Mixed,
      default: null,
      select: false, // Excluded from default queries
    },

    // Error classification if analysis fails
    analysisError: {
      code: {
        type: String,
        enum: [
          'ERR_VISUAL_OBSCURED',
          'ERR_NO_FOOD_DETECTED',
          'ERR_LOW_RESOLUTION',
          'ERR_GEMINI_TIMEOUT',
          'ERR_GEMINI_QUOTA',
          'ERR_SCHEMA_INVALID',
          'ERR_UNKNOWN',
        ],
        default: null,
      },
      message: { type: String, default: null },
    },

    analysisStartedAt:   { type: Date, default: null },
    analysisCompletedAt: { type: Date, default: null },

    // Derived: total wall-clock time for analysis in ms
    analysisLatencyMs: { type: Number, default: null },

    // Multi-shot: link captures that belong to the same meal session
    sessionGroupId: { type: String, default: null, index: true },
  },
  {
    timestamps: true,
    collection: 'captures',
  }
);

CaptureSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Capture', CaptureSchema);
