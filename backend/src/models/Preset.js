const mongoose = require('mongoose');
const { Schema } = mongoose;

const PresetSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    calories: {
      type: Number,
      required: true,
      min: 0,
    },
    proteinGrams: {
      type: Number,
      required: true,
      min: 0,
    },
    carbohydratesGrams: {
      type: Number,
      required: true,
      min: 0,
    },
    fatGrams: {
      type: Number,
      required: true,
      min: 0,
    },
    amount: {
      type: Number,
      default: 1,
      min: 0.1,
    },
  },
  {
    timestamps: true,
  }
);

// Search by name
PresetSchema.index({ userId: 1, name: 'text' });

module.exports = mongoose.model('Preset', PresetSchema);
