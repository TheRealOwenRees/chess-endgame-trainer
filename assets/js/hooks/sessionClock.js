// Ticks a session clock in mm:ss from its `data-started-at` (unix ms) so the
// timer advances without a server round-trip. The server renders the initial
// value, so a re-render stays in sync with the client.
export const SessionClock = {
  mounted() {
    this.tick();
    this.timer = setInterval(() => this.tick(), 1000);
  },

  updated() {
    this.tick();
  },

  destroyed() {
    clearInterval(this.timer);
  },

  tick() {
    const startedAt = parseInt(this.el.dataset.startedAt, 10);
    if (!startedAt) return;

    const total = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
    const minutes = String(Math.floor(total / 60)).padStart(2, "0");
    const seconds = String(total % 60).padStart(2, "0");
    this.el.textContent = `${minutes}:${seconds}`;
  },
};
