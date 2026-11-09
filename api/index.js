// Vercel Serverless Function entry point
require('dotenv').config();
const { app, startPromise } = require('../server');

module.exports = async (req, res) => {
  if (startPromise) {
    await startPromise;
  }
  return app(req, res);
};
