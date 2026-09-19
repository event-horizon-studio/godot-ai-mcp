# godot-ai-mcp

> Give AI agents full control over the Godot 4.7+ editor via the [Model Context Protocol](https://modelcontextprotocol.io).

**godot-ai-mcp** connects any MCP-compatible AI client (Claude, Cursor, Windsurf, Cline, Antigravity, etc.) to a live Godot editor instance. The AI can inspect scenes, create and manipulate nodes, execute GDScript, capture viewport screenshots, query the ClassDB, and more — all through a clean tool interface with full undo/redo support.

![Godot 4.7+](https://img.shields.io/badge/Godot-4.7%2B-blue?logo=godotengine&logoColor=white)
![Node.js 18+](https://img.shields.io/badge/Node.js-18%2B-green?logo=nodedotjs&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![MCP](https://img.shields.io/badge/Protocol-MCP-purple)

---

## Architecture

```
┌──────────────────────────┐
│  AI Client               │
│  (Claude / Cursor / etc) │
└──────────┬───────────────┘
           │ STDIO (JSON-RPC 2.0)
           ▼
┌──────────────────────────┐
│  godot-ai-mcp            │
│  (Node.js MCP Server)    │
└──────────┬───────────────┘
           │ TCP Socket (127.0.0.1:6505)
           │ Line-delimited JSON
           ▼
┌──────────────────────────┐
│  Godot AI MCP Plugin     │
│  (@tool GDScript)        │
│  Running inside Godot    │
└──────────┬───────────────┘
           │ Direct API access
           ▼
┌──────────────────────────┐
│  Godot 4.7+ Editor       │
│  Scene Tree, ClassDB,    │
│  EditorInterface, etc.   │
└──────────────────────────┘
```

The MCP server process owns the STDIO transport cleanly (Godot's editor prints logs to stdout which would corrupt JSON-RPC). The GDScript plugin processes all commands on Godot's main thread via `_process()`, ensuring thread safety. Both sides auto-reconnect independently.

---

## Features

### 25 Tools Across 7 Categories

| Category | Tool | Description |
|----------|------|-------------|
| **Editor** | `godot_get_editor_status` | Godot version, project name, active scene, render method, play state |
| | `godot_open_scene` | Open a `.tscn` by resource path |
| | `godot_save_scene` | Save the active scene |
| | `godot_run_project` | Run main or specific scene (F5 equivalent) |
| | `godot_stop_project` | Stop running game |
| | `godot_get_editor_logs` | Retrieve recent engine/editor logs for AI self-debugging |
| **Scene** | `godot_get_scene_tree` | Full node hierarchy as JSON |
| | `godot_get_node_info` | Detailed node inspection (transform, properties, signals, groups) |
| | `godot_create_node` | Create node with undo/redo |
| | `godot_modify_node_property` | Set any property with undo/redo |
| | `godot_delete_node` | Delete node with undo/redo |
| | `godot_reparent_node` | Move node to new parent with undo/redo |
| | `godot_connect_signal` | Connect signals between nodes with undo/redo |
| | `godot_get_node_connections` | List outgoing signal connections for a node |
| | `godot_create_primitive_mesh` | One-shot 3D primitive mesh instance (Box, Sphere, Capsule, Cylinder, Plane) |
| | `godot_create_collision_shape` | One-shot 3D collision shape (Box, Sphere, Capsule, Cylinder) |
| **Input & Settings** | `godot_get_input_actions` | List all configured input actions and bound keys |
| | `godot_add_input_action` | Add actions with key/mouse bindings to ProjectSettings |
| | `godot_set_project_setting` | Set and save any ProjectSettings property |
| **Resource** | `godot_create_material` | Create StandardMaterial3D (color, roughness, metallic, emission) |
| **Script** | `godot_execute_gdscript` | Run arbitrary GDScript in editor context |
| | `godot_create_script` | Create `.gd` file + optional node attachment |
| | `godot_read_script` | Read script source code |
| **Viewport** | `godot_get_viewport_screenshot` | Capture 2D/3D viewport as PNG |
| **Reflection** | `godot_api_lookup` | ClassDB query (properties, methods, signals, enums) |
| | `godot_list_project_files` | List project files with extension filtering |

> **💡 `godot_execute_gdscript` is the universal escape hatch.** For anything not covered by the specialized tools, the AI can write and run arbitrary GDScript inside the editor — giving it access to every Godot API.

---

## Installation

### Prerequisites

- [Godot 4.7+](https://godotengine.org/download) (standard build — no .NET/C# required)
- [Node.js 18+](https://nodejs.org/)

### Step 1: Install the Godot Plugin

Copy the `addons/godot_ai_mcp/` folder into your Godot project:

```bash
# From this repository root:
cp -r godot-plugin/addons/godot_ai_mcp /path/to/your/godot/project/addons/
```

Then in Godot:
1. Open **Project → Project Settings → Plugins**
2. Enable **"Godot AI MCP"**
3. You should see a **"MCP"** tab appear in the bottom panel showing 🔴 "No clients connected"

### Step 2: Install the MCP Server

**Option A: Install globally from npm** (once published)
```bash
npm install -g godot-ai-mcp
```

**Option B: Run from source**
```bash
cd mcp-server
npm install
npm run build
```

### Step 3: Configure Your AI Client

Add the MCP server to your AI client's configuration.

#### Claude Desktop (`claude_desktop_config.json`)
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "godot-ai-mcp"
    }
  }
}
```

Or if running from source:
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/godot-ai-mcp/mcp-server/build/index.js"]
    }
  }
}
```

#### Cursor / Windsurf / Cline
Add to your MCP settings:
```json
{
  "godot-ai-mcp": {
    "command": "godot-ai-mcp"
  }
}
```

#### Google Antigravity (`.gemini/settings.json`)
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/godot-ai-mcp/mcp-server/build/index.js"]
    }
  }
}
```

### Step 4: Verify

1. Open your Godot project with the plugin enabled
2. Start your AI client
3. The MCP bottom panel in Godot should turn 🟢 **"MCP: 1 client"**
4. Ask the AI: *"What's the Godot editor status?"*

---

## How It Works

### Wire Protocol

The MCP server and Godot plugin communicate over TCP (`127.0.0.1:6505`) using line-delimited JSON:

**Request** (MCP Server → Godot):
```json
{"id": "uuid", "method": "get_scene_tree", "params": {"max_depth": 5}}
```

**Response** (Godot → MCP Server):
```json
{"id": "uuid", "result": {"tree": {"name": "Main", "type": "Node3D", "children": [...]}}}
```

### Undo/Redo

All scene modifications (`create_node`, `modify_node_property`, `delete_node`, `reparent_node`, `create_script` with attachment) are wrapped in `EditorUndoRedoManager` actions. Users can **Ctrl+Z** any AI change.

### Node Ownership

When creating nodes, the plugin correctly sets `node.owner = scene_root` so nodes persist when saving the scene. This is a critical Godot requirement that's easy to miss.

### Auto-Reconnect

The TCP bridge has exponential backoff reconnection (1s → 2s → 4s → max 10s). Godot and the MCP server can start in any order. If either restarts, the connection is re-established automatically.

---

## Configuration

### Port

The default TCP port is `6505`. To change it, edit the `PORT` constant in:
- `godot-plugin/addons/godot_ai_mcp/mcp_server.gd` (line 10)
- `mcp-server/src/bridge.ts` (constructor default)

### Timeout

Request timeout is 15 seconds by default. Increase it for long-running GDScript execution:
- `mcp-server/src/bridge.ts` — change `15000` in the `setTimeout` call

---

## Project Structure

```
godot-ai-mcp/
├── mcp-server/                        # TypeScript MCP server (npm package)
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts                   # Entry point + tool registration
│       ├── bridge.ts                  # TCP bridge with auto-reconnect
│       └── tools/
│           ├── editor.ts              # Editor lifecycle tools
│           ├── scene.ts               # Scene tree tools
│           ├── script.ts              # GDScript tools
│           ├── viewport.ts            # Viewport capture
│           └── reflection.ts          # ClassDB + file listing
│
├── godot-plugin/                      # Godot EditorPlugin
│   └── addons/godot_ai_mcp/
│       ├── plugin.cfg                 # Plugin manifest
│       ├── plugin.gd                  # EditorPlugin entry
│       ├── mcp_server.gd             # TCP server + request router
│       ├── handlers/
│       │   ├── editor_handler.gd
│       │   ├── scene_handler.gd
│       │   ├── script_handler.gd
│       │   ├── viewport_handler.gd
│       │   └── reflection_handler.gd
│       └── ui/
│           └── status_panel.gd        # Bottom panel status indicator
│
├── README.md
├── LICENSE
└── .gitignore
```

---

## Requirements

- **Godot 4.7+** (standard build — no .NET/Mono/C# required)
- **Node.js 18+**
- **Any MCP-compatible AI client**

Works on **Windows**, **macOS**, and **Linux**.

---

## Contributing

Contributions are welcome! Some areas that would be great to expand:

- **Animation tools** — keyframe editing, AnimationPlayer management
- **Shader tools** — visual shader node manipulation, shader parameter editing
- **Physics tools** — collision layer/mask management, physics debugging
- **Audio tools** — AudioBus configuration, sound playback
- **Tilemap tools** — TileMap/TileSet editing for 2D games
- **Input action tools** — InputMap configuration
- **Resource tools** — .tres creation, material/mesh management
- **Project settings tools** — project configuration management

---

## License

[MIT](LICENSE)
