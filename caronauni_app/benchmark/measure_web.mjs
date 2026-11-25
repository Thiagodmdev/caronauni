// Mede list_benchmark_web no Edge pelo protocolo do DevTools.
// A rodada 0 grava também o registro do painel de desempenho.
// Uso: node benchmark/measure_web.mjs <pasta do build> <pasta de saída> [rodadas]
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, extname, resolve, sep } from 'node:path';

const [build, out, rounds = '3'] = process.argv.slice(2);
const root = resolve(build);
const edge = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
await mkdir(out, { recursive: true });

const server = createServer(async (req, res) => {
  const path = new URL(req.url, 'http://x').pathname;
  const file = resolve(join(root, decodeURIComponent(path === '/' ? '/index.html' : path)));
  try {
    if (!file.startsWith(root + sep)) throw new Error('fora da pasta');
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(8799, '127.0.0.1');

async function connect(port) {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      const page = list.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('navegador não abriu');
}

let current;
async function measure(mode, round, attempt) {
  const port = 9400 + attempt * 100 + round * 2 + (mode === 'antes' ? 0 : 1);
  const profile = await mkdtemp(join(tmpdir(), 'bench-'));
  const child = (current = spawn(edge, [
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--disable-sync', '--disable-background-timer-throttling',
    '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding',
    '--window-size=500,900', '--window-position=0,0', 'about:blank',
  ]));
  const ws = new WebSocket(await connect(port));
  await new Promise((r) => (ws.onopen = r));
  let id = 0;
  const waiting = new Map();
  const marks = {};
  const trace = [];
  let traceDone;
  ws.onmessage = ({ data }) => {
    const m = JSON.parse(data);
    if (m.id) return waiting.get(m.id)?.(m.result ?? m.error);
    if (m.method === 'Runtime.consoleAPICalled') {
      const text = String(m.params.args[0]?.value ?? '');
      if (text.startsWith('BENCH ')) {
        const [, phase, value] = text.split(' ');
        marks[phase] = value ?? true;
      }
    }
    if (m.method === 'Runtime.exceptionThrown') console.log('ERRO', m.params.exceptionDetails.text);
    if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') console.log('ERRO', m.params.args[0]?.value);
    if (m.method === 'Tracing.dataCollected') trace.push(...m.params.value);
    if (m.method === 'Tracing.tracingComplete') traceDone?.();
  };
  const send = (method, params = {}) =>
    new Promise((r) => {
      waiting.set(++id, r);
      ws.send(JSON.stringify({ id, method, params }));
    });
  const until = async (phase) => {
    for (let i = 0; i < 600 && !marks[phase]; i++) await sleep(100);
    if (!marks[phase]) throw new Error(`não chegou em ${phase}`);
  };
  await send('Page.enable');
  await send('Runtime.enable');
  await send('HeapProfiler.enable');
  await send('Performance.enable');
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source: 'window.__f=[];(function t(n){window.__f.push(n);requestAnimationFrame(t)})(0);',
  });
  await send('Page.navigate', { url: `http://127.0.0.1:8799/?modo=${mode}` });
  await until('mounted');
  await sleep(2000);
  await send('HeapProfiler.collectGarbage');
  const metrics = await send('Performance.getMetrics');
  const heap = metrics.metrics.find((m) => m.name === 'JSHeapUsedSize').value / 2 ** 20;
  if (round === 0) {
    await send('Tracing.start', {
      transferMode: 'ReportEvents',
      categories: '-*,devtools.timeline,disabled-by-default-devtools.timeline,disabled-by-default-devtools.timeline.frame,v8.execute,blink.user_timing,loading,latencyInfo',
    });
  }
  await until('scroll_start');
  await send('Runtime.evaluate', { expression: 'window.__s=performance.now()' });
  await until('scroll_end');
  const { result } = await send('Runtime.evaluate', {
    expression: 'JSON.stringify(window.__f.filter(x=>x>=window.__s))', returnByValue: true,
  });
  const shot = await send('Page.captureScreenshot', { format: 'png' });
  await writeFile(join(out, `tela-${mode}-${round}.png`), Buffer.from(shot.data, 'base64'));
  if (round === 0) {
    const done = new Promise((r) => (traceDone = r));
    await send('Tracing.end');
    await done;
    await writeFile(join(out, `trace-${mode}.json`), JSON.stringify({ traceEvents: trace }));
  }
  const frames = JSON.parse(result.value);
  const gaps = frames.slice(1).map((x, i) => x - frames[i]).sort((a, b) => a - b);
  const total = frames.at(-1) - frames[0];
  ws.close();
  child.kill();
  await sleep(1500);
  return {
    mode, round,
    montagem_ms: +Number(marks.mounted).toFixed(1),
    heap_mb: +heap.toFixed(1),
    quadros: gaps.length,
    fps: +((gaps.length / total) * 1000).toFixed(1),
    quadro_p50_ms: +gaps[gaps.length >> 1].toFixed(1),
    quadro_p95_ms: +gaps[Math.floor(gaps.length * 0.95)].toFixed(1),
    pior_ms: +gaps.at(-1).toFixed(1),
    acima_33ms: gaps.filter((g) => g > 33.4).length,
  };
}

const all = [];
for (let r = 0; r < Number(rounds); r++) {
  for (const mode of r % 2 ? ['depois', 'antes'] : ['antes', 'depois']) {
    let result;
    for (let attempt = 1; !result; attempt++) {
      try {
        result = await measure(mode, r, attempt);
      } catch (e) {
        current?.kill();
        console.log('FALHA', mode, r, e.message);
        if (attempt === 3) process.exit(1);
      }
    }
    console.log('RESULT', JSON.stringify(result));
    all.push(result);
  }
}
await writeFile(join(out, 'resultados.json'), JSON.stringify(all, null, 1));
server.close();
process.exit(0);
