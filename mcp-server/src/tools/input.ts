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

export function registerInputTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_get_input_actions',
        'List all configured input actions and their key/button bindings from ProjectSettings.',
        {},
        async () => {
            try {
                const res = await bridge.sendRequest('get_input_actions');
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_add_input_action',
        'Add a new input action (e.g. move_left, jump) with key/mouse bindings to ProjectSettings and save.',
        {
            action: z.string().describe('The action name, e.g. move_forward, jump, attack'),
            deadzone: z.number().optional().describe('Deadzone for analog inputs (default: 0.5)'),
            keys: z.array(z.string()).optional().describe('Key names to bind, e.g. ["W", "Up", "Space"]'),
            mouse_buttons: z.array(z.number()).optional().describe('Mouse button indices (1 = Left, 2 = Right, 3 = Middle)')
        },
        async ({ action, deadzone = 0.5, keys = [], mouse_buttons = [] }) => {
            try {
                const res = await bridge.sendRequest('add_input_action', { action, deadzone, keys, mouse_buttons });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );

    server.tool('godot_set_project_setting',
        'Set any ProjectSettings property (e.g. physics/common/physics_ticks_per_second, display/window/size/viewport_width) and save.',
        {
            setting: z.string().describe('Setting path, e.g. physics/2d/default_gravity'),
            value: z.any().describe('The value to set')
        },
        async ({ setting, value }) => {
            try {
                const res = await bridge.sendRequest('set_project_setting', { setting, value });
                return formatResult(res);
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
