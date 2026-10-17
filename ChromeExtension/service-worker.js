const SERVER_URL = "ws://127.0.0.1:8765";

const SITES = {
  openDisneyPlus: { url: "https://www.disneyplus.com/home", match: "*://*.disneyplus.com/*" },
  openHulu: { url: "https://www.hulu.com/", match: "*://*.hulu.com/*" },
  openPeacock: { url: "https://www.peacocktv.com/", match: "*://*.peacocktv.com/*" },
  openAppleTV: { url: "https://tv.apple.com/", match: "*://tv.apple.com/*" },
  openYouTube: { url: "https://www.youtube.com/", match: "*://*.youtube.com/*" }
};

async function openSite(command) {
  const site = SITES[command];
  if (!site) return false;
  const [existing] = await chrome.tabs.query({ url: site.match });
  if (existing) {
    await chrome.tabs.update(existing.id, { active: true });
    await chrome.windows.update(existing.windowId, { focused: true });
  } else {
    await chrome.tabs.create({ url: site.url });
  }
  return true;
}
let socket;
let reconnectTimer;
let mostRecentStreamingTabId;

async function targetStreamingTabId() {
  if (mostRecentStreamingTabId) return mostRecentStreamingTabId;
  const { mostRecentStreamingTabId: storedId } = await chrome.storage.session.get("mostRecentStreamingTabId");
  if (storedId) return storedId;
  const tabs = await chrome.tabs.query({
    url: ["https://www.hulu.com/*", "https://www.disneyplus.com/*",
          "https://www.peacocktv.com/*", "https://tv.apple.com/*", "https://www.youtube.com/*"]
  });
  return tabs.find((tab) => tab.active)?.id ?? tabs[0]?.id;
}

async function credentials() {
  return chrome.storage.local.get(["token", "pairingCode"]);
}

function connect() {
  clearTimeout(reconnectTimer);
  const connection = new WebSocket(SERVER_URL);
  socket = connection;
  connection.onopen = async () => {
    const { token } = await credentials();
    if (socket !== connection) return;
    if (token) connection.send(JSON.stringify({ type: "authenticate", token }));
    else {
      // The Mac companion trusts connections from this same machine,
      // so the extension pairs automatically with no code to type.
      connection.send(JSON.stringify({
        type: "pairRequest",
        deviceName: "TV Remote Chrome"
      }));
    }
  };
  connection.onmessage = async ({ data }) => {
    const message = JSON.parse(data);
    if (message.type === "paired") {
      await chrome.storage.local.remove("pairingCode");
      await chrome.storage.local.set({ token: message.token });
    }
    if (message.type === "execute") {
      if (await openSite(message.command)) return;
      const tabId = await targetStreamingTabId();
      if (tabId) {
        if (message.command === "toggleFullscreen") {
          try {
            const tab = await chrome.tabs.get(tabId);
            const window = await chrome.windows.get(tab.windowId);
            await chrome.windows.update(tab.windowId, {
              state: window.state === "fullscreen" ? "normal" : "fullscreen"
            });
            console.log(`TV Remote: Chrome window is now ${window.state === "fullscreen" ? "normal" : "fullscreen"}`);
          } catch (error) {
            console.error("TV Remote: could not toggle Chrome fullscreen", error);
          }
          return;
        }
        chrome.tabs.sendMessage(tabId, { type: "execute", command: message.command });
      } else {
        console.warn("TV Remote: no Hulu or Disney+ tab is available");
      }
    }
    if (message.type === "search" || message.type === "selectTile") {
      const tabId = await targetStreamingTabId();
      if (tabId) chrome.tabs.sendMessage(tabId, message);
    }
  };
  connection.onclose = () => {
    if (socket === connection) reconnectTimer = setTimeout(connect, 3000);
  };
  connection.onerror = () => connection.close();
}

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message.type !== "playerStatus" && message.type !== "browseState") return;
  if (message.status.isAvailable && sender.tab?.id) {
    mostRecentStreamingTabId = sender.tab.id;
    chrome.storage.session.set({ mostRecentStreamingTabId });
  }
  if (socket?.readyState !== WebSocket.OPEN) return;
  socket.send(JSON.stringify(message.type === "playerStatus"
    ? { type: "playerStatus", status: message.status }
    : { type: "browseState", browse: message.browse }));
});

chrome.action.onClicked.addListener(() => chrome.runtime.openOptionsPage());

connect();
