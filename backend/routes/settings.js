const express = require('express');
const router = express.Router();
const { validate, validateParams, sanitize, schemas } = require('../middleware/validation');
const logger = require('../config/logger');

// Get all settings
router.get('/settings', async (req, res) => {
  try {
    const Settings = req.app.locals.models.Settings;
    
    const settings = await Settings.getAll();
    const apiKeys = await Settings.getAllApiKeys();
    
    res.json({
      settings,
      apiKeys
    });
  } catch (error) {
    logger.error('Get settings error:', error.message);
    res.status(500).json({ error: 'Failed to get settings' });
  }
});

// Update settings
router.put('/settings', async (req, res) => {
  try {
    const Settings = req.app.locals.models.Settings;
    const { settings, apiKeys } = req.body;
    
    // Update general settings
    if (settings && typeof settings === 'object') {
      await Settings.setMultiple(settings);
    }
    
    // Update API keys
    if (apiKeys && typeof apiKeys === 'object') {
      for (const [provider, key] of Object.entries(apiKeys)) {
        if (key && key.trim()) {
          await Settings.setApiKey(provider, key.trim());
        }
      }
    }
    
    // Return updated settings
    const updatedSettings = await Settings.getAll();
    const updatedApiKeys = await Settings.getAllApiKeys();
    
    res.json({
      message: 'Settings updated successfully',
      settings: updatedSettings,
      apiKeys: updatedApiKeys
    });
  } catch (error) {
    console.error('Update settings error:', error);
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

// Get specific setting
router.get('/settings/:key', async (req, res) => {
  try {
    const { key } = req.params;
    const Settings = req.app.locals.models.Settings;
    
    const value = await Settings.get(key);
    if (value === null) {
      return res.status(404).json({ error: 'Setting not found' });
    }
    
    res.json({ key, value });
  } catch (error) {
    console.error('Get setting error:', error);
    res.status(500).json({ error: 'Failed to get setting' });
  }
});

// Update specific setting
router.put('/settings/:key', async (req, res) => {
  try {
    const { key } = req.params;
    const { value } = req.body;
    const Settings = req.app.locals.models.Settings;
    
    if (value === undefined) {
      return res.status(400).json({ error: 'Value is required' });
    }
    
    await Settings.set(key, value.toString());
    res.json({ key, value, message: 'Setting updated successfully' });
  } catch (error) {
    console.error('Update setting error:', error);
    res.status(500).json({ error: 'Failed to update setting' });
  }
});

// Delete setting
router.delete('/settings/:key', async (req, res) => {
  try {
    const { key } = req.params;
    const Settings = req.app.locals.models.Settings;
    
    const result = await Settings.delete(key);
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Setting not found' });
    }
    
    res.json({ message: 'Setting deleted successfully' });
  } catch (error) {
    console.error('Delete setting error:', error);
    res.status(500).json({ error: 'Failed to delete setting' });
  }
});

// Test API key
router.post('/settings/test-api-key', async (req, res) => {
  try {
    const { provider, apiKey } = req.body;
    
    if (!provider || !apiKey) {
      return res.status(400).json({ error: 'Provider and API key are required' });
    }
    
    const LLMService = require('../services/llmService');
    const llmService = new LLMService();
    
    // Test with a simple message
    const testMessages = [
      { role: 'user', content: 'Hello, this is a test message. Please respond with "API key test successful".' }
    ];
    
    const apiKeys = { [provider]: apiKey };
    const settings = { max_tokens: '50', temperature: '0' };
    
    // Determine which model to test based on provider
    let testModel;
    if (provider === 'openai') {
      testModel = 'gpt-3.5-turbo';
    } else if (provider === 'anthropic') {
      testModel = 'claude-3-haiku';
    } else {
      return res.status(400).json({ error: 'Unsupported provider' });
    }
    
    const response = await llmService.sendMessage(testModel, testMessages, apiKeys, settings);
    
    res.json({
      success: true,
      message: 'API key is valid',
      provider,
      testResponse: response.content.substring(0, 100) + '...'
    });
  } catch (error) {
    console.error('Test API key error:', error);
    res.status(400).json({
      success: false,
      error: error.message || 'API key test failed'
    });
  }
});

module.exports = router; 