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

    server.tool('godot_connect_signal',
        'Connect a signal from a source node to a target node method with undo/redo support.',
        {
            source_path: z.string().describe('Path to the node emitting the signal, e.g. Button or Area3D'),
            signal_name: z.string().describe('Name of the signal, e.g. pressed, body_entered'),
            target_path: z.string().describe('Path to the target node with the receiving method'),
            method_name: z.string().describe('Name of the receiving method, e.g. _on_button_pressed')
        },
        async ({ source_path, signal_name, target_path, method_name }) => {
            try {
                const res = await bridge.sendRequest('connect_signal', { source_path, signal_name, target_path, method_name });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_get_node_connections',
        'List all outgoing signal connections for a given node.',
        {
            node_path: z.string().describe('Path to the node')
        },
        async ({ node_path }) => {
            try {
                const res = await bridge.sendRequest('get_node_connections', { node_path });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_create_primitive_mesh',
        'Create a MeshInstance3D with a primitive mesh (box, sphere, capsule, cylinder, plane) in one step with undo/redo support.',
        {
            parent_path: z.string().describe('Path to the parent node'),
            mesh_type: z.enum(['box', 'sphere', 'capsule', 'cylinder', 'plane']).describe('Type of primitive mesh'),
            node_name: z.string().optional().describe('Name for the MeshInstance3D (default: MeshInstance3D)'),
            size: z.object({ x: z.number(), y: z.number(), z: z.number() }).optional().describe('Size vector for box/plane'),
            radius: z.number().optional().describe('Radius for sphere/capsule/cylinder (default: 0.5)'),
            height: z.number().optional().describe('Height for capsule/cylinder (default: 2.0)'),
            material_path: z.string().optional().describe('Optional resource path to a material (.tres) to apply')
        },
        async ({ parent_path, mesh_type, node_name = 'MeshInstance3D', size, radius = 0.5, height = 2.0, material_path = '' }) => {
            try {
                const res = await bridge.sendRequest('create_primitive_mesh', {
                    parent_path,
                    mesh_type,
                    node_name,
                    size,
                    radius,
                    height,
                    material_path
                });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_create_collision_shape',
        'Create a CollisionShape3D with a specified 3D shape (box, sphere, capsule, cylinder) in one step with undo/redo support.',
        {
            parent_path: z.string().describe('Path to the parent physics body (e.g. CharacterBody3D, StaticBody3D, Area3D)'),
            shape_type: z.enum(['box', 'sphere', 'capsule', 'cylinder']).describe('Type of collision shape'),
            node_name: z.string().optional().describe('Name for the CollisionShape3D (default: CollisionShape3D)'),
            size: z.object({ x: z.number(), y: z.number(), z: z.number() }).optional().describe('Size vector for box shape'),
            radius: z.number().optional().describe('Radius for sphere/capsule/cylinder (default: 0.5)'),
            height: z.number().optional().describe('Height for capsule/cylinder (default: 2.0)')
        },
        async ({ parent_path, shape_type, node_name = 'CollisionShape3D', size, radius = 0.5, height = 2.0 }) => {
            try {
                const res = await bridge.sendRequest('create_collision_shape', {
                    parent_path,
                    shape_type,
                    node_name,
                    size,
                    radius,
                    height
                });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
