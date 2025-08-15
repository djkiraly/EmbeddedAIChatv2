const express = require('express');
const router = express.Router();
const LLMService = require('../services/llmService');
const { validate, validateParams, sanitize, schemas } = require('../middleware/validation');
const logger = require('../config/logger');

// Initialize services
const llmService = new LLMService();

// Chat endpoint with validation
router.post('/chat', sanitize, validate(schemas.chatMessage), async (req, res) => {
  try {
    const { message, model, sessionId, temperature, maxTokens } = req.body;

    const db = req.app.locals.database.getDatabase();
    const Session = req.app.locals.models.Session;
    const Message = req.app.locals.models.Message;
    const Settings = req.app.locals.models.Settings;

    // Get current session or create new one
    let currentSession;
    if (sessionId) {
      currentSession = await Session.getById(sessionId);
      if (!currentSession) {
        return res.status(404).json({ error: 'Session not found' });
      }
    } else {
      // Create new session with appropriate title based on model type
      const isImageModel = llmService.isImageModel(model);
      const title = isImageModel 
        ? `Image: ${message.length > 30 ? message.substring(0, 30) + '...' : message}`
        : message.length > 50 ? message.substring(0, 50) + '...' : message;
      currentSession = await Session.create(title, model);
    }

    // Save user message
    const userMessage = await Message.create(
      currentSession.id,
      message,
      'user'
    );

    // Handle image generation vs text generation differently
    const isImageModel = llmService.isImageModel(model);
    
    let response, aiMessage;
    
    if (isImageModel) {
      // For image generation, we only need the current prompt
      const messages = [{ role: 'user', content: message }];
      
      // Get API keys and settings
      const settings = await Settings.getAll();
      const apiKeys = {
        openai: await Settings.getActualApiKey('openai'),
        anthropic: await Settings.getActualApiKey('anthropic')
      };

      console.log(`Generating image with ${model}: ${message.substring(0, 50)}...`);
      
      // Generate image
      response = await llmService.sendMessage(model, messages, apiKeys, settings);
      
      // Save AI response with image data
      aiMessage = await Message.create(
        currentSession.id,
        response.content, // This is the image URL
        'assistant',
        model,
        0, // No tokens for images
        'image',
        {
          prompt: response.prompt,
          revised_prompt: response.revised_prompt,
          image_url: response.content,
          size: settings.image_size || (model === 'dall-e-3' ? '1024x1024' : '512x512'),
          quality: model === 'dall-e-3' ? (settings.image_quality || 'standard') : undefined,
          style: model === 'dall-e-3' ? (settings.image_style || 'natural') : undefined
        }
      );
    } else {
      // For text generation, get conversation history
      const messageHistory = await Message.getBySessionId(currentSession.id);
      
      // Prepare messages for LLM
      const llmMessages = messageHistory.map(msg => ({
        role: msg.role,
        content: msg.content
      }));

      // Get API keys and settings
      const settings = await Settings.getAll();
      const apiKeys = {
        openai: await Settings.getActualApiKey('openai'),
        anthropic: await Settings.getActualApiKey('anthropic')
      };

      console.log('API Keys retrieved:', {
        openai: apiKeys.openai ? 'SET' : 'NOT SET',
        anthropic: apiKeys.anthropic ? 'SET' : 'NOT SET',
        selectedModel: model
      });

      // Call LLM
      response = await llmService.sendMessage(model, llmMessages, apiKeys, settings);

      // Save AI response
      aiMessage = await Message.create(
        currentSession.id,
        response.content,
        'assistant',
        model,
        response.usage?.total_tokens || 0,
        'text'
      );
    }

    // Update session
    await Session.update(currentSession.id, { model_used: model });

    res.json({
      message: aiMessage,
      session: {
        id: currentSession.id,
        title: currentSession.title
      },
      usage: response.usage || null
    });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ 
      error: error.message || 'Internal server error',
      type: error.message.includes('API key') ? 'api_key_error' : 'llm_error'
    });
  }
});

// Get available models
router.get('/models', (req, res) => {
  try {
    const models = llmService.getAvailableModels();
    res.json({ models });
  } catch (error) {
    console.error('Models error:', error);
    res.status(500).json({ error: 'Failed to get models' });
  }
});

// Get chat sessions
router.get('/sessions', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const Session = req.app.locals.models.Session;
    
    const sessions = await Session.getAll(limit);
    res.json({ sessions });
  } catch (error) {
    console.error('Sessions error:', error);
    res.status(500).json({ error: 'Failed to get sessions' });
  }
});

// Get session by ID
router.get('/sessions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const Session = req.app.locals.models.Session;
    const Message = req.app.locals.models.Message;
    
    const session = await Session.getById(id);
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const messages = await Message.getBySessionId(id);
    
    res.json({
      session,
      messages
    });
  } catch (error) {
    console.error('Session error:', error);
    res.status(500).json({ error: 'Failed to get session' });
  }
});

// Get messages for a session
router.get('/sessions/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 100;
    const Message = req.app.locals.models.Message;
    
    const messages = await Message.getBySessionId(id, limit);
    res.json({ messages });
  } catch (error) {
    console.error('Messages error:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

// Delete session
router.delete('/sessions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const Session = req.app.locals.models.Session;
    
    const result = await Session.delete(id);
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }
    
    res.json({ message: 'Session deleted successfully' });
  } catch (error) {
    console.error('Delete session error:', error);
    res.status(500).json({ error: 'Failed to delete session' });
  }
});

module.exports = router; 