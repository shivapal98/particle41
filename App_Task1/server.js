// server.js
const express = require("express");
const os = require("os");

const app = express();
const port = 3000;

// Middleware to get the visitor's IP
app.use((req, res, next) => {
  req.visitorIP = req.headers["x-forwarded-for"] || req.socket.remoteAddress;
  next();
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    timestamp: new Date().toISOString(),
    ip: req.visitorIP,
  });
});

// Start the server
app.listen(port, () => {
  console.log(`SimpleTimeService running on http://localhost:${port}`);
});
