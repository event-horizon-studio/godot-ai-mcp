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

export function registerResourceTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_create_material',
        'Create a StandardMaterial3D with albedo color, roughness, metallic, and optional emission, optionally saving it to a .tres file.',
        {
            save_path: z.string().optional().describe('Resource path to save, e.g. res://materials/player_mat.tres'),
            albedo_color: z.union([
                z.string(),
                z.object({ r: z.number(), g: z.number(), b: z.number(), a: z.number().optional() })
            ]).optional().describe('Albedo color as hex string "#ff0000" or RGBA object'),
            roughness: z.number().optional().describe('Roughness from 0.0 to 1.0 (default: 0.5)'),
            metallic: z.number().optional().describe('Metallic from 0.0 to 1.0 (default: 0.0)'),
            emission_color: z.union([
                z.string(),
                z.object({ r: z.number(), g: z.number(), b: z.number(), a: z.number().optional() })
            ]).optional().describe('Emission color as hex string or RGBA object'),
            emission_energy_multiplier: z.number().optional().describe('Emission strength multiplier (default: 1.0)')
        },
        async ({ save_path, albedo_color, roughness = 0.5, metallic = 0.0, emission_color, emission_energy_multiplier = 1.0 }) => {
            try {
                const res = await bridge.sendRequest('create_material', {
                    save_path,
                    albedo_color,
                    roughness,
                    metallic,
                    emission_color,
                    emission_energy_multiplier
                });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
