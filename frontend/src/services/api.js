import axios from 'axios';

// Create axios instance with default config
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || '/api',
  timeout: 30000, // 30 seconds timeout for AI requests
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    // Add any auth headers or other common headers here
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => {
    return response.data;
  },
  (error) => {
    // Handle common error cases
    let errorMessage = 'An unexpected error occurred';
    
    if (error.response) {
      // Server responded with error status
      errorMessage = error.response.data?.error || error.response.data?.message || errorMessage;
    } else if (error.request) {
      // Request was made but no response received
      errorMessage = 'No response from server. Please check your connection.';
    } else if (error.code === 'ECONNABORTED') {
      // Request timeout
      errorMessage = 'Request timeout. The server took too long to respond.';
    } else {
      // Something else happened
      errorMessage = error.message || errorMessage;
    }
    
    const enhancedError = new Error(errorMessage);
    enhancedError.response = error.response;
    enhancedError.status = error.response?.status;
    
    return Promise.reject(enhancedError);
  }
);

// Chat service
export const chatService = {
  // Send message to AI
  sendMessage: async (data) => {
    // Use longer timeout for image models
    const isImageModel = data.model && (
      data.model.includes('dall-e') || 
      data.model.includes('gpt-image')
    );
    const timeout = isImageModel ? 300000 : 30000; // 5 minutes for images, 30 seconds for text
    
    return await api.post('/chat', data, { timeout });
  },

  // Get available models
  getModels: async () => {
    return await api.get('/models');
  },

  // Get chat sessions
  getSessions: async (limit = 50) => {
    return await api.get(`/sessions?limit=${limit}`);
  },

  // Get specific session
  getSession: async (sessionId) => {
    return await api.get(`/sessions/${sessionId}`);
  },

  // Get messages for a session
  getSessionMessages: async (sessionId, limit = 100) => {
    return await api.get(`/sessions/${sessionId}/messages?limit=${limit}`);
  },

  // Delete session
  deleteSession: async (sessionId) => {
    return await api.delete(`/sessions/${sessionId}`);
  },

  // Settings endpoints
  getSettings: async () => {
    return await api.get('/settings');
  },

  updateSettings: async (data) => {
    return await api.put('/settings', data);
  },

  getSetting: async (key) => {
    return await api.get(`/settings/${key}`);
  },

  updateSetting: async (key, value) => {
    return await api.put(`/settings/${key}`, { value });
  },

  deleteSetting: async (key) => {
    return await api.delete(`/settings/${key}`);
  },

  testApiKey: async (provider, apiKey) => {
    return await api.post('/settings/test-api-key', { provider, apiKey });
  },
};

// Reporting service
export const reportService = {
  // Get usage report
  getReport: async () => {
    return await api.get('/report');
  },

  // Get sessions report
  getSessionsReport: async (limit = 50, offset = 0) => {
    return await api.get(`/report/sessions?limit=${limit}&offset=${offset}`);
  },

  // Get models report
  getModelsReport: async () => {
    return await api.get('/report/models');
  },

  // Export data
  exportData: async (format = 'json', includeMessages = false) => {
    const params = new URLSearchParams({
      format,
      include_messages: includeMessages.toString()
    });
    
    const response = await axios({
      method: 'GET',
      url: `${process.env.REACT_APP_API_URL || '/api'}/report/export?${params}`,
      responseType: 'blob',
    });
    
    return response;
  },
};

// Health check
export const healthService = {
  check: async () => {
    return await api.get('/health', { baseURL: process.env.REACT_APP_API_URL || '' });
  },
};

// Utility functions
export const apiUtils = {
  // Check if error is network related
  isNetworkError: (error) => {
    return !error.response && error.request;
  },

  // Check if error is timeout
  isTimeoutError: (error) => {
    return error.code === 'ECONNABORTED';
  },

  // Check if error is server error (5xx)
  isServerError: (error) => {
    return error.status && error.status >= 500;
  },

  // Check if error is client error (4xx)
  isClientError: (error) => {
    return error.status && error.status >= 400 && error.status < 500;
  },

  // Format error for user display
  formatError: (error) => {
    if (apiUtils.isNetworkError(error)) {
      return 'Connection error. Please check your internet connection.';
    }
    
    if (apiUtils.isTimeoutError(error)) {
      return 'Request timeout. The server is taking too long to respond.';
    }
    
    if (apiUtils.isServerError(error)) {
      return 'Server error. Please try again later.';
    }
    
    return error.message || 'An unexpected error occurred.';
  },
};

export default api; 