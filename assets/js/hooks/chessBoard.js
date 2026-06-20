import { Chessground } from 'chessground';
import { Chess } from 'chess.js';

export const ChessBoard = {
    mounted() {
        this.chess = new Chess();

        this.ground = Chessground(this.el, {
            fen: this.chess.fen(),
            movable: {
                color: 'white',
                free: false,
                dests: this.getValidDests()
            },
            events: {
                move: (orig, dest, _metadata) => {
                this.handleMove(orig, dest);
                }
            }
        });

        this.handleEvent("set_fen", ({ fen }) => {
            try {
                this.chess.load(fen);

                const currentTurnColor = this.chess.turn() === 'w' ? 'white' : 'black';
                
                this.ground.set({
                    fen: fen,
                    turnColor: currentTurnColor,
                    movable: {
                        color: currentTurnColor,
                        dests: this.getValidDests()
                    }
                });
            } catch (error) {
                console.error("Invalid FEN string submitted:", error);
                alert("Invalid FEN configuration!");
            }
        });
  },

  getValidDests() {
    // Convert chess.js moves into the Map format Chessground expects
    const dests = new Map();
    this.chess.moves({ verbose: true }).forEach(m => {
      if (!dests.has(m.from)) dests.set(m.from, []);
      dests.get(m.from).push(m.to);
    });
    return dests;
  },

  handleMove(orig, dest) {
    const move = this.chess.move({ from: orig, to: dest, promotion: 'q' });

    if (move) {
      this.pushEvent("move_played", { 
        from: orig, 
        to: dest, 
        fen: this.chess.fen(),
        san: move.san,
      });

      const nextTurnColor = this.chess.turn() === 'w' ? 'white' : 'black';

      this.ground.set({
        turnColor: nextTurnColor,
        movable: {
          color: nextTurnColor,
          dests: this.getValidDests()
        }
      });
    } else {
      this.ground.set({ fen: this.chess.fen() });
    }
  }
}