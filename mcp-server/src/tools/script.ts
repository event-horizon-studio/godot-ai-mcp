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

export function registerScriptTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_execute_gdscript',
        'Execute arbitrary GDScript code inside the Godot Editor context. Has access to EditorInterface, ClassDB, etc.',
        {
            code: z.string().describe('GDScript code to execute')
        },
        async ({ code }) => {
            try {
                const res = await bridge.sendRequest('execute_gdscript', { code });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_create_script',
        'Create a new .gd file with specified content, and optionally attach it to a node.',
        {
            script_path: z.string().describe('Path for the new script, e.g., res://scripts/player.gd'),
            content: z.string().describe('GDScript source code content'),
            attach_to: z.string().optional().describe('Node path to attach the script to, if desired')
        },
        async ({ script_path, content, attach_to }) => {
            try {
                const res = await bridge.sendRequest('create_script', { script_path, content, attach_to });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_read_script',
        'Read the source code of a GDScript file from the project.',
        {
            script_path: z.string().describe('Resource path to the script, e.g., res://scripts/player.gd')
        },
        async ({ script_path }) => {
            try {
                const res = await bridge.sendRequest('read_script', { script_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
