// proxy.js
// 0.0.0.0:8080 → 127.0.0.1:18789 HTTP + WebSocket 프록시
//
// ref: https://nodejs.org/api/http.html
// ref: https://nodejs.org/api/net.html
// ref: spec/HANDOVER.md — WebSocket 터널 gcube 환경 검증 완료

'use strict';

const http = require('http');
const net  = require('net');

const UPSTREAM_HOST = '127.0.0.1';
const UPSTREAM_PORT = 18789;
const LISTEN_PORT   = 8080;
const LISTEN_HOST   = '0.0.0.0';

// ── HTTP 요청 프록시 ──────────────────────────────────────
const server = http.createServer((req, res) => {
  console.log(`[HTTP] ${req.method} ${req.url}`);

  const options = {
    hostname: UPSTREAM_HOST,
    port:     UPSTREAM_PORT,
    path:     req.url,
    method:   req.method,
    headers:  req.headers,
  };

  const proxy = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxy.on('error', (err) => {
    console.error(`[ERROR] HTTP proxy error: ${err.message}`);
    if (!res.headersSent) res.writeHead(502);
    res.end('Bad Gateway');
  });

  req.on('error', (err) => {
    console.error(`[ERROR] Client request error: ${err.message}`);
    proxy.destroy();
  });

  req.pipe(proxy, { end: true });
});

// ── WebSocket Upgrade 터널 ────────────────────────────────
// gcube는 외부 HTTPS → 내부 HTTP로 전달 (x-forwarded-proto: http)
// Upgrade 요청을 원본 그대로 TCP 터널로 upstream에 전달
server.on('upgrade', (req, clientSocket, head) => {
  console.log(`[WS] Upgrade: ${req.url}`);

  const serverSocket = net.connect(UPSTREAM_PORT, UPSTREAM_HOST, () => {
    // 원본 HTTP upgrade 요청 헤더를 그대로 upstream에 재전송
    let raw = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      raw += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
    }
    raw += '\r\n';
    serverSocket.write(raw);

    if (head && head.length > 0) serverSocket.write(head);

    serverSocket.pipe(clientSocket, { end: true });
    clientSocket.pipe(serverSocket, { end: true });
  });

  serverSocket.on('error', (err) => {
    console.error(`[ERROR] WS server socket error: ${err.message}`);
    clientSocket.destroy();
  });

  clientSocket.on('error', (err) => {
    console.error(`[ERROR] WS client socket error: ${err.message}`);
    serverSocket.destroy();
  });
});

server.on('error', (err) => {
  console.error(`[ERROR] Server error: ${err.message}`);
  process.exit(1);
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`[proxy] ${LISTEN_HOST}:${LISTEN_PORT} → ${UPSTREAM_HOST}:${UPSTREAM_PORT}`);
});
