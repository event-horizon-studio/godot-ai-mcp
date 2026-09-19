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

export function registerSceneTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_get_scene_tree',
        'Get the full scene tree hierarchy for the active scene.',
        {
            max_depth: z.number().optional().describe('Maximum depth to traverse. -1 for unlimited.')
        },
        async ({ max_depth = -1 }) => {
            try {
                const res = await bridge.sendRequest('get_scene_tree', { max_depth });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_get_node_info',
        'Get detailed information about a specific node.',
        {
            node_path: z.string().describe('Path to the node, e.g., Player/CollisionShape3D')
        },
        async ({ node_path }) => {
            try {
                const res = await bridge.sendRequest('get_node_info', { node_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_create_node',
        'Create a new node in the scene tree with undo/redo support.',
        {
            parent_path: z.string().describe('Path to the parent node'),
            node_type: z.string().describe('Godot class name, e.g., CharacterBody3D'),
            node_name: z.string().describe('Name for the new node')
        },
        async ({ parent_path, node_type, node_name }) => {
            try {
                const res = await bridge.sendRequest('create_node', { parent_path, node_type, node_name });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_modify_node_property',
        'Modify a property on an existing node with undo/redo support.',
        {
            node_path: z.string().describe('Path to the node'),
            property: z.string().describe('Name of the property to change'),
            value: z.any().describe('New value for the property')
        },
        async ({ node_path, property, value }) => {
            try {
                const res = await bridge.sendRequest('modify_node_property', { node_path, property, value });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_delete_node',
        'Delete a node from the scene tree with undo/redo support.',
        {
            node_path: z.string().describe('Path to the node to delete')
        },
        async ({ node_path }) => {
            try {
                const res = await bridge.sendRequest('delete_node', { node_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_reparent_node',
        'Move a node to a new parent in the scene tree with undo/redo support.',
        {
            node_path: z.string().describe('Path to the node to move'),
            new_parent_path: z.string().describe('Path to the new parent node')
        },
        async ({ node_path, new_parent_path }) => {
            try {
                const res = await bridge.sendRequest('reparent_node', { node_path, new_parent_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
