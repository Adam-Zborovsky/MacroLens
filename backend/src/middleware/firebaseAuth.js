const admin = require('firebase-admin');

// Initialize Firebase Admin (assumes FIREBASE_ADMIN_JSON env var is set)
// For development, you can use firebase-admin-key.json in the root directory
let firebaseInitialized = false;

function initFirebaseAdmin() {
  if (firebaseInitialized) return;

  try {
    const serviceAccount = process.env.FIREBASE_ADMIN_JSON
      ? JSON.parse(process.env.FIREBASE_ADMIN_JSON)
      : require('../../firebase-admin-key.json');

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    firebaseInitialized = true;
    console.log('[Firebase] Admin SDK initialized');
  } catch (err) {
    console.warn('[Firebase] Admin SDK not initialized (expected for stub auth):', err.message);
  }
}

// Initialize on first import
initFirebaseAdmin();

/**
 * Middleware to verify Firebase ID tokens and extract user info.
 * Falls back to stub userId for development.
 */
async function verifyFirebaseToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    // No auth header — return 401
    if (!authHeader) {
      return res.status(401).json({
        error: { code: 'ERR_AUTH_REQUIRED', message: 'Authorization header required.' },
      });
    }

    // Extract token from "Bearer <token>"
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;

    if (!token) {
      return res.status(401).json({
        error: { code: 'ERR_INVALID_TOKEN', message: 'Invalid authorization header format.' },
      });
    }

    // Try to verify with Firebase
    if (admin.apps.length > 0) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.userId = decodedToken.uid;
        req.user = decodedToken;
        return next();
      } catch (err) {
        console.warn('[Firebase] Token verification failed:', err.message);
      }
    }

    // Fallback for development: accept stub tokens (for testing without Firebase)
    // In production, this branch should never execute
    if (process.env.NODE_ENV !== 'production') {
      req.userId = 'stub_' + token.substring(0, 16);
      req.user = { uid: req.userId, email: 'test@macrolens.local' };
      return next();
    }

    return res.status(401).json({
      error: { code: 'ERR_INVALID_TOKEN', message: 'Firebase token verification failed.' },
    });
  } catch (err) {
    console.error('[Firebase Auth] Unexpected error:', err);
    res.status(500).json({
      error: {
        code: 'ERR_AUTH_FAILED',
        message: 'Authentication failed.',
      },
    });
  }
}

module.exports = { verifyFirebaseToken };
