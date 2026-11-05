// Plain-DOM mobile navigation. It lives outside the LiveView hook system so it
// also runs on controller-rendered pages such as the landing page.

const WRAP = ".nav-wrap";
const TOGGLE = ".menu-button";
const LINKS = ".nav-links";

const setOpen = (open) => {
  const wrap = document.querySelector(WRAP);
  const links = wrap?.querySelector(LINKS);
  const button = wrap?.querySelector(TOGGLE);

  if (!links) return;

  links.classList.toggle("open", open);
  button?.setAttribute("aria-expanded", String(open));
};

document.addEventListener("click", (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (!target) return;

  if (target.closest(TOGGLE)) {
    const links = document.querySelector(LINKS);
    setOpen(!links?.classList.contains("open"));
    return;
  }

  if (target.closest(`${LINKS} a`)) {
    setOpen(false);
    return;
  }

  if (!target.closest(WRAP)) {
    setOpen(false);
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    setOpen(false);
  }
});

// Flash toasts also render on controller pages (the landing page, after logging
// out, for example), where there is no LiveView to handle the component's
// phx-click. Dismiss them with plain DOM there; LiveView pages keep clearing
// the server-side flash through `lv:clear-flash`.
document.addEventListener("click", (event) => {
  const target = event.target instanceof Element ? event.target : null;
  const flash = target?.closest("[data-flash-dismiss]");
  if (!flash) return;
  if (window.liveSocket?.isConnected?.()) return;

  flash.remove();
});

// Auto-dismiss real flash messages after a few seconds. Synthetic clicks reuse
// the manual dismiss path, so LiveView pages also clear the server-side flash.
// The connectivity notices (`client-error`/`server-error`) start hidden and are
// left alone: they should stay until the connection recovers.
const FLASH_TIMEOUT_MS = 5000;
const scheduledFlashes = new WeakSet();

const scheduleFlashDismiss = (flash) => {
  if (scheduledFlashes.has(flash) || flash.hasAttribute("hidden")) return;

  scheduledFlashes.add(flash);
  setTimeout(() => flash.click(), FLASH_TIMEOUT_MS);
};

const scheduleFlashes = (root) => {
  if (root.matches?.("[data-flash-dismiss]")) scheduleFlashDismiss(root);
  root.querySelectorAll?.("[data-flash-dismiss]").forEach(scheduleFlashDismiss);
};

document.querySelectorAll("[data-flash-dismiss]").forEach(scheduleFlashDismiss);

// Flashes rendered later (LiveView updates, live navigation) arrive after the
// initial pass, so watch for them.
new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    for (const node of mutation.addedNodes) {
      if (node instanceof Element) scheduleFlashes(node);
    }
  }
}).observe(document.body, { childList: true, subtree: true });
