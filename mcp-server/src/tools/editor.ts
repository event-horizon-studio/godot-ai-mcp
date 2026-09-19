import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { GodotBridge } from '../bridge.js';

function formatResult(result: any) {
    return {
        content: [{ type: 'text' as const, text: JSON.stringify(result, null, 2) }]
    };
}

function formatError(error: any) {
    return {
        isError: true,
        content: [{ type: 'text' as const, text: error instanceof Error ? error.message : JSON.stringify(error) }]
    };
}

export function registerEditorTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_get_editor_status',
        'Get the status of the Godot editor, including version, current scene, project name, and plugin status.',
        {},
        async () => {
            try {
                const res = await bridge.sendRequest('get_editor_status');
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_open_scene',
        'Open a specific scene in the Godot editor.',
        {
            scene_path: z.string().describe('Resource path like res://scenes/main.tscn')
        },
        async ({ scene_path }) => {
            try {
                const res = await bridge.sendRequest('open_scene', { scene_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_save_scene',
        'Save the currently open scene in the Godot editor.',
        {},
        async () => {
            try {
                const res = await bridge.sendRequest('save_scene');
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_run_project',
        'Run the Godot project. Optionally run a specific scene.',
        {
            scene_path: z.string().optional().describe('Resource path to specific scene. If omitted, runs the main scene.')
        },
        async ({ scene_path }) => {
            try {
                const res = await bridge.sendRequest('run_project', { scene_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_stop_project',
        'Stop the running Godot project execution.',
        {},
        async () => {
            try {
                const res = await bridge.sendRequest('stop_project');
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_get_editor_logs',
        'Retrieve the most recent Godot engine/editor log messages and errors for self-debugging.',
        {
            line_count: z.number().optional().describe('Number of recent log lines to retrieve (default: 50)')
        },
        async ({ line_count = 50 }) => {
            try {
                const res = await bridge.sendRequest('get_editor_logs', { line_count });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_get_editor_output',
        'Capture the exact live text, errors, warnings, and print statements currently visible in the Godot Output dock at the bottom of the editor.',
        {
            line_count: z.number().optional().describe('Number of recent lines to retrieve from the Output dock (default: 50)')
        },
        async ({ line_count = 50 }) => {
            try {
                const res = await bridge.sendRequest('get_editor_output', { line_count });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
