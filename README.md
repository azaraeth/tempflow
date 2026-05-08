# ⬡ flowtpl

> Template manager for sn-flow. Save any workflow as a portable `.snflow` file, share it with others, and load it into any project in seconds.

Part of the **sn-flow** ecosystem. See `README_flow.md` to get started.

---

## What is flowtpl?

flowtpl lets you package an entire sn-flow project — all its nodes, bodies, and connections — into a single human-readable `.snflow` file. You can then share that file with anyone, import it on any device, and load it into a new project instantly.

It uses a **green theme** to distinguish it visually from the orange of flow and the blue of flowmon.

---

## Installation

```bash
chmod +x flowtpl
./flowtpl
```

flowtpl reads from the same `~/.flowterm/` data directory as flow. No additional setup needed.

---

## Quick Workflow

```bash
# 1. Build your workflow in flow, then open flowtpl
./flowtpl

# 2. Save current project as a template
save mybot "my ai starter workflow"

# 3. Export to share
export mybot ~/Desktop/mybot.snflow

# 4. Recipient imports on their device
import ~/Downloads/mybot.snflow

# 5. Load it into a new project
load mybot mynewproject

# 6. Switch to it inside flow
switch mynewproject
```

---

## Commands

| Command | Description |
|---|---|
| `save <name> [desc]` | Save current flow project as a template |
| `load <name> [project]` | Load a template into a new or existing project |
| `import <path.snflow>` | Import a shared `.snflow` file from any path |
| `export <name> [dest]` | Export a template to a shareable file |
| `ls` | List all saved templates with author and description |
| `show <name>` | Inspect template metadata and node list |
| `rm <name>` | Delete a saved template |
| `proj` | Show the currently active project |
| `switch <project>` | Switch active project |
| `help` | Command reference |
| `exit / quit` | Exit flowtpl |

---

## The `.snflow` File Format

`.snflow` files are plain text and fully human-readable. You can open, inspect, and even edit them in any text editor. Here is what the structure looks like:

```
# ╔══════════════════════════════════════════════╗
# ║   sn-flow template  ·  .snflow               ║
# ╚══════════════════════════════════════════════╝
#meta:name=mybot
#meta:description=my ai starter workflow
#meta:author=azaraeth
#meta:created=2026-05-08 12:00:00
#meta:source_project=myproject
#meta:nodes=4
#meta:version=1

# NODES

NODE:start
TYPE:start
SUB:-
LANG:-
BODY_START
BODY_END

NODE:fetch
TYPE:command
SUB:script
LANG:bash
BODY_START
curl -s http://localhost:11434/api/generate
BODY_END

# CONNECTIONS

start fetch
fetch end
```

Because the format is plain text, templates can be shared via messaging apps, email, GitHub, or any file transfer method.

---

## Template Storage

Templates are saved locally at:

```
~/.flowterm/templates/<name>.snflow
```

Each template stores a complete snapshot of the project at the time of saving — changes made to the project afterward are not reflected in the template unless you save again.

---

## Loading into an Existing Project

When loading a template into a project that already has nodes, flowtpl will warn you before overwriting:

```
project 'myproject' already has nodes — overwrite? [y/N]
```

Answering `y` wipes the existing nodes and connections and replaces them with the template. Answering `N` cancels with no changes made.

---

## Color Theme

flowtpl uses a **green theme** to distinguish it from flow (orange) and flowmon (blue).

| Variable | Code | Color |
|---|---|---|
| `OR` | `\033[38;5;119m` | Lime green — main accent |
| `OD` | `\033[38;5;71m`  | Forest green — dim accent |
| `BL` | `\033[38;5;114m` | Soft green — badges |
| `GR` | `\033[38;5;156m` | Bright green — success |
| `CY` | `\033[38;5;121m` | Mint green — highlights |

---

## Changelog

### v1.0.0
- Initial release alongside sn-flow v1.2.4
- Save, load, import, export `.snflow` templates
- Human-readable template format with full metadata header
- Green theme distinguishing flowtpl from flow and flowmon

---

## See Also

- `README_flow.md` — main workflow runner
- `README_flowmon.md` — background run monitor

---

## Created by Azaraeth
