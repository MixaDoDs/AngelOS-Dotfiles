// Minimal Chrome DevTools Protocol client for driving Spotify.
// Spotify has to be started with --remote-debugging-port=<port> (localhost only).
// Uses the WebSocket built into Node 22+, no dependencies.

async function connect(port = 9222) {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = targets.find(t => t.type === "page" && /xpui\.app\.spotify\.com/.test(t.url));
  if (!page) throw new Error("Spotify page target not found on port " + port);

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

  let id = 0;
  const pending = new Map();
  ws.onmessage = ev => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(msg.error.message));
      else resolve(msg.result);
    }
  };

  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const n = ++id;
    pending.set(n, { resolve, reject });
    ws.send(JSON.stringify({ id: n, method, params }));
  });

  // run an expression (or async IIFE) in the page and return its value
  async function evaluate(expression) {
    const r = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error("page: " + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    return r.result.value;
  }

  async function screenshot() {
    const r = await send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
    return Buffer.from(r.data, "base64");
  }

  return { send, evaluate, screenshot, close: () => ws.close() };
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

module.exports = { connect, sleep };
