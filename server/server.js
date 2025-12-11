const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// Configure CORS
app.use(cors());
app.use(express.json());

// Socket.IO setup with CORS
const io = socketIO(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Store active meetings and participants
const meetings = new Map();
const participants = new Map();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    activeMeetings: meetings.size,
    activeParticipants: participants.size
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // Join a meeting room
  socket.on('join-meeting', ({ meetingId, participantId, participantName, isHost }) => {
    console.log(`${participantName} (${participantId}) joining meeting ${meetingId}`);
    
    // Join the Socket.IO room
    socket.join(meetingId);
    
    // Store participant info
    participants.set(socket.id, {
      socketId: socket.id,
      participantId,
      participantName,
      meetingId,
      isHost
    });

    // Add to meeting
    if (!meetings.has(meetingId)) {
      meetings.set(meetingId, new Set());
    }
    meetings.get(meetingId).add(socket.id);

    // Notify others in the room
    socket.to(meetingId).emit('participant-joined', {
      participantId,
      participantName,
      isHost
    });

    // Send current participants to the new joiner
    const currentParticipants = Array.from(meetings.get(meetingId))
      .map(sid => participants.get(sid))
      .filter(p => p && p.socketId !== socket.id);
    
    socket.emit('existing-participants', currentParticipants);

    console.log(`Meeting ${meetingId} now has ${meetings.get(meetingId).size} participants`);
  });

  // WebRTC Signaling: Offer
  socket.on('offer', ({ meetingId, toParticipantId, offer }) => {
    const sender = participants.get(socket.id);
    console.log(`Offer from ${sender?.participantName} to ${toParticipantId}`);
    
    // Find the target participant's socket
    const targetSocket = Array.from(participants.entries())
      .find(([_, p]) => p.participantId === toParticipantId);
    
    if (targetSocket) {
      io.to(targetSocket[0]).emit('offer', {
        fromParticipantId: sender.participantId,
        fromParticipantName: sender.participantName,
        offer
      });
    }
  });

  // WebRTC Signaling: Answer
  socket.on('answer', ({ meetingId, toParticipantId, answer }) => {
    const sender = participants.get(socket.id);
    console.log(`Answer from ${sender?.participantName} to ${toParticipantId}`);
    
    // Find the target participant's socket
    const targetSocket = Array.from(participants.entries())
      .find(([_, p]) => p.participantId === toParticipantId);
    
    if (targetSocket) {
      io.to(targetSocket[0]).emit('answer', {
        fromParticipantId: sender.participantId,
        answer
      });
    }
  });

  // WebRTC Signaling: ICE Candidate
  socket.on('ice-candidate', ({ meetingId, toParticipantId, candidate }) => {
    const sender = participants.get(socket.id);
    
    // Find the target participant's socket
    const targetSocket = Array.from(participants.entries())
      .find(([_, p]) => p.participantId === toParticipantId);
    
    if (targetSocket) {
      io.to(targetSocket[0]).emit('ice-candidate', {
        fromParticipantId: sender.participantId,
        candidate
      });
    }
  });

  // Leave meeting
  socket.on('leave-meeting', ({ meetingId, participantId }) => {
    handleParticipantLeave(socket, meetingId, participantId);
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    const participant = participants.get(socket.id);
    
    if (participant) {
      handleParticipantLeave(socket, participant.meetingId, participant.participantId);
    }
  });
});

function handleParticipantLeave(socket, meetingId, participantId) {
  const participant = participants.get(socket.id);
  
  if (participant) {
    console.log(`${participant.participantName} left meeting ${meetingId}`);
    
    // Notify others
    socket.to(meetingId).emit('participant-left', {
      participantId: participant.participantId,
      participantName: participant.participantName
    });
    
    // Clean up
    socket.leave(meetingId);
    participants.delete(socket.id);
    
    if (meetings.has(meetingId)) {
      meetings.get(meetingId).delete(socket.id);
      
      // Remove meeting if empty
      if (meetings.get(meetingId).size === 0) {
        meetings.delete(meetingId);
        console.log(`Meeting ${meetingId} ended (no participants)`);
      }
    }
  }
}

const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || '0.0.0.0';

server.listen(PORT, HOST, () => {
  console.log(`🚀 WebRTC Signaling Server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`✅ Server ready to accept connections`);
});
