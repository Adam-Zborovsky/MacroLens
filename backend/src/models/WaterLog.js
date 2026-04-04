const mongoose = require('mongoose');
const { Schema } = mongoose;

const WaterLogSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    amountMl: {
      type: Number,
      required: true,
      min: 0,
    },
    loggedAt: {
      type: Date,
      required: true,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
    collection: 'water_logs',
  }
);

// Index for fetching logs by user and date range (e.g., today)
WaterLogSchema.index({ userId: 1, loggedAt: -1 });

module.exports = mongoose.model('WaterLog', WaterLogSchema);
