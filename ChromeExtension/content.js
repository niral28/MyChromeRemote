const supportedService = location.hostname.includes("hulu.com") ? "Hulu"
  : location.hostname.includes("peacocktv.com") ? "Peacock"
  : location.hostname.includes("tv.apple.com") ? "Apple TV"
  : location.hostname.includes("youtube.com") ? "YouTube"
  : "Disney+";

function video() {
  return [...document.querySelectorAll("video")]
    .sort((a, b) => (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight))[0];
}

function press(key) {
  for (const type of ["keydown", "keyup"]) {
    document.dispatchEvent(new KeyboardEvent(type, { key, code: key, bubbles: true }));
  }
}

function execute(command) {
  const player = video();
  if (["back", "home", "up", "down", "left", "right", "select", "openSearch", "submitSearch"].includes(command)) {
    browse(command);
    return;
  }
  if (!player) return;

  switch (command) {
    case "togglePlayback":
      player.paused ? player.play().catch(() => press(" ")) : player.pause();
      break;
    case "mute":
      player.muted = !player.muted;
      break;
    case "volumeUp":
      player.volume = Math.min(1, player.volume + 0.1);
      break;
    case "volumeDown":
      player.volume = Math.max(0, player.volume - 0.1);
      break;
    case "seekBackward":
      player.currentTime = Math.max(0, player.currentTime - 15);
      break;
    case "seekForward":
      player.currentTime = Math.min(player.duration || Infinity, player.currentTime + 15);
      break;
    case "toggleFullscreen":
      if (document.fullscreenElement) document.exitFullscreen();
      else player.requestFullscreen().catch(() => press("f"));
      break;
    case "next":
      press("n");
      break;
    case "previous":
      press("p");
      break;
  }
  report();
}

let focusedIndex = 0;
function tiles() {
  const linksWithArtwork = [...document.querySelectorAll("a[href]")].filter((element) => {
    const rect = element.getBoundingClientRect();
    return element.querySelector("img") && rect.width > 100 && rect.height > 80;
  });
  const labeledControls = [...document.querySelectorAll("button, a[href]")]
    .filter((element) => element.getAttribute("aria-label") || element.textContent.trim())
    .filter((element) => element.getBoundingClientRect().width > 30);
  return [...new Set([...labeledControls.slice(0, 12), ...linksWithArtwork])].slice(0, 36);
}
function reportBrowse() {
  const items = tiles().map((element, index) => ({
    id: String(index),
    title: element.getAttribute("aria-label") || element.querySelector("img")?.alt || element.textContent.trim().slice(0, 80) || "Disney+ title",
    artworkURL: element.querySelector("img")?.currentSrc || element.querySelector("img")?.src || null
  })).filter((item) => item.title);
  chrome.runtime.sendMessage({ type: "browseState", browse: { title: title(), tiles: items, focusedTileID: items[focusedIndex]?.id || null } });
}
function browse(command) {
  const items = tiles();
  if (command === "back") history.back();
  else if (command === "home") location.assign("https://www.disneyplus.com/home");
  else if (command === "openSearch") (document.querySelector('input[type="search"], input[placeholder*="Search" i]') || document.querySelector("button[aria-label*='Search' i]"))?.click();
  else if (command === "select") items[focusedIndex]?.click();
  else if (items.length) {
    const delta = command === "left" || command === "up" ? -1 : 1;
    focusedIndex = (focusedIndex + delta + items.length) % items.length;
    items[focusedIndex].scrollIntoView({ block: "center", inline: "center" });
  }
  reportBrowse();
}
function search(query) {
  const input = document.querySelector('input[type="search"], input[placeholder*="Search" i]');
  if (!input) return browse("openSearch");
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
  setter.call(input, query);
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
  input.focus();
  reportBrowse();
}

function title() {
  return document.querySelector("[data-testid*='title']")?.textContent?.trim() ||
    document.title.replace(/\s*[|–-]\s*(Hulu|Disney\+|Peacock|Apple TV|YouTube).*$/i, "").trim();
}

function report() {
  const player = video();
  chrome.runtime.sendMessage({
    type: "playerStatus",
    status: {
      service: supportedService,
      title: title(),
      isAvailable: Boolean(player)
    }
  });
}

chrome.runtime.onMessage.addListener((message) => {
  if (message.type === "execute") execute(message.command);
  if (message.type === "search") search(message.query);
  if (message.type === "selectTile") { focusedIndex = Number(message.tileID) || 0; browse("select"); }
});

new MutationObserver(report).observe(document.documentElement, { childList: true, subtree: true });
setInterval(report, 5000);
setInterval(reportBrowse, 3000);
report();
reportBrowse();
