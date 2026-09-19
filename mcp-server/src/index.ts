#!/usr/bin/env node

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { GodotBridge } from './bridge.js';
import { registerEditorTools } from './tools/editor.js';
import { registerSceneTools } from './tools/scene.js';
import { registerScriptTools } from './tools/script.js';
import { registerViewportTools } from './tools/viewport.js';
import { registerReflectionTools } from './tools/reflection.js';

async function main() {
    const bridge = new GodotBridge();
    
    // Connect to Godot in the background
    bridge.connect();

    const server = new McpServer({
        name: 'godot-ai-mcp',
        version: '1.0.0'
    });

    registerEditorTools(server, bridge);
    registerSceneTools(server, bridge);
    registerScriptTools(server, bridge);
    registerViewportTools(server, bridge);
    registerReflectionTools(server, bridge);

    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error('Godot AI MCP Server running on stdio');

    process.on('SIGINT', () => {
        bridge.disconnect();
        server.close();
        process.exit(0);
    });

    process.on('SIGTERM', () => {
        bridge.disconnect();
        server.close();
        process.exit(0);
    });
}

main().catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
});
