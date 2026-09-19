import * as net from 'node:net';
import * as crypto from 'node:crypto';

interface PendingRequest {
    resolve: (value: any) => void;
    reject: (reason?: any) => void;
    timer: NodeJS.Timeout;
}

export class GodotBridge {
    private socket: net.Socket | null = null;
    private buffer = '';
    private pendingRequests = new Map<string, PendingRequest>();
    private reconnectTimer: NodeJS.Timeout | null = null;
    private reconnectDelay = 1000;
    private maxReconnectDelay = 10000;
    
    private state: 'connected' | 'disconnected' | 'reconnecting' = 'disconnected';
    private onConnectionChangeCallback?: (state: string) => void;

    constructor(
        private host: string = '127.0.0.1',
        private port: number = 6505
    ) {}

    isConnected() {
        return this.state === 'connected';
    }

    onConnectionChange(cb: (state: string) => void) {
        this.onConnectionChangeCallback = cb;
    }

    private setState(newState: 'connected' | 'disconnected' | 'reconnecting') {
        if (this.state !== newState) {
            this.state = newState;
            if (this.onConnectionChangeCallback) {
                this.onConnectionChangeCallback(newState);
            }
        }
    }

    connect() {
        if (this.state === 'connected' || this.state === 'reconnecting') return;
        
        this.setState('reconnecting');
        this.socket = new net.Socket();
        
        this.socket.on('connect', () => {
            this.setState('connected');
            this.reconnectDelay = 1000; // Reset backoff
            if (this.reconnectTimer) {
                clearTimeout(this.reconnectTimer);
                this.reconnectTimer = null;
            }
        });

        this.socket.on('data', (data) => {
            this.buffer += data.toString();
            let newlineIdx;
            while ((newlineIdx = this.buffer.indexOf('\n')) !== -1) {
                const line = this.buffer.slice(0, newlineIdx);
                this.buffer = this.buffer.slice(newlineIdx + 1);
                
                if (line.trim()) {
                    try {
                        const msg = JSON.parse(line);
                        this.handleMessage(msg);
                    } catch (e) {
                        console.error('Failed to parse incoming message:', line);
                    }
                }
            }
        });

        this.socket.on('error', (err) => {
            console.error('Godot Bridge TCP Error:', err.message);
        });

        this.socket.on('close', () => {
            this.setState('disconnected');
            this.socket = null;
            
            // Fail all pending requests
            for (const [id, req] of this.pendingRequests.entries()) {
                clearTimeout(req.timer);
                req.reject(new Error('Connection to Godot closed'));
                this.pendingRequests.delete(id);
            }

            // Auto-reconnect
            this.reconnectTimer = setTimeout(() => {
                this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
                this.connect();
            }, this.reconnectDelay);
        });

        this.socket.connect(this.port, this.host);
    }

    disconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        if (this.socket) {
            this.socket.destroy();
            this.socket = null;
        }
        this.setState('disconnected');
    }

    private handleMessage(msg: any) {
        if (msg.id && this.pendingRequests.has(msg.id)) {
            const req = this.pendingRequests.get(msg.id)!;
            clearTimeout(req.timer);
            this.pendingRequests.delete(msg.id);
            
            if (msg.error) {
                req.reject(msg.error);
            } else {
                req.resolve(msg.result);
            }
        }
    }

    sendRequest(method: string, params: Record<string, unknown> = {}): Promise<any> {
        return new Promise((resolve, reject) => {
            if (!this.isConnected() || !this.socket) {
                return reject(new Error('Not connected to Godot editor. Please ensure Godot is running with the MCP plugin enabled.'));
            }

            const id = crypto.randomUUID();
            const payload = JSON.stringify({ id, method, params }) + '\n';
            
            const timer = setTimeout(() => {
                if (this.pendingRequests.has(id)) {
                    this.pendingRequests.delete(id);
                    reject(new Error(`Request timeout for method: ${method}`));
                }
            }, 15000);

            this.pendingRequests.set(id, { resolve, reject, timer });
            
            this.socket.write(payload, (err) => {
                if (err) {
                    clearTimeout(timer);
                    this.pendingRequests.delete(id);
                    reject(err);
                }
            });
        });
    }
}
