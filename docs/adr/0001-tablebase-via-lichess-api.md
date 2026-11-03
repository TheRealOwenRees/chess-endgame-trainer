# Tablebase via the lichess API instead of self-hosting

_Superseded by ADR-0005: five-or-fewer-piece positions are now probed locally;
Lichess remains for six and seven pieces._

The trainer grades moves against Syzygy tablebases, but self-hosting them is not
possible yet, so we query the lichess tablebase API (`tablebase.lichess.ovh`)
over HTTP and cache responses. This couples the core play loop to a remote
service with rate limits (mitigated by a cooldown and an LFU cache), but avoids
the multi-terabyte 7-piece dataset and hosting cost until local tablebases are
viable.
