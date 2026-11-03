# Player-facing endgame URLs use a public code

Player links address an endgame by a short random **public code** rather than
its database UUID. The UUID stays the admin identity: admin routes mount by
id and the Show page displays both. The code is stable for the row's lifetime
and unguessable, so a shared play link neither exposes a primary key nor
invites enumeration. Keys were rejected as the handle because many endgames
share one (that is how the list groups them), and Key-plus-ordinal would break
when endgames are added or removed. A FEN hash was rejected as longer and
derivable without hiding anything new.

## Consequences

- Admin URLs and the admin list keep the UUID, so debugging still lines up
  with the database. Admin search accepts either identifier plus a FEN or FEN
  fragment.
- A public code is generated on insert and backfilled by migration; it is
  never regenerated on update.
