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
  btnGear: document.getElementById("btn-gear"),
};

// ---- Settings (persisted) ----
// bgIndex: 0 = daily photo, 1..N = gradient themes (THEMES[bgIndex-1])
const DEFAULTS = { hour24: false, showSeconds: true, bgIndex: 0, customBg: null };
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

// ---- Background themes (CSS gradients — no external files, work offline) ----
const THEMES = [
  "linear-gradient(160deg, #16324f 0%, #0d2034 45%, #081320 100%)",   // deep dusk blue
  "linear-gradient(160deg, #2b1c44 0%, #20143a 45%, #120b22 100%)",   // twilight purple
  "linear-gradient(160deg, #103a34 0%, #0c2a27 45%, #06181a 100%)",   // forest teal
  "linear-gradient(160deg, #3a2218 0%, #281410 45%, #160a08 100%)",   // warm ember
  "linear-gradient(160deg, #1b1f24 0%, #14171b 45%, #0a0c0f 100%)",   // graphite
];
const DAILY_FALLBACK = THEMES[0];

function todayStamp() {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

// Apply whichever background the settings call for. The frosted card behind the
// clock keeps the white numbers readable, so no per-image color logic is needed.
function applyBackground(bust) {
  if (settings.customBg) {
    el.stage.style.backgroundImage = `url("${settings.customBg}")`;
  } else if (settings.bgIndex === 0) {
    const v = bust || todayStamp();          // cache-bust by day (or timestamp on refresh)
    loadDailyImage(`images/today.jpg?d=${encodeURIComponent(v)}`);
  } else {
    el.stage.style.backgroundImage = THEMES[(settings.bgIndex - 1) % THEMES.length];
  }
}

// Load the daily photo; fall back to a gradient if it's missing/offline.
function loadDailyImage(url) {
  const img = new Image();
  img.onload = () => { el.stage.style.backgroundImage = `url("${url}")`; };
  img.onerror = () => { el.stage.style.backgroundImage = DAILY_FALLBACK; };
  img.src = url;
}

// ---- Clock tick ----
const DAYS = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
const MONTHS = ["January","February","March","April","May","June","July",
                "August","September","October","November","December"];

function pad(n) { return n < 10 ? "0" + n : "" + n; }

let lastDay = todayStamp();
function tick() {
  const now = new Date();
  let h = now.getHours();
  const m = now.getMinutes();
  const s = now.getSeconds();

  if (settings.hour24) {
    el.time.textContent = pad(h) + ":" + pad(m);
    el.ampm.style.display = "none";
  } else {
    el.ampm.textContent = h >= 12 ? "PM" : "AM";
    let h12 = h % 12; if (h12 === 0) h12 = 12;
    el.time.textContent = h12 + ":" + pad(m);
    el.ampm.style.display = "";
  }
  el.seconds.textContent = pad(s);
  el.date.textContent = `${DAYS[now.getDay()]}, ${MONTHS[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()}`;

  // At local midnight, refresh the daily photo for the new day.
  const stamp = todayStamp();
  if (stamp !== lastDay) {
    lastDay = stamp;
    if (!settings.customBg && settings.bgIndex === 0) applyBackground();
  }
}

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

// Theme button cycles: Daily photo -> gradient 1..N -> Daily photo
el.btnBg.addEventListener("click", () => {
  settings.customBg = null;
  settings.bgIndex = (settings.bgIndex + 1) % (THEMES.length + 1);
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
  if (!document.fullscreenElement) document.documentElement.requestFullscreen?.().catch(() => {});
  else document.exitFullscreen?.();
}
document.addEventListener("dblclick", toggleFullscreen);
document.addEventListener("keydown", (e) => { if (e.key === "f" || e.key === "F") toggleFullscreen(); });

// When the window regains focus, pick up a freshly-downloaded daily photo.
document.addEventListener("visibilitychange", () => {
  if (!document.hidden && !settings.customBg && settings.bgIndex === 0) {
    applyBackground(String(Date.now()));
  }
});

// ---- Gear icon toggle ----
function toggleControls() {
  const open = document.body.classList.toggle("show-controls");
  el.btnGear.classList.toggle("active", open);
}

el.btnGear.addEventListener("click", (e) => {
  e.stopPropagation();
  toggleControls();
});

document.addEventListener("click", (e) => {
  if (document.body.classList.contains("show-controls") &&
      !el.controls.contains(e.target) &&
      e.target !== el.btnGear) {
    document.body.classList.remove("show-controls");
    el.btnGear.classList.remove("active");
  }
});

// ---- Service worker (offline / installable) ----
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}

// ---- Init ----
applyBackground();
syncButtons();
startClock();
// A new day's image may still be downloading at launch — re-check shortly after.
setTimeout(() => {
  if (!settings.customBg && settings.bgIndex === 0) applyBackground(String(Date.now()));
}, 8000);
