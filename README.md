# Goblin-COM-zig

A zig rewrite of [Goblin-COM roguelike game for 7DRL 2015](https://github.com/skeeto/goblin-com)

### How to run

`make run/release`

---

### ANSI Escape Sequences

| Code | Where | What it does |
|------|-------|-------------|
| `\x1b[2J` | `init()` | **Clear entire screen** — erases all content |
| `\x1b[?25l` | `init()` | **Hide the cursor** — makes the blinking cursor invisible |
| `\x1b[?25h` | `deinit()` | **Show the cursor** — restores cursor visibility |
| `\x1b[m` | `deinit()` | **Reset all attributes** — restores default colors and styling |
| `\x1b[{y};{x}H` | `move()` | **Move cursor** to row `y`, column `x` (1-based) |
| `\x1b[{fg};{bg}m` | `putc()` | **Set text colors** — `fg` is foreground (30–37 normal, 90–97 bright), `bg` is background (40–47 normal, 100–107 bright) |

The general pattern is `\x1b[` (ESC + `[`, called **CSI** — Control Sequence Introducer) followed by parameters and a letter that determines the command.
The letter at the end is the key: `J` = erase, `H` = cursor position, `m` = set graphics/color, and `?25l`/`?25h` are DEC private mode sequences for cursor visibility.

