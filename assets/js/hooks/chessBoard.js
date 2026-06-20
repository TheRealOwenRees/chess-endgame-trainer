import { Chessground } from 'chessground';
import { Chess } from 'chess.js';

export const ChessBoard = {
    mounted() {
    // Initialize chess.js for local rule validation
    this.chess = new Chess();

    // Initialize Chessground
    this.ground = Chessground(this.el, {
      fen: this.chess.fen(),
      movable: {
        color: 'white',
        free: false, // Don't allow completely arbitrary drops
        dests: this.getValidDests() // Only allow legal chess moves
      },
      events: {
        // Triggered when a piece is successfully dropped
        move: (orig, dest, _metadata) => {
          this.handleMove(orig, dest);
        }
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
    // 1. Try to execute the move in chess.js state
    const move = this.chess.move({ from: orig, to: dest, promotion: 'q' });

    if (move) {
      // 2. Telemetry back up to Phoenix LiveView
      this.pushEvent("move_played", { 
        from: orig, 
        to: dest, 
        fen: this.chess.fen() 
      });

      // 3. Determine whose turn it is now ('w' or 'b')
      const nextTurnColor = this.chess.turn() === 'w' ? 'white' : 'black';

      // 4. Force Chessground to update its internal state for the next player
      this.ground.set({
        turnColor: nextTurnColor, // Switches turn tracking
        movable: {
          color: nextTurnColor,   // 👈 THIS IS CRITICAL: Changes who is allowed to drag pieces!
          dests: this.getValidDests() // Re-calculates valid legal squares for Black
        }
      });
    } else {
      // If chess.js says it's an illegal move, snap the piece back instantly
      this.ground.set({ fen: this.chess.fen() });
    }
  }
}