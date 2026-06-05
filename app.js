const ROUTES = ["menu", "og", "pobierz", "licencja"];

let audioCtx;

function getAudioContext() {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return null;
  if (!audioCtx) audioCtx = new AudioContextClass();
  if (audioCtx.state === "suspended") {
    audioCtx.resume().catch(() => {});
  }
  return audioCtx;
}

function playClickSound(type = "soft") {
  const ctx = getAudioContext();
  if (!ctx) return;

  const now = ctx.currentTime;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  const isTab = type === "tab";
  osc.type = isTab ? "triangle" : "sine";
  osc.frequency.setValueAtTime(isTab ? 360 : 300, now);
  osc.frequency.exponentialRampToValueAtTime(isTab ? 500 : 420, now + 0.06);

  const peakGain = isTab ? 0.14 : 0.12;

  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(peakGain, now + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.1);

  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(now);
  osc.stop(now + 0.11);
}

function setActiveView(route) {
  const safeRoute = ROUTES.includes(route) ? route : "menu";
  const tabs = document.querySelectorAll(".tab[data-route]");
  const views = document.querySelectorAll("[data-view]");

  tabs.forEach((tab) => {
    tab.setAttribute("aria-selected", String(tab.dataset.route === safeRoute));
  });

  views.forEach((view) => {
    const isActive = view.dataset.view === safeRoute;
    view.hidden = !isActive;
    view.classList.remove("view--animate");

    if (isActive) {
      requestAnimationFrame(() => {
        view.classList.add("view--animate");
        const tiles = view.querySelectorAll(".tile-animate");
        tiles.forEach((tile, index) => {
          tile.style.setProperty("--i", String(index));
        });
      });
    }
  });

  if (window.location.hash !== `#${safeRoute}`) {
    window.location.hash = safeRoute;
  }
}

function getRouteFromHash() {
  const hash = (window.location.hash || "").replace("#", "").trim();
  return ROUTES.includes(hash) ? hash : "menu";
}

function wireTabs() {
  document.querySelectorAll(".tab[data-route]").forEach((tab) => {
    tab.addEventListener("click", () => {
      playClickSound("tab");
      setActiveView(tab.dataset.route);
    });
  });

  window.addEventListener("hashchange", () => setActiveView(getRouteFromHash()));
}

function wireShortcuts() {
  window.addEventListener("keydown", (e) => {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.key === "1") setActiveView("menu");
    if (e.key === "2") setActiveView("og");
    if (e.key === "3") setActiveView("pobierz");
    if (e.key === "4") setActiveView("licencja");
  });
}

function wireButtonSounds() {
  const clickable = document.querySelectorAll("button:not(.tab), .btn, a.btn");
  clickable.forEach((el) => {
    el.addEventListener("click", () => playClickSound("soft"));
  });
}

document.addEventListener("DOMContentLoaded", () => {
  wireTabs();
  wireShortcuts();
  wireButtonSounds();
  setActiveView(getRouteFromHash());
});
