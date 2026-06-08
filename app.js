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

async function triggerFileDownload(url, filename) {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error("Download failed");
    const blob = await response.blob();
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = objectUrl;
    link.download = filename;
    link.rel = "noopener";
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(objectUrl);
  } catch {
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    link.rel = "noopener";
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    link.remove();
  }
}

function wireFileDownloads() {
  document.querySelectorAll("[data-file-download]").forEach((el) => {
    el.addEventListener("click", (event) => {
      event.preventDefault();
      const url = el.getAttribute("href");
      const filename = el.dataset.fileName || url.split("/").pop();
      if (!url || !filename) return;
      triggerFileDownload(url, filename);
    });
  });
}

const WELCOME_CLICKS_TO_TOGGLE = 3;

function bumpWelcomeTitle(title) {
  title.classList.remove("welcome-title--bump");
  void title.offsetWidth;
  title.classList.add("welcome-title--bump");
}

function wireWelcomeEasterEgg() {
  const title = document.getElementById("welcome-title");
  if (!title) return;

  let clickCount = 0;

  const handleActivate = () => {
    playClickSound("soft");
    bumpWelcomeTitle(title);
    clickCount += 1;

    if (clickCount >= WELCOME_CLICKS_TO_TOGGLE) {
      clickCount = 0;
      document.body.classList.toggle("cartoon-mode");
    }
  };

  title.addEventListener("click", handleActivate);
  title.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    handleActivate();
  });
  title.addEventListener("animationend", (event) => {
    if (event.animationName === "welcome-bump") {
      title.classList.remove("welcome-title--bump");
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  wireTabs();
  wireShortcuts();
  wireButtonSounds();
  wireFileDownloads();
  wireWelcomeEasterEgg();
  setActiveView(getRouteFromHash());
});
