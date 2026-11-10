// Cookieless Matomo for anonymous public pages. The server only renders the
// #matomo-config element for anonymous visitors, so account and admin pages
// never load a tracker.

const OPT_OUT_KEY = "matomo_optout";

export function isOptedOut() {
  try {
    return localStorage.getItem(OPT_OUT_KEY) === "1";
  } catch (_error) {
    // If storage is unavailable we cannot remember an opt-out. Fail closed.
    return true;
  }
}

function setOptedOut(optedOut) {
  try {
    if (optedOut) {
      localStorage.setItem(OPT_OUT_KEY, "1");
    } else {
      localStorage.removeItem(OPT_OUT_KEY);
    }
  } catch (_error) {
    // Nothing else to do; the current page remains untracked.
  }
}

function updateUI() {
  const optOutButton = document.getElementById("analytics-opt-out");
  const optInButton = document.getElementById("analytics-opt-in");
  const status = document.getElementById("analytics-status");

  if (!optOutButton && !optInButton && !status) return;

  const optedOut = isOptedOut();

  if (optOutButton) optOutButton.hidden = optedOut;
  if (optInButton) optInButton.hidden = !optedOut;
  if (status) {
    status.textContent = optedOut
      ? "Analytics is currently off in this browser."
      : "Analytics is currently on in this browser.";
  }
}

function isPrivatePath() {
  return window.location.pathname.startsWith("/admin");
}

function trackPageView() {
  if (isPrivatePath() || isOptedOut() || !window._paq) return;

  window._paq.push(["setCustomUrl", window.location.href]);
  window._paq.push(["trackPageView"]);
}

function loadTracker() {
  const config = document.getElementById("matomo-config");
  if (!config || isPrivatePath() || isOptedOut()) return;

  const url = config.dataset.url;
  const siteId = config.dataset.siteId;
  if (!url || !siteId) return;

  const _paq = (window._paq = window._paq || []);
  _paq.push(["disableCookies"]);
  _paq.push(["setDoNotTrack", true]);
  _paq.push(["trackPageView"]);
  _paq.push(["setTrackerUrl", `${url}matomo.php`]);
  _paq.push(["setSiteId", siteId]);

  const script = document.createElement("script");
  script.async = true;
  script.src = `${url}matomo.js`;
  document.head.appendChild(script);
}

function handleClick(event) {
  const target = event.target instanceof Element ? event.target : null;
  if (!target) return;

  if (target.closest("#analytics-opt-out")) {
    event.preventDefault();
    setOptedOut(true);
    updateUI();
    return;
  }

  if (target.closest("#analytics-opt-in")) {
    event.preventDefault();
    setOptedOut(false);
    // The tracker was not loaded while opted out. Reload to start it.
    window.location.reload();
  }
}

export function initAnalytics() {
  if (window.__matomoInitialised) return;
  window.__matomoInitialised = true;

  loadTracker();
  window.addEventListener("phx:navigate", trackPageView);
  document.addEventListener("click", handleClick);
  updateUI();
}
