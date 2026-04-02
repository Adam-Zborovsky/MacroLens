const jwt = require('jsonwebtoken');

function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'ERR_UNAUTHORIZED', message: 'Missing or invalid token.' } });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');
    req.userId = decoded.userId;
    next();
  } catch (err) {
    return res.status(401).json({ error: { code: 'ERR_INVALID_TOKEN', message: 'Token is invalid or expired.' } });
  }
}

module.exports = { verifyToken };
