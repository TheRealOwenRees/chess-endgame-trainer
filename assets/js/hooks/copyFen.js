export const CopyFen = {
  mounted() {
    this.status = document.getElementById("copy-fen-status");
    this.originalLabel = this.el.getAttribute("aria-label");
    this.originalTitle = this.el.getAttribute("title");
    this.timer = null;

    this.onClick = async (event) => {
      event.preventDefault();

      try {
        if (!navigator.clipboard || !navigator.clipboard.writeText) {
          throw new Error("Clipboard API unavailable");
        }

        await navigator.clipboard.writeText(this.el.dataset.fen);
        this.announce("Copied!", "FEN copied", "text-success-text");
      } catch {
        this.announce("Couldn't copy", "Copy failed", "text-error-text");
      }
    };

    this.el.addEventListener("click", this.onClick);
  },

  announce(message, label, colorClass) {
    if (this.status) {
      this.status.textContent = message;
      this.status.classList.remove("text-success-text", "text-error-text");
      this.status.classList.add(colorClass);
    }

    this.el.setAttribute("aria-label", label);
    this.el.setAttribute("title", label);

    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.restore(), 2000);
  },

  restore() {
    this.timer = null;

    if (this.status) {
      this.status.textContent = "";
      this.status.classList.remove("text-success-text", "text-error-text");
    }

    this.setOrRemoveAttribute("aria-label", this.originalLabel);
    this.setOrRemoveAttribute("title", this.originalTitle);
  },

  setOrRemoveAttribute(name, value) {
    if (value === null) {
      this.el.removeAttribute(name);
    } else {
      this.el.setAttribute(name, value);
    }
  },

  destroyed() {
    clearTimeout(this.timer);
    this.timer = null;
    this.restore();
    this.el.removeEventListener("click", this.onClick);
  },
};
