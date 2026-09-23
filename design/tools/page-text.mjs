/**
 * 用 CDP 驱动 Edge 无头浏览器，打印某个 URL 渲染完成后的正文文本。
 * 用途：查应用市场重名（SPA 页面，普通 HTTP 抓不到内容）。
 *
 *   node page-text.mjs "https://appgallery.huawei.com/search/爪心" [等待毫秒]
 */
import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
// 端口随机，避免并发跑的时候两个进程抢同一个浏览器实例
const PORT = 9300 + Math.floor(Math.random() * 500);

const url = process.argv[2];
const extraWait = Number(process.argv[3] ?? 7000);
if (!url) {
  console.error('usage: node page-text.mjs <url> [waitMs]');
  process.exit(2);
}

const profile = `${process.env.TEMP ?? '.'}\\cdp-profile-${Date.now()}`;
const edge = spawn(EDGE, [
  '--headless=new',
  '--disable-gpu',
  '--no-first-run',
  '--no-default-browser-check',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  'about:blank'
], { stdio: 'ignore' });

async function targetUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const list = await res.json();
      const page = list.find((t) => t.type === 'page');
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
    } catch {
      // 浏览器还没起来
    }
    await sleep(300);
  }
  throw new Error('devtools not reachable');
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  const events = [];
  const ready = new Promise((resolve, reject) => {
    ws.addEventListener('open', () => resolve());
    ws.addEventListener('error', (e) => reject(new Error('ws error')));
  });
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
    } else if (msg.method) {
      events.push(msg.method);
    }
  });
  return {
    ready,
    send(method, params = {}) {
      const msgId = ++id;
      ws.send(JSON.stringify({ id: msgId, method, params }));
      return new Promise((resolve, reject) => pending.set(msgId, { resolve, reject }));
    },
    events,
    close: () => ws.close()
  };
}

try {
  const cdp = connect(await targetUrl());
  await cdp.ready;
  await cdp.send('Page.enable');
  await cdp.send('Page.navigate', { url });
  for (let i = 0; i < 40 && !cdp.events.includes('Page.loadEventFired'); i++) await sleep(250);
  await sleep(extraWait);
  const r = await cdp.send('Runtime.evaluate', {
    expression: 'document.body ? document.body.innerText : ""',
    returnByValue: true
  });
  console.log(r.result?.value ?? '(no text)');
  cdp.close();
} catch (err) {
  console.error('failed:', err.message);
  process.exitCode = 1;
} finally {
  edge.kill();
}
