import { Chessground } from "chessground";
import { Chess } from "chess.js";

export const ChessBoard = {
  mounted() {
    this.chess = new Chess();
    this.ground = null;

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

    this.initBoard({
      fen: this.chess.fen(),
      orientation: "white",
      player_color: "white",
    });
  },

  initBoard({ fen, orientation, player_color }) {
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

    if (this.ground) {
      this.ground.destroy();
    }

    const turnColor = this.chess.turn() === "w" ? "white" : "black";

    this.ground = Chessground(this.el, {
      fen: fen,
      orientation: orientation,
      turnColor: turnColor,
      movable: {
        color: player_color,
        free: false,
        dests: this.getValidDests(),
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
    const move = this.chess.move({ from: orig, to: dest, promotion });

    if (move) {
      const eventName =
        this.el.dataset && this.el.dataset.endgameId
          ? "endgame_move_played"
          : "move_played";

      const payload = {
        from: orig,
        to: dest,
        fen: this.chess.fen(),
        san: move.san,
      };

      if (eventName === "endgame_move_played") {
        payload.endgame_id = this.el.dataset.endgameId;
      }

      this.pushEvent(eventName, payload);

      const nextTurnColor = this.chess.turn() === "w" ? "white" : "black";

      this.ground.set({
        turnColor: nextTurnColor,
        fen: this.chess.fen(),
        movable: {
          color: nextTurnColor,
          dests: this.getValidDests(),
        },
      });
    } else {
      this.ground.set({ fen: this.chess.fen() });
    }
  },
};
