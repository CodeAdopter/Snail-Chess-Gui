# scdb, the position store

A local store for engine evaluations, games and engine logs. It answers one question fast: given a
position, what did every engine say about it, while other threads keep writing.

The code lives in the GUI library at `src/database/`, so the app can use it. This folder holds the
command-line tool, its test and these docs.

The storage engine is **Snail Db**, a separate library at `C:\Snail Db`. Its README covers how the
store works, its crash safety, and the benchmark against SQLite. `src/library.toml` links it by
path, so changes made there show up here on the next build.

## Layout

| Path | What |
|---|---|
| `src/database/position_store.snail` | `PositionDb` |
| `src/database/db_records.snail`, `db_game_types.snail`, `db_games.snail`, `db_logs.snail` | The chess records: evaluations, packed positions, games, logs |
| `src/database/db_pgn_import.snail`, `db_export.snail` | PGN import (streaming, `[%eval]` comments become evaluations) and export with filters |
| `src/database/db_lichess.snail` | Lichess downloads: player games, broadcasts, cloud evaluations, the evaluation dump |
| `src/database/eval_recorder.snail` | The app's recorder: every engine line the app sees goes into the store |
| `db/tool/` | `scdb.exe`, the command-line tool (`snailc build` in `db/tool/`) |
| `db/tests/` | `python db/tests/run.py`, the PGN round trip |

## In the app

- **Recording:** the app opens `<data>/positiondb` at startup. It keeps the deepest exact line of
  each engine and line number from analysis tabs, and the line each engine moved by in tournaments
  and Play games. It commits about once a second while lines come in, and on close. A second
  window finds the store in use and keeps nothing.
- **Evaluations panel** (`src/views/database_panel.snail`): the cloud button (icon only) on the
  analysis tab's command bar, or Settings > Cloud > Show cloud evaluations, shows the stored and
  cloud lines for the position under the analysis. Every engine stands once (local and cloud lines
  of one name merge, the better kept), ranked by CCRL Rating, then depth. At most 10 show, one row
  each with its best line; Show all gives those 10 every line. Find engine filters by name and
  suggests matching names (Enter takes the first). A splitter under the panel caps its height
  (`layout.evals`, 0 for no cap). Kept in settings as `board.database_panel`. Screenshot args:
  `--evals-find WORD`, `--evals-all`.
- **Cloud database:** the server's address is in Settings > Cloud. The server is the Snail rebuild,
  `C:\Open Chess Database Snail` (`build\snailcloud.exe serve`, `http://127.0.0.1:8090` here).
  Sharing is opt in (Settings > Cloud > Opt in, or Enable on the Profile tab's Evaluated positions
  card). Opted in, live lines at depth 12+ go as they are kept, and `EvalRecorder.sync` walks the
  store in 4096 key slices (2 ms a frame) for older lines not shared yet, skipping the
  `Lichess cloud` imports. Lines the server took are marked `DbShared` in `DbEval.flags`, so they
  are never sent again; the count taken is in `cloud_shared.txt` (address, lines, positions). The
  write key is sealed in `cloud_key.bin`. Code: `src/database/cloud_db.snail`, `eval_recorder.snail`.
- **Finished games:** tournament games are kept as engine against engine, and Play games with the
  engine side marked by its name. Their engines' lines were kept as they played, so the PGN's
  `[%eval]` comments are not read again.
- **Database tab** (`src/tabs/database_page.snail`, `--page database`):
  - **Rail:** All games, Played here, Imported and Lichess, with their counts, then the older
    imports the Profile tab used to hold, still browsable.
  - **List:** searched by player and event, narrowed by who played (humans, human vs engine,
    engines) and by rating, newest first, building only the rows in view.
  - **Preview:** on a wide window, the game clicked shows on a board stepped with the buttons or
    the arrow keys, with how many games reached the position shown.
  - **Opening:** Analyse or Open in analysis opens the game in an analysis tab at that move.
  - **Command bar:** Import PGN (on its own thread, any size), Import from Lichess (a player's
    games), Export (the games the list shows, as PGN).
  - **Test arguments:** `--database-import FILE`, `--database-game N` to show game N in the
    preview, `--database-open N --database-ply P` to open it.

## What it keeps

`PositionDb` sets up one Snail Db folder holding:

- **Three tables, each keyed by the position's Polyglot key**
  - `evals`: one engine evaluation per record, 64 bytes, exactly one cache line. A record holds the
    engine, line number, depth, seldepth, bound, score from the side to move, WDL, nodes, time, a
    timestamp and up to 12 PV moves. Records are told apart by engine and line. A deeper evaluation
    replaces a shallower one; at equal depth, more nodes win, then the newer one.
  - `positions`: the position packed into 24 bytes, so evaluations can be exported back as FEN.
    It uses Stockfish's trick: an occupancy bitboard plus a nibble per piece, with special nibbles
    for en passant, castling rooks and Black to move.
  - `seen`: one record for every position every game reached (key, game, ply, result). This is
    the explorer index behind "which games reached this position".
- **Two name lists**: `engines`, and `names` for players and events.
- **Two journals**
  - `games`: a 40-byte entry per game (players, event, Elo, date, result, which sides were
    engines, source), plus its tag lines and 2-byte moves.
  - `logs`: a 32-byte entry per line sent to or read from an engine (time, engine, game,
    direction), plus the text.

## The command-line tool

```
scdb FOLDER import FILE.pgn [--engines]
scdb FOLDER lichess-user NAME [MOST]
scdb FOLDER lichess-broadcast ID
scdb FOLDER lichess-cloud FEN
scdb FOLDER lichess-evals FILE.jsonl [MOST]
scdb FOLDER evals FEN
scdb FOLDER games FEN [MOST]
scdb FOLDER export-games FILE.pgn [--humans|--human-engine|--engines] [--player NAME] [--elo MIN-MAX]
scdb FOLDER export-evals FILE.jsonl [--engine NAME]
scdb FOLDER export-logs FILE.txt [--engine NAME]
scdb FOLDER stats
```

**How players are marked as engines:** a player counts as an engine if they're titled BOT, have a
`WhiteType`/`BlackType` tag of `program`, are named as an engine the store already knows, or the
import used `--engines` (for engine-event files such as CCRL or TCEC, which carry no titles).
"Engine matches in an Elo range" is `export-games out.pgn --engines --elo 3400-3700`.

**What Lichess offers:**
- **Player games:** `lichess-user`. The evaluations from analysed games come in as engine
  "Lichess analysis", at depth 0, because Lichess doesn't say the depth.
- **Over-the-board events:** `lichess-broadcast ID`. Lichess has no bulk download of its masters
  database, so its official broadcasts are where the top over-the-board games come from.
- **Cloud evaluations:** `lichess-cloud` for one position, up to 5 lines.
- **The full evaluation dump:** `database.lichess.org/lichess_db_eval.jsonl.zst`. Unpack it from
  zstd first, then load it with `lichess-evals`. There's no zstd unpacker here yet.

## From the app

```snail
use src/database/db_games
use src/database/db_logs

var db: PositionDb
db.open("C:/.../positions")
let sf = db.engine("Stockfish 17")                       # engine number, made once
db.put_eval(&board, DbEval(engine: sf, multipv: 1, depth: 30, score: 25, ...))
db.commit()                                               # when convenient, e.g. each bestmove
var list: [..]DbEval
db.evals_at(board.key, &list)                             # every engine, deepest of each line
db.add_game(&input)                                       # a finished game, positions indexed at once
db.games_at(board.key, &seen)
db.log_line(sf, game, DbFromEngine, "info depth 30 ...")
db.close()
```

Ranking for a "cloud evaluation" panel (CCRL rating, then depth) belongs in the GUI, read from the
registry's `ccrl.json` when it's shown. Ratings change every week, so they aren't stored here.

## Limits and next steps

- **Chess960 castling rights aren't packed.** The rights are kept only for rooks on the corner
  squares.
- **Games and log lines become readable after `commit()`**, though the positions a game reached
  are findable at once.
- **Folders made before the move to Snail Db aren't read correctly**: the manifest, name lists and
  logs changed format. Re-import them.
- **Not hooked into the GUI yet**: the store needs the cloud-eval panel, the engine output feed,
  tournament games and the engine log.
