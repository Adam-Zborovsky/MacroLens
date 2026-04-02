const mongoose = require('mongoose');
const { Schema } = mongoose;

const MacroTargetSchema = new Schema(
  {
    calories:           { type: Number, required: true, min: 0 },
    proteinGrams:       { type: Number, required: true, min: 0 },
    carbohydratesGrams: { type: Number, required: true, min: 0 },
    fatGrams:           { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const UserSchema = new Schema(
  {
    // Firebase UID — primary lookup key (string, not ObjectId)
    firebaseUid: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },

    displayName: { type: String, default: null },

    // Physical metrics — used for TDEE calculation
    biometrics: {
      massKilograms:    { type: Number, default: null, min: 0 },
      heightCentimeters: { type: Number, default: null, min: 0 },
      ageYears:         { type: Number, default: null, min: 0 },
      biologicalSex:    {
        type: String,
        enum: ['male', 'female', 'prefer_not_to_say', null],
        default: null,
      },
      activityMultiplier: {
        type: Number,
        enum: [1.2, 1.375, 1.55, 1.725, 1.9],
        default: 1.55,
        comment: 'Sedentary=1.2, Light=1.375, Moderate=1.55, Active=1.725, VeryActive=1.9',
      },
    },

    // Current training phase drives target macro calculations
    currentPhase: {
      type: String,
      enum: ['bulk', 'cut', 'maintain'],
      default: 'maintain',
    },

    // Computed targets — updated when biometrics or phase changes
    dailyTargets: { type: MacroTargetSchema, default: null },

    // Custom macro split overrides (0–1.0, must sum to ~1.0)
    macroSplit: {
      proteinRatio:       { type: Number, default: 0.3, min: 0, max: 1 },
      carbohydratesRatio: { type: Number, default: 0.4, min: 0, max: 1 },
      fatRatio:           { type: Number, default: 0.3, min: 0, max: 1 },
    },

    hydrationTargetMl: { type: Number, default: 2500 },

    integrations: {
      appleHealthEnabled:  { type: Boolean, default: false },
      googleFitEnabled:    { type: Boolean, default: false },
    },

    // Notification schedule (meal-time reminders)
    reminderSchedule: {
      breakfastTime: { type: String, default: null, comment: 'HH:MM local time' },
      lunchTime:     { type: String, default: null },
      dinnerTime:    { type: String, default: null },
    },

    isOnboarded: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    collection: 'users',
  }
);

module.exports = mongoose.model('User', UserSchema);
