
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

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

// Socket.io connection handling
io.on('connection', socket => {
    console.log('User connected');
    
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

server.listen(3000, () => console.log('Chat app running on port 3000'));
