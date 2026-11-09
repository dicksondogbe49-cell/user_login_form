// Vercel Serverless Function entry point
require('dotenv').config();

let serverPromise;

function getServer() {
  if (!serverPromise) {
    serverPromise = (async () => {
      try {
        const { app, startPromise } = require('../server');
        if (startPromise) {
          await startPromise;
        }
        return app;
      } catch (err) {
        console.error('Vercel serverless initialization error:', err);
        throw err;
      }
    })();
  }
  return serverPromise;
}

module.exports = async (req, res) => {
  try {
    const app = await getServer();
    return app(req, res);
  } catch (err) {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      error: 'Serverless Function Error',
      message: err.message,
      stack: process.env.NODE_ENV === 'production' ? undefined : err.stack
    }));
  }
};
