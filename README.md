# Godot AI MCP (`godot-ai-mcp`)

[![npm version](https://img.shields.io/npm/v/godot-ai-mcp.svg?style=flat-square&color=cb3837)](https://www.npmjs.com/package/godot-ai-mcp)
[![Godot Engine](https://img.shields.io/badge/Godot-4.7%2B-478cbf?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Protocol](https://img.shields.io/badge/Protocol-MCP-8A2BE2?style=flat-square)](https://modelcontextprotocol.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

A [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server that provides AI coding assistants with full programmatic control over the live **Godot 4.7+** editor.

Inspect scene graphs, create and modify nodes with undo/redo history, generate primitive meshes and collision shapes, wire signals, bind input actions, capture editor viewports, query `ClassDB` reflection, and execute GDScript directly inside the editor.

---

## Why `godot-ai-mcp`?

- **Pure GDScript Plugin:** Works with standard, official Godot builds. **No .NET, Mono, or C# runtime required.**
- **Undo / Redo Native:** All node creations, property modifications, and signal connections register with Godot's `EditorUndoRedoManager`. Any AI action can be undone with standard `Ctrl+Z` (`Cmd+Z`).
- **Clean Architecture:** Operates over a local TCP bridge (`127.0.0.1:6505`). Godot editor console output never pollutes the MCP `stdio` stream.
- **Zero-Install Client Execution:** Distributed via npm — launch instantly with `npx -y godot-ai-mcp`.

---

## System Architecture

```
┌────────────────────────────────────────┐
│  AI Assistant                          │
│  (Claude Desktop / Cursor / Cline)     │
└───────────────────┬────────────────────┘
                    │ MCP STDIO (JSON-RPC 2.0)
                    ▼
┌────────────────────────────────────────┐
│  godot-ai-mcp (Node.js Process)        │
└───────────────────┬────────────────────┘
                    │ Local TCP (127.0.0.1:6505)
                    │ Line-Delimited JSON
                    ▼
┌────────────────────────────────────────┐
│  Godot AI MCP EditorPlugin (@tool)     │
│  Running inside Godot 4.7+ Editor      │
└───────────────────┬────────────────────┘
                    │ Direct Engine Reflection
                    ▼
┌────────────────────────────────────────┐
│  Godot SceneTree, ClassDB, Viewports   │
└────────────────────────────────────────┘
```

---

## Quick Start (3 Steps)

### Step 1: Install the Godot Plugin

1. Download or copy the [`addons/godot_ai_mcp`](https://github.com/event-horizon-studio/godot-ai-mcp/tree/main/godot-plugin/addons/godot_ai_mcp) directory into the `addons/` folder of your Godot project:
   ```
   your-godot-project/
   ├── addons/
   │   └── godot_ai_mcp/
   │       ├── plugin.cfg
   │       ├── plugin.gd
   │       ├── mcp_server.gd
   │       ├── handlers/
   │       └── ui/
   └── project.godot
   ```
2. Open your project in **Godot 4.7+**.
3. Navigate to **Project → Project Settings → Plugins** and set **Godot AI MCP** to **Enabled**.
4. An **"MCP"** tab will appear in the bottom panel dock showing:  
   `🔴 MCP: No clients connected`

---

### Step 2: Configure Your AI Client

Add `godot-ai-mcp` to your client's MCP configuration file.

#### Claude Desktop

Edit your configuration file:
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "npx",
      "args": ["-y", "godot-ai-mcp"]
    }
  }
}
```

#### Cursor

1. Open **Cursor Settings → Features → MCP**.
2. Click **+ Add New MCP Server**.
3. Fill in:
   - **Name:** `godot-ai-mcp`
   - **Type:** `command`
   - **Command:** `npx -y godot-ai-mcp`

Or edit `.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "npx",
      "args": ["-y", "godot-ai-mcp"]
    }
  }
}
```

#### Windsurf

Edit `~/.codeium/windsurf/mcp_config.json`:
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "npx",
      "args": ["-y", "godot-ai-mcp"]
    }
  }
}
```

#### Cline (VS Code Extension)

Open the Cline MCP settings tab and add:
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "npx",
      "args": ["-y", "godot-ai-mcp"]
    }
  }
}
```

#### Google Antigravity / Gemini CLI

Add to your workspace `.gemini/settings.json`:
```json
{
  "mcpServers": {
    "godot-ai-mcp": {
      "command": "npx",
      "args": ["-y", "godot-ai-mcp"]
    }
  }
}
```

---

### Step 3: Verify the Connection

1. Keep Godot open with the plugin enabled.
2. Launch or restart your AI assistant.
3. The bottom panel in Godot will immediately change to:  
   `🟢 MCP: 1 client`
4. Prompt your AI:  
   > *"What is the current status of the Godot editor and active scene?"*  
   
   The AI will invoke `godot_get_editor_status` and report back with your Godot version, active scene name, and project configuration.

---

## Tool Reference (26 Tools)

### 1. Editor Lifecycle & Project Management
| Tool | Description | Parameters |
|---|---|---|
| `godot_get_editor_status` | Returns Godot engine version, project name, active scene file path, root node name, and play state. | *(None)* |
| `godot_open_scene` | Opens an existing scene in the editor. | `scene_path` (string, e.g. `res://scenes/main.tscn`) |
| `godot_save_scene` | Saves the currently active scene. | *(None)* |
| `godot_run_project` | Launches project playback (F5 equivalent) or runs a specific scene file. | `scene_path` (string, optional) |
| `godot_stop_project` | Stops the running playtest session. | *(None)* |
| `godot_get_editor_logs` | Reads engine/editor logs from disk for self-diagnosis. | `line_count` (number, default: 50) |
| `godot_get_editor_output` | Captures the exact live text, errors, and warnings visible in the Godot Output dock. | `line_count` (number, default: 50) |

### 2. Scene Graph & Node Manipulation (Undo/Redo Supported)
| Tool | Description | Parameters |
|---|---|---|
| `godot_get_scene_tree` | Serializes the complete node hierarchy of the active scene to JSON. | `max_depth` (number, default: -1 for unlimited) |
| `godot_get_node_info` | Retrieves detailed information about a node (transform, properties, signals, groups). | `node_path` (string, e.g. `Player/CollisionShape3D`) |
| `godot_create_node` | Instantiates and adds any engine node type into the scene tree. | `parent_path`, `node_type`, `node_name` |
| `godot_modify_node_property` | Modifies an exported or engine property on a target node. | `node_path`, `property`, `value` |
| `godot_delete_node` | Removes a node from the scene tree. | `node_path` |
| `godot_reparent_node` | Changes the parent of a node while preserving transforms and ownership. | `node_path`, `new_parent_path` |
| `godot_connect_signal` | Connects a signal from a source node to a target node method. | `source_path`, `signal_name`, `target_path`, `method_name` |
| `godot_get_node_connections` | Lists all active signal connections originating from a node. | `node_path` |

### 3. Rapid 3D Prototyping
| Tool | Description | Parameters |
|---|---|---|
| `godot_create_primitive_mesh` | Spawns a `MeshInstance3D` with a primitive geometry (Box, Sphere, Capsule, Cylinder, Plane). | `parent_path`, `mesh_type`, `node_name`, `size`, `radius`, `height`, `material_path` |
| `godot_create_collision_shape` | Spawns a `CollisionShape3D` with matching geometry (Box, Sphere, Capsule, Cylinder). | `parent_path`, `shape_type`, `node_name`, `size`, `radius`, `height` |

### 4. InputMap & Project Settings
| Tool | Description | Parameters |
|---|---|---|
| `godot_get_input_actions` | Lists all actions defined in the project InputMap and their bound keys/buttons. | *(None)* |
| `godot_add_input_action` | Creates a new action with key and mouse bindings in `ProjectSettings`. | `action`, `deadzone`, `keys` (e.g. `["W", "Up"]`), `mouse_buttons` |
| `godot_set_project_setting` | Modifies and persists any setting in `project.godot`. | `setting` (string), `value` (any) |

### 5. Materials & Shaders
| Tool | Description | Parameters |
|---|---|---|
| `godot_create_material` | Creates a `StandardMaterial3D` with color, roughness, metallic, and emission, optionally saving to `.tres`. | `save_path`, `albedo_color`, `roughness`, `metallic`, `emission_color`, `emission_energy_multiplier` |

### 6. GDScript Authoring & Execution
| Tool | Description | Parameters |
|---|---|---|
| `godot_execute_gdscript` | Executes arbitrary GDScript in the editor context with access to `EditorInterface` and singletons. | `code` (string) |
| `godot_create_script` | Writes a `.gd` file, rescans the filesystem, and optionally attaches it to a node. | `script_path`, `content`, `attach_to` |
| `godot_read_script` | Reads the text content of any GDScript file in `res://`. | `script_path` |

### 7. Viewport & Reflection
| Tool | Description | Parameters |
|---|---|---|
| `godot_get_viewport_screenshot` | Captures an image of the 2D or 3D editor viewport and returns it as a PNG. | `viewport` (`"2d"` or `"3d"`) |
| `godot_api_lookup` | Queries Godot's `ClassDB` for class methods, arguments, return types, properties, and enums. | `class_name`, `include_inherited` |
| `godot_list_project_files` | Scans `res://` and lists files filtered by extension. | `directory`, `extensions`, `recursive` |

---

## Example Prompts

Here are examples of what you can ask your AI assistant once connected:

- **Grayboxing:**
  > *"Create a 3D floor plane of size (20, 1, 20) named Ground with a StaticBody3D and matching collision shape."*
- **Character Setup:**
  > *"Create a CharacterBody3D named Player at position (0, 1, 0), add a CapsuleMesh, a CapsuleShape3D, and attach a basic movement script."*
- **Input Configuration:**
  > *"Add 'move_forward' bound to W and Up arrow, and 'jump' bound to Space in the project input map."*
- **Signal Wiring:**
  > *"Connect the 'body_entered' signal from HazardArea to the '_on_hazard_entered' method on Player."*
- **Self-Debugging:**
  > *"Check the editor logs for errors, locate the script that failed, and fix the syntax error."*
- **Visual Inspection:**
  > *"Take a screenshot of the 3D viewport and verify if the lighting and player placement look correct."*

---

## Configuration & Advanced Options

### Port Configuration
By default, the plugin and MCP server communicate over TCP port `6505` on `127.0.0.1`.

If port `6505` is in use:
1. In `addons/godot_ai_mcp/mcp_server.gd`, change:
   ```gdscript
   const PORT := 6505
   ```
2. In your AI client configuration, pass the custom port via environment variable or argument:
   ```json
   {
     "mcpServers": {
       "godot-ai-mcp": {
         "command": "npx",
         "args": ["-y", "godot-ai-mcp"],
         "env": {
           "GODOT_PORT": "6510"
         }
       }
     }
   }
   ```

### Timeout
Tool requests have a 15-second timeout by default. Long GDScript execution tasks can be handled by breaking them into smaller steps or executing asynchronously via custom scripts.

---

## Troubleshooting

### Bottom panel shows "🔴 MCP: No clients connected"
1. Verify that your AI assistant is running and that the configuration file contains `npx -y godot-ai-mcp`.
2. Restart your AI client (e.g. fully quit and reopen Claude Desktop or Cursor).
3. Ensure no firewall or antivirus is blocking local connections to `127.0.0.1:6505`.

### Port already in use (`ERR_ALREADY_IN_USE`)
If you reloaded Godot without cleanly disabling the plugin, the previous port binding might linger for a few seconds.
- Disable and re-enable the plugin in **Project Settings → Plugins**.
- Or restart the Godot editor.

### "Not connected to Godot editor" error in AI chat
This indicates the MCP server process started, but Godot is not running or the plugin is disabled. Open your project in Godot and ensure **Godot AI MCP** is toggled **On** under **Project Settings → Plugins**.

---

## Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the repository at [github.com/event-horizon-studio/godot-ai-mcp](https://github.com/event-horizon-studio/godot-ai-mcp).
2. Create a feature branch: `git checkout -b feature/my-new-feature`.
3. Commit your changes: `git commit -am 'Add some feature'`.
4. Push to the branch: `git push origin feature/my-new-feature`.
5. Open a Pull Request.

---

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.
