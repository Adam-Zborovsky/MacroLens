/**
 * Central error handler.
 * Uses the clinical product voice defined in context.md:
 *   ERR_<DOMAIN>_<REASON>: <description>
 */
function errorHandler(err, req, res, next) {
  const status = err.status || err.statusCode || 500;

  // Zod validation errors
  if (err.name === 'ZodError') {
    return res.status(422).json({
      error: {
        code: 'ERR_VALIDATION_SCHEMA',
        message: 'Request payload failed schema validation.',
        issues: err.errors,
      },
    });
  }

  // Mongoose validation errors
  if (err.name === 'ValidationError') {
    return res.status(422).json({
      error: {
        code: 'ERR_CASE_FILE_SCHEMA',
        message: err.message,
      },
    });
  }

  // Mongoose duplicate key
  if (err.code === 11000) {
    return res.status(409).json({
      error: {
        code: 'ERR_DUPLICATE_RECORD',
        message: 'A record with this identifier already exists.',
      },
    });
  }

  // Known operational errors with a code property
  if (err.code) {
    return res.status(status).json({
      error: {
        code: err.code,
        message: err.message,
      },
    });
  }

  // Unhandled — mask internals in production
  if (process.env.NODE_ENV === 'production') {
    console.error('[ERR_INTERNAL]', err);
  }

  const message =
    process.env.NODE_ENV === 'production'
      ? 'ERR_INTERNAL: An unspecified analysis error occurred.'
      : err.message;

  res.status(status).json({
    error: {
      code: 'ERR_INTERNAL',
      message,
    },
  });
}

module.exports = { errorHandler };
