/*
 * Thin C shim over Fathom's inline API so Rust can call stable symbols.
 */
#include <stdbool.h>
#include <stdint.h>

#include "tbprobe.h"

bool fathom_init(const char *path) { return tb_init(path); }

void fathom_free(void) { tb_free(); }

unsigned fathom_largest(void) { return TB_LARGEST; }

unsigned fathom_probe_root(uint64_t white, uint64_t black, uint64_t kings,
                           uint64_t queens, uint64_t rooks, uint64_t bishops,
                           uint64_t knights, uint64_t pawns, unsigned rule50,
                           unsigned castling, unsigned ep, bool turn,
                           unsigned *results) {
  return tb_probe_root(white, black, kings, queens, rooks, bishops, knights,
                       pawns, rule50, castling, ep, turn, results);
}
