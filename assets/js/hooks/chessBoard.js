import { Chessground } from "chessground";
import { Chess } from "chess.js";

export const ChessBoard = {
  mounted() {
    this.chess = new Chess();
    this.ground = null;
    this.playerColor = "white";

    this.handleEvent("init_board", (payload) => {
      this.initBoard(payload);
    });

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
    const color = this.chess.turn() === "w" ? "white" : "black";
    const overlay = document.createElement("div");
    overlay.className = "promotion-overlay";
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
      btn.className = `promotion-piece ${type} ${color}`;
      btn.addEventListener("click", () => this.completePromotion(code));
      picker.appendChild(btn);
    });
    overlay.appendChild(picker);
    const boardContainer = this.el.closest(".shadow-inner");
    boardContainer.style.position = "relative";
    boardContainer.appendChild(overlay);
  },

  completePromotion(pieceType) {
    const { orig, dest } = this.pendingPromotion;
    this.pendingPromotion = null;
    const picker = this.el.closest(".shadow-inner")?.querySelector(".promotion-overlay");
    if (picker) picker.remove();
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
    } else {
      this.ground.set({ fen: this.chess.fen() });
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
