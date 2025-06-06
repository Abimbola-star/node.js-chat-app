const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const promClient = require('prom-client');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Prometheus metrics setup
const collectDefaultMetrics = promClient.collectDefaultMetrics;
const Registry = promClient.Registry;
const register = new Registry();
collectDefaultMetrics({ register });

// Custom metrics
const activeConnectionsGauge = new promClient.Gauge({
    name: 'chat_active_connections',
    help: 'Number of active chat connections',
    registers: [register]
});

const messageCounter = new promClient.Counter({
    name: 'chat_messages_total',
    help: 'Total number of chat messages',
    registers: [register]
});

// Middleware
app.use(express.static(__dirname));
app.use(express.json());

// Store messages in memory (replace with database in production)
const chatHistory = [];
const activeUsers = new Set();

// Define route for the root path
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// Socket.io connection handling
io.on('connection', socket => {
    console.log('User connected');
    activeConnectionsGauge.inc();
    
    // Handle user joining
    socket.on('user_join', (username) => {
        activeUsers.add(username);
        socket.username = username;
        
        // Send welcome message
        socket.emit('message', {
            user: 'System',
            text: `Welcome to the chat, ${username}!`,
            time: new Date().toLocaleTimeString()
        });
        
        // Notify others
        socket.broadcast.emit('message', {
            user: 'System',
            text: `${username} has joined the chat`,
            time: new Date().toLocaleTimeString()
        });
        
        // Send chat history to new user
        chatHistory.forEach(msg => {
            socket.emit('message', msg);
        });
        
        // Update user list for everyone
        io.emit('update_users', Array.from(activeUsers));
    });
    
    // Handle chat messages
    socket.on('send_message', (messageText) => {
        const message = {
            user: socket.username || 'Anonymous',
            text: messageText,
            time: new Date().toLocaleTimeString()
        };
        
        // Store in history (limit to last 50 messages)
        chatHistory.push(message);
        if (chatHistory.length > 50) {
            chatHistory.shift();
        }
        
        // Increment message counter for Prometheus
        messageCounter.inc();
        
        // Broadcast to all clients
        io.emit('message', message);
    });
    
    // Handle typing indicator
    socket.on('typing', (isTyping) => {
        socket.broadcast.emit('user_typing', {
            user: socket.username,
            isTyping: isTyping
        });
    });
    
    // Handle disconnection
    socket.on('disconnect', () => {
        console.log('User disconnected');
        activeConnectionsGauge.dec();
        if (socket.username) {
            activeUsers.delete(socket.username);
            io.emit('message', {
                user: 'System',
                text: `${socket.username} has left the chat`,
                time: new Date().toLocaleTimeString()
            });
            io.emit('update_users', Array.from(activeUsers));
        }
    });
});

// Start server on port 3000 for the chat app and 9100 for metrics
server.listen(3000, () => console.log('Chat app running on port 3000'));