import { Chessground } from "chessground";
import { Chess } from "chess.js";

const isTypingTarget = (target) =>
  target instanceof HTMLElement &&
  (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName));

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

    this.handleEvent("best_line_move", ({ from, to, promotion }) => {
      this.applyBestLineMove({ from, to, promotion });
    });

    this.handleEvent("apply_move", ({ from, to, promotion }) => {
      if (this.reviewing) return;
      this.executeMove(from, to, promotion);
    });

    this.handleKeyDown = (event) => {
      if (!this.reviewing) return;
      if (event.defaultPrevented) return;
      if (event.ctrlKey || event.metaKey || event.altKey) return;
      if (isTypingTarget(event.target)) return;

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
        this.pushEvent("chess_fen_invalid", {
          fen,
          message: error && error.message ? error.message : String(error),
        });
      }
    });

    this.handleEvent("opponent_move", ({ from, to, promotion }) => {
      this.applyOpponentMove({ from, to, promotion });
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
    window.removeEventListener("resize", this.repositionPromotion);
    this.repositionPromotion = null;
    this.promotionDialog?.remove();
    this.promotionDialog = null;
  },

  showReviewPosition(fen) {
    if (!this.ground) return;

    try {
      this.chess.load(fen);
    } catch {
      return;
    }

    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground.set({
      fen: this.chess.fen(),
      turnColor,
      movable: { color: null, dests: new Map() },
    });
  },

  applyBestLineMove({ from, to, promotion }) {
    const move = promotion
      ? this.chess.move({ from, to, promotion })
      : this.chess.move({ from, to });

    if (!move) {
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
    const color = this.chess.turn() === "w" ? "white" : "black";
    const dialog = document.createElement("dialog");
    dialog.className = "promotion-dialog";
    dialog.setAttribute("aria-labelledby", "promotion-dialog-title");
    dialog.setAttribute("closedby", "any");

    const title = document.createElement("h2");
    title.id = "promotion-dialog-title";
    title.className = "sr-only";
    title.textContent = "Choose a promotion piece";
    dialog.appendChild(title);

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
    dialog.appendChild(picker);

    // Safari and older engines lack `closedby`: light-dismiss ourselves.
    if (!("closedBy" in HTMLDialogElement.prototype)) {
      dialog.addEventListener("click", (event) => {
        if (event.target === dialog) dialog.close();
      });
    }

    dialog.addEventListener("close", () => {
      // A dismissal (Esc, back gesture, backdrop) leaves the position untouched.
      const dismissed = !!this.pendingPromotion;
      this.pendingPromotion = null;
      if (this.promotionDialog === dialog) this.promotionDialog = null;
      window.removeEventListener("resize", this.repositionPromotion);
      this.repositionPromotion = null;
      dialog.remove();
      if (dismissed && this.ground) this.ground.set({ fen: this.chess.fen() });
    });

    this.pendingPromotion = { orig, dest };
    this.promotionDialog = dialog;
    document.body.appendChild(dialog);
    dialog.showModal();
    this.positionPromotionDialog(dialog);
    this.repositionPromotion = () => this.positionPromotionDialog(dialog);
    window.addEventListener("resize", this.repositionPromotion);
    picker.querySelector("button")?.focus();
  },

  // Anchor the picker to the square the pawn promotes on: horizontally centred
  // on the square, extending towards the middle of the board, clamped to the
  // viewport so it stays reachable at 320px.
  positionPromotionDialog(dialog) {
    if (!this.pendingPromotion || !this.ground) return;

    const { dest } = this.pendingPromotion;
    const board = this.el.getBoundingClientRect();
    const squareSize = board.width / 8;
    const orientation = this.ground.state.orientation || "white";
    const fileIndex = dest.charCodeAt(0) - "a".charCodeAt(0);
    const rank = Number(dest[1]);
    const column = orientation === "white" ? fileIndex : 7 - fileIndex;
    const row = orientation === "white" ? 8 - rank : rank - 1;

    const squareLeft = board.left + column * squareSize;
    const squareTop = board.top + row * squareSize;
    const squareCenterX = squareLeft + squareSize / 2;
    const boardCenterY = board.top + board.height / 2;

    const { width, height } = dialog.getBoundingClientRect();
    const margin = 8;
    const maxLeft = Math.max(margin, window.innerWidth - width - margin);
    const maxTop = Math.max(margin, window.innerHeight - height - margin);

    const preferredTop =
      squareTop + squareSize / 2 < boardCenterY ? squareTop : squareTop + squareSize - height;

    dialog.style.left = `${Math.min(Math.max(squareCenterX - width / 2, margin), maxLeft)}px`;
    dialog.style.top = `${Math.min(Math.max(preferredTop, margin), maxTop)}px`;
  },

  completePromotion(pieceType) {
    const { orig, dest } = this.pendingPromotion;
    this.pendingPromotion = null;
    this.promotionDialog?.close();
    this.executeMove(orig, dest, pieceType);
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

  applyOpponentMove({ from, to, promotion }) {
    const move = promotion
      ? this.chess.move({ from, to, promotion })
      : this.chess.move({ from, to });

    if (!move) {
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
