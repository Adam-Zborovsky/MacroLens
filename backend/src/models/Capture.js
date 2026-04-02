const mongoose = require('mongoose');
const { Schema } = mongoose;

const CaptureSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    mimeType: { type: String, default: 'image/jpeg' },
    
    // Physical path on disk (Docker Volume)
    localPath: { type: String, default: null },

    analysisStatus: {
      type: String,
      enum: ['pending', 'analyzing', 'completed', 'failed'],
      default: 'pending',
    },
    analysisError: {
      code:    { type: String, default: null },
      message: { type: String, default: null },
    },

    resultMealId: {
      type: Schema.Types.ObjectId,
      ref: 'Meal',
      default: null,
    },

    sessionGroupId: { type: String, default: null, index: true },
  },
  {
    timestamps: true,
    collection: 'captures',
  }
);

CaptureSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Capture', CaptureSchema);
