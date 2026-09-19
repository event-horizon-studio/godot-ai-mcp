import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { GodotBridge } from '../bridge.js';

function formatError(error: any) {
    return {
        isError: true,
        content: [{ type: 'text' as const, text: error instanceof Error ? error.message : JSON.stringify(error) }]
    };
}

export function registerViewportTools(server: McpServer, bridge: GodotBridge) {
    server.tool('godot_get_viewport_screenshot',
        'Capture a screenshot of a specific Godot Editor viewport.',
        {
            viewport: z.enum(['2d', '3d']).optional().describe('Which viewport to capture. Defaults to 3d.')
        },
        async ({ viewport = '3d' }) => {
            try {
                const res = await bridge.sendRequest('get_viewport_screenshot', { viewport });
                return {
                    content: [{
                        type: 'image' as const,
                        data: res.image_base64,
                        mimeType: 'image/png'
                    }]
                };
            } catch (e) {
                return formatError(e);
            }
        }
    );
}
