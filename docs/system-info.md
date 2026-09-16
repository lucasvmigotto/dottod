# System information in the prompt

dottod appends a compact system-metrics segment to the stock Spaceship
prompt. All existing Spaceship sections (directory, git, package,
languages, cloud, docker, kubernetes, …) are untouched; `sysinfo` is
registered as one additional section at the end of the prompt's first line.

Example (default metrics):

```text
<CPU> 23% │ <MEM> 7.8/15.6G 50% │ <NET> ↓12.4M/s ↑1.8M/s
```

With opt-in metrics enabled:

```text
<CPU> 23% │ <MEM> 7.8/15.6G 50% │ <NET> ↓12.4M/s ↑1.8M/s │ <GAUGE> 0.42 │ <THERM> 54°C
```

## How it works

```text
Spaceship `sysinfo` section          scripts/.sysinfo.prompt.sh
        │  thin integration layer (calls collector, renders via spaceship::section)
        ▼
collector                            scripts/system-info.sh
        │  reads Linux kernel interfaces, formats one display line
        ▼
cache + previous-sample state        ${XDG_CACHE_HOME:-$HOME/.cache}/dottod/
```

The section function (`spaceship_sysinfo`) is best effort: any failure
(missing collector, empty output, collector error) renders nothing and
returns 0, so the prompt can never break shell startup.

## Metrics

| Metric | Source | Calculation |
| ------ | ------ | ----------- |
| CPU % | `/proc/stat` (`cpu` line) | `100 × (1 − Δidle/Δtotal)` across two samples; load average is never confused with utilization |
| RAM | `/proc/meminfo` (`MemTotal`, `MemAvailable`) | `used = total − available`; shown as `used/total` GiB + percent |
| Net RX/TX | `/proc/net/route` (default route) + `/proc/net/dev` | byte-counter deltas over wall time; falls back to first non-`lo` interface |
| Load (opt-in) | `/proc/loadavg` | first value, e.g. `0.42` |
| CPU temp (opt-in) | `/sys/class/thermal/thermal_zone*/temp`, `/sys/class/hwmon/hwmon*/temp*_input` | max valid sensor (millidegree °C, sanity-checked); omitted entirely when no sensor exists |

Rate-based metrics need history: the first run after boot (or cache wipe)
shows only RAM/load/temperature, and the next prompt has the full segment.
Counter resets and default-route/interface changes are detected and degrade
to omitting the affected metric for one sample — the prompt never errors.

## Cache behavior

* Location: `${XDG_CACHE_HOME:-$HOME/.cache}/dottod/` (`sysinfo.cache` for
  the display line, `sysinfo.state` for the previous sample). No cache
  files live in the repository.
* Fresh cache (default TTL 2 s) is printed verbatim — prompt cost is one
  file read (~milliseconds). Stale cache triggers recollection.
* Writes are atomic (`mktemp` in the same directory + `mv`), so concurrent
  shells never observe partial files; last-writer-wins on the state file
  only skews one sample.
* Corrupt cache/state is ignored and recollected. The cache holds metrics
  only — no sensitive data.

## Glyphs (Nerd Fonts)

Glyphs are defined with explicit Unicode code-point notation in
`scripts/system-info.sh` (no literal icons in source). Code points are
Material Design Icons from Nerd Fonts 3.x, verified against the upstream
`glyphnames.json`:

| Constant | Code point | Icon |
| -------- | ---------- | ---- |
| `GLYPH_CPU` | U+F061A | md-chip |
| `GLYPH_MEM` | U+F035B | md-memory |
| `GLYPH_NET` | U+F06F3 | md-network |
| `GLYPH_LOAD` | U+F029A | md-gauge |
| `GLYPH_TEMP` | U+F050F | md-thermometer |
| `GLYPH_DOWN` / `GLYPH_UP` | U+2193 / U+2191 | plain ↓ ↑ (not font-dependent) |
| separator | U+2502 | │ |

Without a Nerd Font installed (see the `fonts` task), the MDI icons render
as boxes but the values stay readable.

## Configuration

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `_DOT_SYSTEM_INFO_ENABLED` | `true` | master switch for the section |
| `_DOT_SYSTEM_INFO_TTL` | `2` | cache TTL in seconds |
| `_DOT_SYSTEM_INFO_SHOW_LOAD` | `0` | set `1` to append load average |
| `_DOT_SYSTEM_INFO_SHOW_TEMP` | `0` | set `1` to append temperature when a sensor exists |
| `SPACESHIP_SYSINFO_SHOW` | `true` | `false` hides the section |
| `SPACESHIP_SYSINFO_COLOR` | `cyan` | section color |
| `SPACESHIP_SYSINFO_SYMBOL` | empty | symbol prefix (output already carries glyphs) |
| `SPACESHIP_SYSINFO_PREFIX` / `_SUFFIX` | prompt defaults | section framing |

No ANSI escapes are emitted by the collector; Spaceship/zsh owns styling.

## Troubleshooting

* **Segment missing**: check `_DOT_SYSTEM_INFO_ENABLED` and that
  `scripts/system-info.sh` is executable; run it manually — it always
  exits 0 and prints what it could collect.
* **Only RAM on first prompt**: expected (no previous sample yet).
* **Stale values**: remove
  `${XDG_CACHE_HOME:-$HOME/.cache}/dottod/sysinfo.*` and re-render.
* **Boxes instead of icons**: install a Nerd Font (`./bin/fonts.sh`).
* **No temperature**: enable `_DOT_SYSTEM_INFO_SHOW_TEMP=1`; still absent
  means no readable sensor under `/sys` on this hardware.

## Performance

Measured on the maintainer machine (cold = no cache/state, cached = fresh
cache): cold ≈ 30 ms, cached ≈ 6 ms. The cached path is what every prompt
render pays. Run `./scripts/system-info.sh --collect` vs plain
`./scripts/system-info.sh` (or `time` either) to re-measure locally.

## Files

* `scripts/system-info.sh` — collector (bash program; a silent no-op if
  ever sourced by zsh, so the `scripts/*.sh` glob can't pollute options).
* `scripts/.sysinfo.prompt.sh` — `spaceship_sysinfo()` section +
  `_dottod_sysinfo_register()` (idempotent order registration).
* `config/.custom.zshrc` — invokes the registration after oh-my-zsh loads.
* `tests/test-system-info.sh`, `tests/test-spaceship-sysinfo.zsh` — suites.
