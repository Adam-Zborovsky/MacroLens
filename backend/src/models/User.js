const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
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
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
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
      },
    },

    currentPhase: {
      type: String,
      enum: ['bulk', 'cut', 'maintain'],
      default: 'maintain',
    },

    dailyTargets: { type: MacroTargetSchema, default: null },

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

    reminderSchedule: {
      breakfastTime: { type: String, default: null },
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

// Hash password before saving
UserSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err);
  }
});

// Method to compare password
UserSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', UserSchema);
