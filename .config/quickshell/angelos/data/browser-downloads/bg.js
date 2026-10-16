// angelOS: the downloads in progress, to the Halo (services/Downloads) through the native host
// org.angelos.downloads (scripts/browser-downloads-host.py). Only the file, the bytes and the
// state go out — no address. Once a second while something downloads; the port is let go when
// nothing does (the host then writes an empty list and ends).
let port = null;
let timer = null;

function connect() {
  if (port)
    return port;
  try {
    port = chrome.runtime.connectNative("org.angelos.downloads");
    port.onDisconnect.addListener(() => { port = null; });
  } catch (e) {
    port = null;
  }
  return port;
}

async function send() {
  const list = await chrome.downloads.search({ state: "in_progress" });
  const p = connect();
  if (p) {
    try {
      p.postMessage({
        at: Date.now(),
        list: list.map(d => ({
          id: d.id,
          file: d.filename || "",
          received: d.bytesReceived || 0,
          total: d.totalBytes > 0 ? d.totalBytes : 0,
          paused: !!d.paused
        }))
      });
    } catch (e) {
      port = null;
    }
  }
  if (list.length) {
    if (!timer)
      timer = setInterval(send, 1000);
  } else {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    if (port) {
      port.disconnect();
      port = null;
    }
  }
}

chrome.downloads.onCreated.addListener(send);
chrome.downloads.onChanged.addListener(send);
chrome.runtime.onStartup.addListener(send);
chrome.runtime.onInstalled.addListener(send);
