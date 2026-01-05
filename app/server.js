const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics setup
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const requestCounter = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Logger setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.path, res.statusCode).observe(duration);
    requestCounter.labels(req.method, req.path, res.statusCode).inc();
    logger.info({
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}s`,
      timestamp: new Date().toISOString()
    });
  });
  next();
});

app.use(express.json());
app.use(express.static('public'));

// Routes
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>DevOps Demo App</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 800px;
          margin: 50px auto;
          padding: 20px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container {
          background: rgba(255,255,255,0.1);
          padding: 30px;
          border-radius: 10px;
          backdrop-filter: blur(10px);
        }
        h1 { margin-top: 0; }
        .stats { 
          display: grid; 
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 20px;
          margin: 20px 0;
        }
        .stat-box {
          background: rgba(255,255,255,0.2);
          padding: 20px;
          border-radius: 8px;
          text-align: center;
        }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { font-size: 0.9em; opacity: 0.8; }
        button {
          background: white;
          color: #667eea;
          border: none;
          padding: 10px 20px;
          border-radius: 5px;
          cursor: pointer;
          font-size: 1em;
          margin: 5px;
        }
        button:hover { opacity: 0.8; }
        #output {
          background: rgba(0,0,0,0.3);
          padding: 15px;
          border-radius: 5px;
          margin-top: 20px;
          min-height: 100px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 DevOps Demo Application</h1>
        <p>A simple interactive Node.js app with monitoring and CI/CD</p>
        
        <div class="stats" id="stats">
          <div class="stat-box">
            <div class="stat-value" id="uptime">Loading...</div>
            <div class="stat-label">Uptime (seconds)</div>
          </div>
          <div class="stat-box">
            <div class="stat-value" id="requests">Loading...</div>
            <div class="stat-label">Total Requests</div>
          </div>
          <div class="stat-box">
            <div class="stat-value" id="timestamp">Loading...</div>
            <div class="stat-label">Server Time</div>
          </div>
        </div>

        <div>
          <button onclick="fetchData()">📊 Fetch Data</button>
          <button onclick="checkHealth()">❤️ Health Check</button>
          <button onclick="viewMetrics()">📈 View Metrics</button>
          <button onclick="refreshStats()">🔄 Refresh Stats</button>
        </div>

        <div id="output"></div>
      </div>

      <script>
        function displayOutput(data) {
          document.getElementById('output').innerHTML = 
            '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
        }

        async function fetchData() {
          const response = await fetch('/api/data');
          const data = await response.json();
          displayOutput(data);
        }

        async function checkHealth() {
          const response = await fetch('/health');
          const data = await response.json();
          displayOutput(data);
        }

        async function viewMetrics() {
          const response = await fetch('/metrics');
          const text = await response.text();
          document.getElementById('output').innerHTML = '<pre>' + text + '</pre>';
        }

        async function refreshStats() {
          const response = await fetch('/api/data');
          const data = await response.json();
          document.getElementById('uptime').textContent = Math.floor(data.uptime);
          document.getElementById('requests').textContent = data.requests;
          document.getElementById('timestamp').textContent = 
            new Date().toLocaleTimeString();
        }

        // Auto-refresh stats every 5 seconds
        setInterval(refreshStats, 5000);
        refreshStats();
      </script>
    </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/api/data', (req, res) => {
  const data = {
    message: 'Data fetched successfully',
    users: Math.floor(Math.random() * 1000) + 1000,
    requests: Math.floor(Math.random() * 5000) + 5000,
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  };
  res.json(data);
});

app.listen(PORT, () => {
  logger.info(`Server started on port ${PORT}`);
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
