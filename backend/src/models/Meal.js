const mongoose = require('mongoose');
const { Schema } = mongoose;

// ─────────────────────────────────────────────
// Sub-schemas
// ─────────────────────────────────────────────

const NutritionProfileSchema = new Schema(
  {
    calories:       { type: Number, required: true, min: 0 },
    proteinGrams:   { type: Number, required: true, min: 0 },
    carbohydratesGrams: { type: Number, required: true, min: 0 },
    fatGrams:       { type: Number, required: true, min: 0 },
    fiberGrams:     { type: Number, default: 0, min: 0 },
    sodiumMilligrams: { type: Number, default: null },
    ironMilligrams:   { type: Number, default: null },
    calciumMilligrams: { type: Number, default: null },
  },
  { _id: false }
);

const AlternativeCandidateSchema = new Schema(
  {
    name:            { type: String, required: true },
    usdaSearchTerm:  { type: String, required: true },
    nutritionPer100g: { type: NutritionProfileSchema, required: true },
  },
  { _id: false }
);

// A single identified food item within the Case File.
const DetectedItemSchema = new Schema(
  {
    itemId: {
      type: String,
      required: true,
      default: () => require('crypto').randomUUID(),
    },
    name:           { type: String, required: true },
    usdaSearchTerm: { type: String, required: true },
    usdaFoodId:     { type: String, default: null },
    boundingBox2D:  { type: [Number], default: [] },

    // Volumetric estimation
    massGrams: {
      type: Number,
      required: true,
      min: 0,
      comment: 'Estimated mass in grams — user-adjustable via NotchedHapticSlider (5g increments)',
    },
    userAdjustedMassGrams: {
      type: Number,
      default: null,
      comment: 'Set when user overrides the AI estimate via Detective UI',
    },

    compositionConfidence: {
      type: String,
      enum: ['high', 'medium', 'low'],
      required: true,
    },
    preparationState: {
      type: String,
      enum: ['cooked', 'raw', 'processed', 'unknown'],
      default: 'unknown',
    },
    cookingMethod: {
      type: String,
      enum: ['grilled', 'fried', 'boiled', 'baked', 'raw', 'unknown'],
      default: 'unknown',
    },

    nutritionPer100g: { type: NutritionProfileSchema, required: true },
    nutritionTotal:   { type: NutritionProfileSchema, required: true },

    // AI-surfaced alternatives for Detective UI swap
    alternativeCandidates: { type: [AlternativeCandidateSchema], default: [] },

    // Audit trail: was this item user-verified or AI-only?
    verificationStatus: {
      type: String,
      enum: ['ai_verified', 'user_confirmed', 'user_corrected', 'custom_entry'],
      default: 'ai_verified',
    },
  },
  { _id: false }
);

// ─────────────────────────────────────────────
// Case File (Meal) — the primary document
// ─────────────────────────────────────────────

const MealSchema = new Schema(
  {
    // Ownership — Firebase UID string (not ObjectId)
    userId: {
      type: String,
      required: true,
      index: true,
    },

    // Linked to the raw image capture
    captureId: {
      type: Schema.Types.ObjectId,
      ref: 'Capture',
      default: null,
    },

    // Case File identity
    caseFileId: {
      type: String,
      required: true,
      unique: true,
      default: () => require('crypto').randomUUID(),
      comment: 'Immutable public identifier surfaced in the UI',
    },

    mealType: {
      type: String,
      enum: ['breakfast', 'lunch', 'dinner', 'snack', 'unknown'],
      default: 'unknown',
    },

    loggedAt: {
      type: Date,
      required: true,
      default: Date.now,
      index: true,
    },

    // The AI's composite confidence across all detected items
    overallConfidence: {
      type: String,
      enum: ['high', 'medium', 'low'],
      required: true,
    },

    detectedItems: {
      type: [DetectedItemSchema],
      validate: {
        validator: (v) => v.length > 0,
        message: 'ERR_CASE_FILE_EMPTY: A Case File must contain at least one detected item.',
      },
    },

    // Aggregated totals — computed and stored for fast dashboard queries
    mealTotals: { type: NutritionProfileSchema, required: true },

    // Anchor data used by the AI for volumetric calibration
    volumetricAnchors: {
      estimatedPlateDiameterCm: { type: Number, default: null },
      anchorObjectDetected:     { type: String, default: null, comment: 'e.g., "fork", "hand"' },
      calibrationMethod:        {
        type: String,
        enum: ['plate_size', 'cutlery', 'hand', 'barcode', 'manual', 'unknown'],
        default: 'unknown',
      },
    },

    // Entry method — drives UI badge display
    entryMethod: {
      type: String,
      enum: ['vision_capture', 'barcode_scan', 'manual_search', 'quick_add', 'restaurant_lookup'],
      required: true,
      default: 'vision_capture',
    },

    // Whether all items in this Case File are backed by USDA or explicit custom values
    nutritionDataVerified: {
      type: Boolean,
      default: false,
      comment: 'True only when every DetectedItem has a usdaFoodId or verificationStatus=custom_entry',
    },

    // Soft-delete — "File Shredding" animation hides before purge
    deletedAt: { type: Date, default: null },

    notes: { type: String, default: null, maxlength: 1000 },
  },
  {
    timestamps: true,
    collection: 'case_files',
  }
);

// ─────────────────────────────────────────────
// Indexes
// ─────────────────────────────────────────────

// Dashboard: fetch today's Case Files fast
MealSchema.index({ userId: 1, loggedAt: -1 });
// Meal History search by food name
MealSchema.index({ userId: 1, 'detectedItems.name': 'text' });
// Soft-delete filter
MealSchema.index({ deletedAt: 1 });

// ─────────────────────────────────────────────
// Virtuals
// ─────────────────────────────────────────────

MealSchema.virtual('isVerified').get(function () {
  return this.nutritionDataVerified && this.overallConfidence === 'high';
});

// ─────────────────────────────────────────────
// Statics
// ─────────────────────────────────────────────

MealSchema.statics.computeTotals = function (items) {
  return items.reduce(
    (totals, item) => {
      const nutrition = item.nutritionTotal;
      totals.calories           += nutrition.calories;
      totals.proteinGrams       += nutrition.proteinGrams;
      totals.carbohydratesGrams += nutrition.carbohydratesGrams;
      totals.fatGrams           += nutrition.fatGrams;
      totals.fiberGrams         += nutrition.fiberGrams ?? 0;
      return totals;
    },
    { calories: 0, proteinGrams: 0, carbohydratesGrams: 0, fatGrams: 0, fiberGrams: 0 }
  );
};

// Scope queries to non-deleted Case Files by default
MealSchema.pre(/^find/, function () {
  if (this.getFilter().deletedAt === undefined) {
    this.where({ deletedAt: null });
  }
});

module.exports = mongoose.model('Meal', MealSchema);
