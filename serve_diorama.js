const http = require('http');
const fs = require('fs');

const PORT = 3000;
const filePath = '/Users/bnymynwysmn/Desktop/\u05d0\u05e4\u05dc\u05d9\u05e7\u05e6\u05d9\u05d4 \u05ea\u05d5\u05d0\u05e8/\u05db\u05e1\u05e3/MoneyCity/Resources/diorama.html';

const server = http.createServer((req, res) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  if (fs.existsSync(filePath)) {
    const html = fs.readFileSync(filePath);
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Length': html.length,
      'Access-Control-Allow-Origin': '*'
    });
    res.end(html);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('diorama.html not found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
