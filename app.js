"use strict";

// ---- Elements ----
const el = {
  stage: document.getElementById("stage"),
  time: document.getElementById("time"),
  ampm: document.getElementById("ampm"),
  seconds: document.getElementById("seconds"),
  date: document.getElementById("date"),
  controls: document.getElementById("controls"),
  btnFormat: document.getElementById("btn-format"),
  btnSeconds: document.getElementById("btn-seconds"),
  btnBg: document.getElementById("btn-bg"),
  btnFullscreen: document.getElementById("btn-fullscreen"),
  fileBg: document.getElementById("file-bg"),
};

// ---- Settings (persisted) ----
const DEFAULTS = { hour24: false, showSeconds: true, theme: 0, customBg: null };
const settings = loadSettings();

function loadSettings() {
  try {
    return Object.assign({}, DEFAULTS, JSON.parse(localStorage.getItem("clock-settings") || "{}"));
  } catch {
    return Object.assign({}, DEFAULTS);
  }
}
function saveSettings() {
  try { localStorage.setItem("clock-settings", JSON.stringify(settings)); } catch {}
}

// ---- Background themes (CSS gradients = no external files, works offline) ----
const THEMES = [
  "linear-gradient(160deg, #16324f 0%, #0d2034 45%, #081320 100%)",   // deep dusk blue
  "linear-gradient(160deg, #2b1c44 0%, #20143a 45%, #120b22 100%)",   // twilight purple
  "linear-gradient(160deg, #103a34 0%, #0c2a27 45%, #06181a 100%)",   // forest teal
  "linear-gradient(160deg, #3a2218 0%, #281410 45%, #160a08 100%)",   // warm ember
  "linear-gradient(160deg, #1b1f24 0%, #14171b 45%, #0a0c0f 100%)",   // graphite
];

function applyBackground() {
  if (settings.customBg) {
    el.stage.style.backgroundImage = `url("${settings.customBg}")`;
  } else {
    el.stage.style.backgroundImage = THEMES[settings.theme % THEMES.length];
  }
}

// ---- Clock tick ----
const DAYS = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
const MONTHS = ["January","February","March","April","May","June","July",
                "August","September","October","November","December"];

function pad(n) { return n < 10 ? "0" + n : "" + n; }

function tick() {
  const now = new Date();
  let h = now.getHours();
  const m = now.getMinutes();
  const s = now.getSeconds();

  if (settings.hour24) {
    el.time.textContent = pad(h) + ":" + pad(m);
    el.ampm.textContent = "";
    el.ampm.style.display = "none";
  } else {
    const ampm = h >= 12 ? "PM" : "AM";
    let h12 = h % 12;
    if (h12 === 0) h12 = 12;
    el.time.textContent = h12 + ":" + pad(m);
    el.ampm.textContent = ampm;
    el.ampm.style.display = "";
  }

  el.seconds.textContent = pad(s);
  el.date.textContent = `${DAYS[now.getDay()]}, ${MONTHS[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()}`;
}

// Align ticks to the second boundary for crisp updates
function startClock() {
  tick();
  const drift = 1000 - (Date.now() % 1000);
  setTimeout(() => { tick(); setInterval(tick, 1000); }, drift);
}

// ---- UI sync ----
function syncButtons() {
  el.btnFormat.textContent = settings.hour24 ? "24h" : "12h";
  el.btnFormat.classList.toggle("active", settings.hour24);
  el.btnSeconds.classList.toggle("active", settings.showSeconds);
  document.body.classList.toggle("no-seconds", !settings.showSeconds);
}

// ---- Events ----
el.btnFormat.addEventListener("click", () => {
  settings.hour24 = !settings.hour24;
  saveSettings(); tick(); syncButtons();
});

el.btnSeconds.addEventListener("click", () => {
  settings.showSeconds = !settings.showSeconds;
  saveSettings(); syncButtons();
});

el.btnBg.addEventListener("click", () => {
  settings.customBg = null;            // cycling themes clears custom photo
  settings.theme = (settings.theme + 1) % THEMES.length;
  saveSettings(); applyBackground();
});

el.fileBg.addEventListener("change", (e) => {
  const file = e.target.files && e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    settings.customBg = reader.result;  // data URL — persists & works offline
    saveSettings(); applyBackground();
  };
  reader.readAsDataURL(file);
});

el.btnFullscreen.addEventListener("click", toggleFullscreen);

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen?.().catch(() => {});
  } else {
    document.exitFullscreen?.();
  }
}

// Double-click anywhere = fullscreen toggle
document.addEventListener("dblclick", toggleFullscreen);

// Press "f" for fullscreen
document.addEventListener("keydown", (e) => {
  if (e.key === "f" || e.key === "F") toggleFullscreen();
});

// ---- Auto-hide controls ----
let hideTimer = null;
function showControls() {
  document.body.classList.add("show-controls");
  document.body.style.cursor = "default";
  clearTimeout(hideTimer);
  hideTimer = setTimeout(() => {
    document.body.classList.remove("show-controls");
    document.body.style.cursor = "none";
  }, 2500);
}
document.addEventListener("mousemove", showControls);
document.addEventListener("touchstart", showControls, { passive: true });

// ---- Service worker (offline / installable) ----
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  });
}

// ---- Init ----
applyBackground();
syncButtons();
startClock();
showControls();
