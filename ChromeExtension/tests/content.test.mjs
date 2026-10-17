import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const player = {
  paused: true,
  muted: false,
  volume: 0.5,
  currentTime: 40,
  duration: 100,
  clientWidth: 100,
  clientHeight: 100,
  play() { this.paused = false; return Promise.resolve(); },
  pause() { this.paused = true; },
  requestFullscreen() { return Promise.resolve(); }
};
const document = {
  title: "Example | Hulu",
  fullscreenElement: null,
  documentElement: {},
  querySelectorAll(selector) { return selector === "video" ? [player] : []; },
  querySelector() { return null; },
  dispatchEvent() {},
  exitFullscreen() {}
};
const context = {
  chrome: { runtime: { sendMessage() {}, onMessage: { addListener() {} } } },
  document,
  location: { hostname: "www.hulu.com" },
  MutationObserver: class { observe() {} },
  setInterval() {},
  KeyboardEvent: class {}
};
vm.createContext(context);
const source = `${fs.readFileSync(new URL("../content.js", import.meta.url), "utf8")}\nglobalThis.adapter = { execute };`;
vm.runInContext(source, context);

context.adapter.execute("seekForward");
assert.equal(player.currentTime, 55);
context.adapter.execute("seekBackward");
assert.equal(player.currentTime, 40);
context.adapter.execute("mute");
assert.equal(player.muted, true);
context.adapter.execute("volumeUp");
assert.equal(player.volume, 0.6);
context.adapter.execute("togglePlayback");
await Promise.resolve();
assert.equal(player.paused, false);
