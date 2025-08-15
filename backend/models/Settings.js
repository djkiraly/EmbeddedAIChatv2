const crypto = require('crypto');

class Settings {
  constructor(db) {
    this.db = db;
  }

  get(key) {
    return new Promise((resolve, reject) => {
      const sql = 'SELECT value FROM settings WHERE key = ?';
      
      this.db.get(sql, [key], (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row ? row.value : null);
        }
      });
    });
  }

  getAll() {
    return new Promise((resolve, reject) => {
      const sql = 'SELECT key, value FROM settings';
      
      this.db.all(sql, [], (err, rows) => {
        if (err) {
          reject(err);
        } else {
          const settings = {};
          rows.forEach(row => {
            settings[row.key] = row.value;
          });
          resolve(settings);
        }
      });
    });
  }

  set(key, value) {
    return new Promise((resolve, reject) => {
      const sql = `
        INSERT OR REPLACE INTO settings (key, value, updated_at) 
        VALUES (?, ?, CURRENT_TIMESTAMP)
      `;
      
      this.db.run(sql, [key, value], function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ key, value });
        }
      });
    });
  }

  setMultiple(settings) {
    return new Promise((resolve, reject) => {
      const entries = Object.entries(settings);
      if (entries.length === 0) {
        resolve(settings);
        return;
      }

      const stmt = this.db.prepare(`
        INSERT OR REPLACE INTO settings (key, value, updated_at) 
        VALUES (?, ?, CURRENT_TIMESTAMP)
      `);

      let completed = 0;
      let hasError = false;
      let transactionStarted = false;

      const cleanup = (error) => {
        if (hasError) return;
        hasError = true;
        
        stmt.finalize(() => {
          if (transactionStarted) {
            this.db.run(error ? 'ROLLBACK' : 'COMMIT', (commitErr) => {
              if (error) {
                reject(error);
              } else if (commitErr) {
                reject(commitErr);
              } else {
                resolve(settings);
              }
            });
          } else {
            if (error) {
              reject(error);
            } else {
              resolve(settings);
            }
          }
        });
      };

      try {
        this.db.serialize(() => {
          this.db.run('BEGIN TRANSACTION', (err) => {
            if (err) {
              cleanup(err);
              return;
            }
            transactionStarted = true;
            
            entries.forEach(([key, value]) => {
              stmt.run(key, value, (runErr) => {
                if (runErr && !hasError) {
                  cleanup(runErr);
                  return;
                }
                
                completed++;
                if (completed === entries.length && !hasError) {
                  cleanup();
                }
              });
            });
          });
        });
      } catch (error) {
        cleanup(error);
      }
    });
  }

  delete(key) {
    return new Promise((resolve, reject) => {
      const sql = 'DELETE FROM settings WHERE key = ?';
      
      this.db.run(sql, [key], function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ changes: this.changes });
        }
      });
    });
  }

  // Generate encryption key from environment or use default (should be set in production)
  getEncryptionKey() {
    const key = process.env.ENCRYPTION_KEY || 'default-key-change-in-production-32-chars';
    return crypto.createHash('sha256').update(key).digest();
  }

  // Encrypt API key using AES-256-CBC
  encryptApiKey(apiKey) {
    const algorithm = 'aes-256-cbc';
    const key = this.getEncryptionKey();
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipheriv(algorithm, key, iv);
    let encrypted = cipher.update(apiKey, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    return iv.toString('hex') + ':' + encrypted;
  }

  // Decrypt API key
  decryptApiKey(encryptedData) {
    const algorithm = 'aes-256-cbc';
    const key = this.getEncryptionKey();
    const [ivHex, encrypted] = encryptedData.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    
    const decipher = crypto.createDecipheriv(algorithm, key, iv);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  // API Key management with AES-256 encryption
  setApiKey(provider, apiKey) {
    return new Promise((resolve, reject) => {
      try {
        const encryptedKey = this.encryptApiKey(apiKey);
        const sql = `
          INSERT OR REPLACE INTO api_keys (provider, key_hash, updated_at) 
          VALUES (?, ?, CURRENT_TIMESTAMP)
        `;
        
        this.db.run(sql, [provider, encryptedKey], function(err) {
          if (err) {
            reject(err);
          } else {
            resolve({ provider, set: true });
          }
        });
      } catch (error) {
        reject(new Error('Failed to encrypt API key: ' + error.message));
      }
    });
  }

  getApiKey(provider) {
    return new Promise((resolve, reject) => {
      // For security, we don't return the actual key, just whether it's set
      const sql = 'SELECT provider FROM api_keys WHERE provider = ?';
      
      this.db.get(sql, [provider], (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(!!row);
        }
      });
    });
  }

  getAllApiKeys() {
    return new Promise((resolve, reject) => {
      const sql = 'SELECT provider, created_at, updated_at FROM api_keys';
      
      this.db.all(sql, [], (err, rows) => {
        if (err) {
          reject(err);
        } else {
          const apiKeys = {};
          rows.forEach(row => {
            apiKeys[row.provider] = {
              isSet: true,
              created_at: row.created_at,
              updated_at: row.updated_at
            };
          });
          resolve(apiKeys);
        }
      });
    });
  }

  deleteApiKey(provider) {
    return new Promise((resolve, reject) => {
      const sql = 'DELETE FROM api_keys WHERE provider = ?';
      
      this.db.run(sql, [provider], function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ changes: this.changes });
        }
      });
    });
  }

  // Get actual API key for internal use (not exposed via API)
  getActualApiKey(provider) {
    return new Promise((resolve, reject) => {
      // First try to get from database
      const sql = 'SELECT key_hash FROM api_keys WHERE provider = ?';
      
      this.db.get(sql, [provider], (err, row) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (row && row.key_hash) {
          // Decrypt the stored key using AES-256
          try {
            const decryptedKey = this.decryptApiKey(row.key_hash);
            resolve(decryptedKey);
          } catch (decodeError) {
            // Log error without exposing sensitive details
            // Fallback to environment variables
            this.getEnvApiKey(provider, resolve);
          }
        } else {
          // Fallback to environment variables if no stored key
          this.getEnvApiKey(provider, resolve);
        }
      });
    });
  }

  // Helper method to get API key from environment variables
  getEnvApiKey(provider, resolve) {
    const envKeys = {
      'openai': process.env.OPENAI_API_KEY,
      'anthropic': process.env.ANTHROPIC_API_KEY
    };
    
    const envKey = envKeys[provider] || null;
    resolve(envKey);
  }
}

module.exports = Settings; 