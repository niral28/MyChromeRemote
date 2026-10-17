const status = document.querySelector("#status");

async function refresh() {
  const { token } = await chrome.storage.local.get("token");
  status.textContent = token
    ? "Status: paired with TV Remote on this Mac."
    : "Status: not paired yet. Keep TV Remote open and reload the extension.";
}

document.querySelector("#reset").addEventListener("click", async () => {
  await chrome.storage.local.remove(["token", "pairingCode"]);
  status.textContent = "Pairing forgotten. Reload the extension to pair again automatically.";
});

refresh();
