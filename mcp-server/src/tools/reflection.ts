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

export function registerReflectionTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_api_lookup',
        'Look up detailed API information for a Godot class via ClassDB.',
        {
            class_name: z.string().describe('The name of the class to look up, e.g. Node3D'),
            include_inherited: z.boolean().optional().describe('Whether to include inherited methods and properties')
        },
        async ({ class_name, include_inherited = false }) => {
            try {
                const res = await bridge.sendRequest('api_lookup', { class_name, include_inherited });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_list_project_files',
        'List files within the Godot project directory.',
        {
            directory: z.string().optional().describe('The directory to search in. Defaults to res://'),
            extensions: z.array(z.string()).optional().describe('Array of file extensions to include, e.g. [".gd", ".tscn"]'),
            recursive: z.boolean().optional().describe('Whether to search recursively. Defaults to true.')
        },
        async ({ directory = 'res://', extensions, recursive = true }) => {
            try {
                const res = await bridge.sendRequest('list_project_files', { directory, extensions, recursive });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
