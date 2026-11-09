import { Chessground } from "chessground";
import { Chess } from "chess.js";

export const ChessBoard = {
  mounted() {
    this.chess = new Chess();
    this.ground = null;
    this.playerColor = "white";
    this.reviewing = false;

    this.handleEvent("init_board", (payload) => {
      this.reviewing = false;
      this.initBoard(payload);
    });

    this.handleEvent("review_position", ({ fen }) => {
      this.reviewing = true;
      this.showReviewPosition(fen);
    });

    this.handleEvent("best_line_move", ({ from, to, promotion, san }) => {
      this.applyBestLineMove({ from, to, promotion, san });
    });

    this.handleEvent("apply_move", ({ from, to, promotion }) => {
      if (this.reviewing) return;
      this.executeMove(from, to, promotion);
    });

    this.handleKeyDown = (event) => {
      if (this.pendingPromotion) {
        if (event.key === "Escape") {
          event.preventDefault();
          this.cancelPromotion();
        }
        return;
      }

      if (!this.reviewing) return;

      if (event.key === "ArrowLeft") {
        event.preventDefault();
        this.pushEvent("review_prev", {});
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        this.pushEvent("review_next", {});
      } else if (event.key === "Home") {
        event.preventDefault();
        this.pushEvent("review_start", {});
      } else if (event.key === "End") {
        event.preventDefault();
        this.pushEvent("review_end", {});
      }
    };

    window.addEventListener("keydown", this.handleKeyDown);

    this.handleEvent("set_fen", ({ fen }) => {
      try {
        this.chess.load(fen);

        if (this.ground) {
          const currentTurnColor = this.chess.turn() === "w" ? "white" : "black";
          this.ground.set({
            fen: fen,
            turnColor: currentTurnColor,
            movable: {
              color: currentTurnColor,
              dests: this.getValidDests(),
            },
          });
        } else {
          this.initBoard({
            fen,
            orientation: "white",
            player_color: "white",
          });
        }
      } catch (error) {
        console.error("Invalid FEN string submitted:", error);
        alert("Invalid FEN configuration!");
      }
    });

    this.handleEvent("opponent_move", ({ from, to, promotion, san }) => {
      this.applyOpponentMove({ from, to, promotion, san });
    });

    this.handleEvent("resume_board", () => {
      this.resumeBoard();
    });

    this.initBoard({
      fen: this.chess.fen(),
      orientation: "white",
      player_color: "white",
    });
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown);
  },

  showReviewPosition(fen) {
    if (!this.ground) return;

    try {
      this.chess.load(fen);
    } catch (error) {
      console.error("Invalid review FEN from server:", fen, error);
      return;
    }

    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground.set({
      fen: this.chess.fen(),
      turnColor,
      movable: { color: null, dests: new Map() },
    });
  },

  applyBestLineMove({ from, to, promotion, san }) {
    const move = promotion
      ? this.chess.move({ from, to, promotion })
      : this.chess.move({ from, to });

    if (!move) {
      console.error("Best-line move rejected by chess.js", { from, to, promotion, san });
      return;
    }

    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground.set({
      fen: this.chess.fen(),
      turnColor,
      movable: { color: null, dests: new Map() },
    });

    this.pushEvent("best_line_move_applied", {
      fen: this.chess.fen(),
      san: move.san,
    });
  },

  initBoard({ fen, orientation, player_color, blocked }) {
    try {
      this.chess.load(fen);
    } catch (error) {
      console.error("Invalid FEN from server:", fen, error);
      this.pushEvent("chess_fen_invalid", {
        fen: fen,
        message: error && error.message ? error.message : String(error),
      });
      return;
    }

    this.playerColor = player_color;

    if (this.ground) {
      this.ground.destroy();
    }

    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground = Chessground(this.el, {
      fen: fen,
      orientation: orientation,
      turnColor: turnColor,
      movable: {
        color: blocked ? null : player_color,
        free: false,
        dests: blocked ? new Map() : this.getValidDests(),
      },
      events: {
        move: (orig, dest, _capturedPiece) => {
          this.handleMove(orig, dest);
        },
      },
    });
  },

  getValidDests() {
    const dests = new Map();

    this.chess.moves({ verbose: true }).forEach((m) => {
      if (!dests.has(m.from)) dests.set(m.from, []);
      dests.get(m.from).push(m.to);
    });

    return dests;
  },

  handleMove(orig, dest) {
    const piece = this.ground.state.pieces.get(dest);
    const destRank = dest[1];
    if (piece?.role === "pawn" && (destRank === "1" || destRank === "8")) {
      this.showPromotionDialog(orig, dest);
      return;
    }
    this.executeMove(orig, dest);
  },

  showPromotionDialog(orig, dest) {
    this.pendingPromotion = { orig, dest };
    this.previousFocus = document.activeElement;
    const color = this.chess.turn() === "w" ? "white" : "black";
    const overlay = document.createElement("div");
    overlay.className = "promotion-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", "Choose a promotion piece");
    const picker = document.createElement("div");
    picker.className = "promotion-picker";
    const pieces = [
      { type: "queen", code: "q" },
      { type: "rook", code: "r" },
      { type: "bishop", code: "b" },
      { type: "knight", code: "n" },
    ];
    pieces.forEach(({ type, code }) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = `promotion-piece ${type} ${color}`;
      btn.setAttribute("aria-label", `Promote to ${type}`);
      btn.addEventListener("click", () => this.completePromotion(code));
      picker.appendChild(btn);
    });
    overlay.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        this.cancelPromotion();
        return;
      }

      if (event.key !== "Tab") return;

      const buttons = Array.from(picker.querySelectorAll("button"));
      const first = buttons[0];
      const last = buttons[buttons.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    });
    overlay.appendChild(picker);
    const container = this.el.parentElement;
    container.style.position = "relative";
    container.appendChild(overlay);
    picker.querySelector("button")?.focus();
  },

  cancelPromotion() {
    this.pendingPromotion = null;
    const overlay = this.el.parentElement?.querySelector(".promotion-overlay");
    if (overlay) overlay.remove();
    this.restoreFocus();
  },

  restoreFocus() {
    if (this.previousFocus instanceof HTMLElement) {
      this.previousFocus.focus();
    } else {
      document.getElementById("move-input")?.focus();
    }

    this.previousFocus = null;
  },

  completePromotion(pieceType) {
    const { orig, dest } = this.pendingPromotion;
    this.pendingPromotion = null;
    const picker = this.el.parentElement?.querySelector(".promotion-overlay");
    if (picker) picker.remove();
    this.executeMove(orig, dest, pieceType);
    document.getElementById("move-input")?.focus();
  },

  executeMove(orig, dest, promotion) {
    const prevFen = this.chess.fen();
    const move = promotion
      ? this.chess.move({ from: orig, to: dest, promotion })
      : this.chess.move({ from: orig, to: dest });

    if (move) {
      const isTrainer = !!(this.el.dataset && this.el.dataset.endgameId);
      const eventName = isTrainer ? "endgame_move_played" : "move_played";

      const payload = {
        from: orig,
        to: dest,
        prev_fen: prevFen,
        fen: this.chess.fen(),
        san: move.san,
        promotion: promotion || null,
        draw: this.chess.isDraw(),
        check: this.chess.isCheck(),
        checkmate: this.chess.isCheckmate(),
      };

      if (isTrainer) {
        payload.endgame_id = this.el.dataset.endgameId;
      }

      this.pushEvent(eventName, payload);

      const nextTurnColor = this.chess.turn() === "w" ? "white" : "black";

      this.ground.set({
        turnColor: nextTurnColor,
        fen: this.chess.fen(),
        movable: isTrainer
          ? { color: null, dests: new Map() }
          : { color: nextTurnColor, dests: this.getValidDests() },
      });

      return true;
    } else {
      this.ground.set({ fen: this.chess.fen() });
      this.pushEvent("move_input_error", {
        message: "That move is not legal in this position.",
      });
      return false;
    }
  },

  applyOpponentMove({ from, to, promotion, san }) {
    const move = promotion
      ? this.chess.move({ from, to, promotion })
      : this.chess.move({ from, to });

    if (!move) {
      console.error("Opponent move rejected by chess.js", { from, to, promotion, san });
      return;
    }

    const nextTurnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground.set({
      fen: this.chess.fen(),
      turnColor: nextTurnColor,
      movable: { color: null, dests: new Map() },
    });

    this.pushEvent("opponent_reply_applied", {
      fen: this.chess.fen(),
      san: move.san,
      draw: this.chess.isDraw(),
      check: this.chess.isCheck(),
      checkmate: this.chess.isCheckmate(),
    });
  },

  resumeBoard() {
    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground.set({
      fen: this.chess.fen(),
      turnColor,
      movable: {
        color: this.playerColor || turnColor,
        free: false,
        dests: this.getValidDests(),
      },
    });
  },
};
