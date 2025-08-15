// Basic type definitions for the AI Chat Backend

export interface ChatMessage {
  id: string;
  message: string;
  model: string;
  sessionId?: string;
  temperature?: number;
  maxTokens?: number;
  timestamp: string;
}

export interface Session {
  id: string;
  title: string;
  model: string;
  created_at: string;
  updated_at: string;
  message_count: number;
}

export interface Settings {
  [key: string]: string | number | boolean;
}

export interface ApiKeyInfo {
  provider: string;
  isSet: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface ValidationError {
  field: string;
  message: string;
}

export interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  details?: ValidationError[];
}