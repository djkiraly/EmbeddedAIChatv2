const Joi = require('joi');
const validator = require('validator');
const logger = require('../config/logger');

// Validation schemas
const schemas = {
  // Chat message validation
  chatMessage: Joi.object({
    message: Joi.string().required().min(1).max(10000).trim(),
    model: Joi.string().required().min(1).max(100),
    sessionId: Joi.string().uuid().optional(),
    temperature: Joi.number().min(0).max(2).optional(),
    maxTokens: Joi.number().min(1).max(8000).optional()
  }),

  // Settings validation
  settings: Joi.object({
    key: Joi.string().required().min(1).max(100).pattern(/^[a-zA-Z0-9_-]+$/),
    value: Joi.alternatives().try(
      Joi.string().max(1000),
      Joi.number(),
      Joi.boolean()
    ).required()
  }),

  // API key validation
  apiKey: Joi.object({
    provider: Joi.string().valid('openai', 'anthropic').required(),
    apiKey: Joi.string().required().min(10).max(200)
  }),

  // Session ID validation
  sessionId: Joi.object({
    id: Joi.string().uuid().required()
  })
};

// Generic validation middleware
const validate = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body, { 
      abortEarly: false,
      stripUnknown: true
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.warn('Validation failed', { 
        url: req.originalUrl, 
        method: req.method, 
        errors 
      });

      return res.status(400).json({
        error: 'Validation failed',
        details: errors
      });
    }

    next();
  };
};

// Parameter validation middleware
const validateParams = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.params, { 
      abortEarly: false 
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.warn('Parameter validation failed', { 
        url: req.originalUrl, 
        method: req.method, 
        errors 
      });

      return res.status(400).json({
        error: 'Invalid parameters',
        details: errors
      });
    }

    next();
  };
};

// Sanitization middleware
const sanitize = (req, res, next) => {
  // Sanitize string inputs
  const sanitizeObject = (obj) => {
    if (typeof obj === 'string') {
      return validator.escape(obj.trim());
    } else if (Array.isArray(obj)) {
      return obj.map(sanitizeObject);
    } else if (obj && typeof obj === 'object') {
      const sanitized = {};
      for (const [key, value] of Object.entries(obj)) {
        sanitized[key] = sanitizeObject(value);
      }
      return sanitized;
    }
    return obj;
  };

  // Sanitize request body
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }

  // Sanitize query parameters
  if (req.query && typeof req.query === 'object') {
    req.query = sanitizeObject(req.query);
  }

  next();
};

// Rate limiting by IP and endpoint
const createRateLimit = (windowMs = 15 * 60 * 1000, max = 100) => {
  const rateLimit = require('express-rate-limit');
  
  return rateLimit({
    windowMs,
    max,
    message: {
      error: 'Too many requests from this IP, please try again later.',
      retryAfter: Math.ceil(windowMs / 1000)
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      logger.warn('Rate limit exceeded', {
        ip: req.ip,
        url: req.originalUrl,
        method: req.method
      });
      
      res.status(429).json({
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: Math.ceil(windowMs / 1000)
      });
    }
  });
};

module.exports = {
  schemas,
  validate,
  validateParams,
  sanitize,
  createRateLimit
};