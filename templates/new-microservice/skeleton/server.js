const http = require('http');
const os = require('os');

const PORT = process.env.PORT || ${{ values.port }};
const SERVICE_NAME = '${{ values.name }}';

let requestCount = 0;
let errorCount = 0;
const startTime = Date.now();

const server = http.createServer((req, res) => {
  requestCount++;

  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', hostname: os.hostname(), uptime: process.uptime() }));
    return;
  }

  if (req.url === '/metrics') {
    const uptime = (Date.now() - startTime) / 1000;
    const metrics = [
      `# HELP http_requests_total Total HTTP requests`,
      `# TYPE http_requests_total counter`,
      `http_requests_total{service="${SERVICE_NAME}",status="200"} ${requestCount}`,
      `http_requests_total{service="${SERVICE_NAME}",status="500"} ${errorCount}`,
      `# HELP process_uptime_seconds Process uptime`,
      `# TYPE process_uptime_seconds gauge`,
      `process_uptime_seconds{service="${SERVICE_NAME}"} ${uptime}`,
      `# HELP process_resident_memory_bytes Resident memory`,
      `# TYPE process_resident_memory_bytes gauge`,
      `process_resident_memory_bytes{service="${SERVICE_NAME}"} ${process.memoryUsage().rss}`,
    ].join('\n');
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(metrics);
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: `Hello from ${SERVICE_NAME}`,
    hostname: os.hostname(),
    version: '1.0.0',
  }));
});

server.listen(PORT, () => console.log(`${SERVICE_NAME} listening on port ${PORT}`));
