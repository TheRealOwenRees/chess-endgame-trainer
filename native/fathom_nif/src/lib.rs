use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::Mutex;

use rustler::types::tuple::make_tuple;
use rustler::{Atom, Encoder, Env, Term};

mod atoms {
    rustler::atoms! {
        win,
        cursed_win,
        draw,
        blessed_loss,
        loss,
        checkmate,
        stalemate,
        failed,
        unknown,
    }
}

// Fathom WDL codes (see tbprobe.h).
const TB_LOSS: u32 = 0;
const TB_BLESSED_LOSS: u32 = 1;
const TB_DRAW: u32 = 2;
const TB_CURSED_WIN: u32 = 3;
const TB_WIN: u32 = 4;

const TB_MAX_MOVES: usize = 192 + 1;

const TB_RESULT_FAILED: u32 = 0xFFFF_FFFF;
const TB_RESULT_CHECKMATE: u32 = 4; // TB_SET_WDL(0, TB_WIN)
const TB_RESULT_STALEMATE: u32 = 2; // TB_SET_WDL(0, TB_DRAW)

extern "C" {
    fn fathom_init(path: *const c_char) -> bool;
    fn fathom_largest() -> u32;
    fn fathom_probe_root(
        white: u64,
        black: u64,
        kings: u64,
        queens: u64,
        rooks: u64,
        bishops: u64,
        knights: u64,
        pawns: u64,
        rule50: u32,
        castling: u32,
        ep: u32,
        turn: bool,
        results: *mut u32,
    ) -> u32;
}

struct State {
    path: Option<String>,
    largest: u32,
}

// Fathom keeps global probe state and `tb_probe_root` is not thread safe, so
// probes are serialised through this lock.
static STATE: Mutex<State> = Mutex::new(State {
    path: None,
    largest: 0,
});

#[derive(Default)]
struct Position {
    white: u64,
    black: u64,
    kings: u64,
    queens: u64,
    rooks: u64,
    bishops: u64,
    knights: u64,
    pawns: u64,
    turn: bool,
    castling: u32,
    ep: u32,
}

fn square(file: u32, rank: u32) -> u32 {
    rank * 8 + file
}

fn bit(square: u32) -> u64 {
    1u64 << square
}

fn parse_fen(fen: &str) -> Result<Position, String> {
    let mut fields = fen.split_whitespace();
    let board = fields.next().ok_or("missing board")?;
    let active = fields.next().ok_or("missing active colour")?;
    let castling = fields.next().unwrap_or("-");
    let en_passant = fields.next().unwrap_or("-");

    let turn = match active {
        "w" => true,
        "b" => false,
        other => return Err(format!("invalid active colour: {other}")),
    };

    let mut pos = Position {
        turn,
        ..Position::default()
    };

    let ranks: Vec<&str> = board.split('/').collect();
    if ranks.len() != 8 {
        return Err(format!("board must have 8 ranks, got {}", ranks.len()));
    }

    for (index, rank) in ranks.iter().enumerate() {
        let rank_index = (7 - index) as u32;
        let mut file: u32 = 0;

        for piece in rank.chars() {
            match piece {
                '1'..='8' => file += piece.to_digit(10).unwrap(),
                _ => {
                    if file >= 8 {
                        return Err(format!("rank {index} overflows 8 squares"));
                    }

                    let square = square(file, rank_index);
                    let b = bit(square);

                    match piece.to_ascii_lowercase() {
                        'k' => pos.kings |= b,
                        'q' => pos.queens |= b,
                        'r' => pos.rooks |= b,
                        'b' => pos.bishops |= b,
                        'n' => pos.knights |= b,
                        'p' => pos.pawns |= b,
                        _ => return Err(format!("unexpected character '{piece}' in board")),
                    }

                    if piece.is_ascii_uppercase() {
                        pos.white |= b;
                    } else {
                        pos.black |= b;
                    }

                    file += 1;
                }
            }

            if file > 8 {
                return Err(format!("rank {index} overflows 8 squares"));
            }
        }

        if file != 8 {
            return Err(format!("rank {index} does not sum to 8 squares"));
        }
    }

    pos.castling = parse_castling(castling)?;
    let ep = parse_en_passant(&pos, en_passant)?;
    pos.ep = ep;

    Ok(pos)
}

fn parse_castling(field: &str) -> Result<u32, String> {
    if field == "-" {
        return Ok(0);
    }

    let mut bits = 0u32;
    for piece in field.chars() {
        bits |= match piece {
            'K' => 0x1,
            'Q' => 0x2,
            'k' => 0x4,
            'q' => 0x8,
            other => return Err(format!("invalid castling field: {other}")),
        };
    }
    Ok(bits)
}

/// Parses the en-passant square, dropping it unless a pawn of the side to move
/// can actually capture, matching how Syzygy positions are canonicalised.
fn parse_en_passant(pos: &Position, field: &str) -> Result<u32, String> {
    if field == "-" {
        return Ok(0);
    }

    let bytes = field.as_bytes();
    if bytes.len() != 2 {
        return Err(format!("invalid en passant field: {field}"));
    }

    let file = match bytes[0] {
        file @ b'a'..=b'h' => (file - b'a') as u32,
        _ => return Err(format!("invalid en passant file: {field}")),
    };
    let rank = match bytes[1] {
        rank @ b'1'..=b'8' => (rank - b'1') as u32,
        _ => return Err(format!("invalid en passant rank: {field}")),
    };

    let mut mask = 0u64;
    let capturing_pawns = if pos.turn {
        // White to move: ep on rank 6, white pawns capture from rank 5.
        if file > 0 {
            mask |= bit(square(file - 1, 4));
        }
        if file < 7 {
            mask |= bit(square(file + 1, 4));
        }
        pos.white & pos.pawns
    } else {
        // Black to move: ep on rank 3, black pawns capture from rank 4.
        if file > 0 {
            mask |= bit(square(file - 1, 3));
        }
        if file < 7 {
            mask |= bit(square(file + 1, 3));
        }
        pos.black & pos.pawns
    };

    if capturing_pawns & mask == 0 {
        Ok(0)
    } else {
        Ok(square(file, rank))
    }
}

fn wdl_atom(wdl: u32) -> Atom {
    match wdl {
        TB_LOSS => atoms::loss(),
        TB_BLESSED_LOSS => atoms::blessed_loss(),
        TB_DRAW => atoms::draw(),
        TB_CURSED_WIN => atoms::cursed_win(),
        TB_WIN => atoms::win(),
        _ => atoms::unknown(),
    }
}

/// Returns `{wdl, from, to, promotes, ep, dtz}` for an encoded TB_RESULT.
fn move_tuple<'a>(env: Env<'a>, result: u32) -> Result<Term<'a>, String> {
    let wdl = wdl_atom(result & 0x0000_000F);
    let from = ((result & 0x0000_FC00) >> 10) as i64;
    let to = ((result & 0x0000_03F0) >> 4) as i64;
    let promotes = ((result & 0x0007_0000) >> 16) as i64;
    let ep = ((result & 0x0008_0000) >> 19) as i64;
    let dtz = ((result & 0xFFF0_0000) >> 20) as i64;

    Ok(make_tuple(
        env,
        &[
            wdl.encode(env),
            from.encode(env),
            to.encode(env),
            promotes.encode(env),
            ep.encode(env),
            dtz.encode(env),
        ],
    ))
}

/// Initialises Fathom against `path` and returns the largest piece count found.
#[rustler::nif(schedule = "DirtyIo")]
fn init(path: String) -> Result<u32, String> {
    let mut state = STATE
        .lock()
        .map_err(|_| "fathom lock poisoned".to_string())?;

    if state.path.as_deref() != Some(path.as_str()) {
        let c_path = CString::new(path.clone()).map_err(|_| "path contains NUL")?;

        if unsafe { fathom_init(c_path.as_ptr()) } {
            state.largest = unsafe { fathom_largest() };
            state.path = Some(path);
        } else {
            return Err(format!("fathom failed to initialise from {path}"));
        }
    }

    Ok(state.largest)
}

/// Probes the position and returns `{root, moves}`.
///
/// `root` is either an outcome atom (`:checkmate`, `:stalemate`, `:failed`) or
/// `{wdl, from, to, promotes, ep, dtz}`. `moves` is a list of the same move
/// tuples, one per legal move.
#[rustler::nif(schedule = "DirtyCpu")]
fn probe<'a>(env: Env<'a>, fen: String) -> Result<Term<'a>, String> {
    let pos = parse_fen(&fen)?;

    let state = STATE
        .lock()
        .map_err(|_| "fathom lock poisoned".to_string())?;

    if state.path.is_none() {
        return Err("fathom not initialised".to_string());
    }

    let mut results = [0u32; TB_MAX_MOVES];
    // rule50 is fixed at 0 so the result is position-level, matching the cache.
    let root = unsafe {
        fathom_probe_root(
            pos.white,
            pos.black,
            pos.kings,
            pos.queens,
            pos.rooks,
            pos.bishops,
            pos.knights,
            pos.pawns,
            0,
            pos.castling,
            pos.ep,
            pos.turn,
            results.as_mut_ptr(),
        )
    };

    let (root_term, moves) = match root {
        TB_RESULT_FAILED => (atoms::failed().encode(env), Vec::new()),
        TB_RESULT_CHECKMATE => (atoms::checkmate().encode(env), Vec::new()),
        TB_RESULT_STALEMATE => (atoms::stalemate().encode(env), Vec::new()),
        other => {
            let mut moves = Vec::new();
            for &result in results.iter() {
                if result == TB_RESULT_FAILED {
                    break;
                }
                moves.push(move_tuple(env, result)?);
            }
            (move_tuple(env, other)?, moves)
        }
    };

    Ok(make_tuple(env, &[root_term, moves.encode(env)]))
}

rustler::init!("Elixir.Chesstrainer.Endgames.Tablebase.Fathom");
