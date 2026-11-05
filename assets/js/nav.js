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
