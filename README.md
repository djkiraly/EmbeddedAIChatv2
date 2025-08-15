# AI Chat Interface

A modern, full-stack AI chat application supporting multiple LLM providers (OpenAI GPT models, DALL-E, Anthropic Claude) with a beautiful React frontend and robust Node.js backend.

## ✨ Features

- **Multi-Provider AI Support**: OpenAI (GPT-3.5, GPT-4, DALL-E 2/3) and Anthropic (Claude 3)
- **Text & Image Generation**: Full support for text conversations and AI image creation
- **Session Management**: Persistent conversation history with SQLite database
- **Real-time UI**: Modern React interface with Tailwind CSS
- **Settings Management**: Configurable API keys, model parameters, and preferences
- **Usage Analytics**: Detailed reporting and usage statistics
- **Responsive Design**: Works seamlessly on desktop and mobile
- **Production Ready**: Full deployment automation for Linux servers

## 🚀 Quick Start

### Local Development

```bash
# Clone the repository
git clone https://github.com/djkiraly/EmbeddedAIChatv2.git
cd EmbeddedAIChatv2

# Install all dependencies
npm run install:all

# Configure API keys (create .env file from template)
# Edit backend/.env and add your API keys
nano backend/.env

# Start development servers
npm start
```

Visit `http://localhost:3000` to access the application.

### 🐧 Linux Production Deployment

For production deployment on Linux servers, use our automated installation scripts:

**Supported Distributions:**
- Ubuntu 18.04+ / Debian 9+
- CentOS 7+ / RHEL 7+ / Fedora 30+
- Other systemd-based distributions

**Prerequisites:**
- User with sudo privileges (do NOT run as root)
- Internet connection for package downloads
- 2GB+ RAM and 10GB+ disk space recommended

#### One-Line Installation
```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/djkiraly/EmbeddedAIChatv2/main/install.sh | bash
```

#### Manual Installation
```bash
# Clone the repository
git clone https://github.com/djkiraly/EmbeddedAIChatv2.git
cd EmbeddedAIChatv2

# Make scripts executable
chmod +x install.sh uninstall.sh update.sh

# Run installation
./install.sh
```

**What gets installed:**
- ✅ Node.js 20+ and all system dependencies
- ✅ Complete application with production build
- ✅ Backend systemd service for auto-start and management
- ✅ Nginx static file serving + API proxy configuration
- ✅ SQLite database with proper schema
- ✅ Security hardening and firewall setup
- ✅ Log rotation and monitoring
- ✅ Management tools and scripts

**Post-installation:**
```bash
# 1. Configure API keys (REQUIRED)
sudo -u aichat nano /opt/ai-chat-interface/backend/.env
# Add your OPENAI_API_KEY and/or ANTHROPIC_API_KEY

# 2. Restart services to apply configuration
ai-chat-manager restart

# 3. Check service status
ai-chat-manager status

# 4. Access the application
# Open http://your-server-ip in your browser
```

**Management commands:**
- `ai-chat-manager start` - Start backend and nginx services
- `ai-chat-manager stop` - Stop backend (nginx continues serving static files)
- `ai-chat-manager restart` - Restart backend and nginx services
- `ai-chat-manager status` - Check service status
- `ai-chat-manager logs backend` - View backend logs
- `ai-chat-manager logs nginx` - View nginx logs
- `ai-chat-manager update` - Update application from git and redeploy

**Service files:**
- Backend: `/etc/systemd/system/ai-chat-backend.service`
- Frontend: Static files served by nginx from `/var/www/html`
- Config: `/opt/ai-chat-interface/backend/.env`
- Logs: `/opt/ai-chat-interface/logs/`
- Web Files: `/var/www/html/` (React build output)

**Quick Reference:**
```bash
# Installation
curl -fsSL https://raw.githubusercontent.com/djkiraly/EmbeddedAIChatv2/main/install.sh | bash

# Service Management
ai-chat-manager start|stop|restart|status
ai-chat-manager logs backend|nginx
ai-chat-manager update

# File Locations
Frontend:     /var/www/html/
Backend:      /opt/ai-chat-interface/
Config:       /opt/ai-chat-interface/backend/.env
Database:     /opt/ai-chat-interface/data/database.sqlite
Logs:         /opt/ai-chat-interface/logs/
```

**Complete deployment documentation:** See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed Linux deployment guide, troubleshooting, and advanced configuration.

## 📋 Requirements

### Development
- Node.js 20+ and npm
- Git

### Production (Linux)
- Ubuntu 18.04+, CentOS 7+, Debian 9+, or Fedora 30+
- User with sudo privileges
- 2GB+ RAM recommended
- 10GB+ disk space

## 🏗️ Architecture

### Local Development
```
Frontend (React)     Backend (Express)     Database
Port 3000      ←→    Port 5000      ←→     SQLite
```

### Production Deployment
```
┌─────────────────────────────────────────────────────────────┐
│                         Nginx (Port 80)                     │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │   Static Files      │    │       API Proxy             │ │
│  │   /var/www/html     │    │    /api/* → localhost:5000  │ │
│  │   (React Build)     │    │                             │ │
│  └─────────────────────┘    └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                       │
                              ┌─────────────────┐
                              │    Backend      │
                              │   (Port 5000)   │
                              │   Express API   │
                              └─────────────────┘
                                       │
                              ┌─────────────────┐
                              │   SQLite DB     │
                              │   (Database)    │
                              └─────────────────┘
```

## 🛠️ Development

### Project Structure
```
ai-chat-interface/
├── frontend/          # React application
├── backend/           # Express API server
├── install.sh         # Linux production installer
├── uninstall.sh       # Linux uninstaller
├── update.sh          # Linux updater
├── DEPLOYMENT.md      # Linux deployment guide
└── package.json       # Root package with scripts
```

### Available Scripts

**Development:**
```bash
npm start              # Start both frontend and backend
npm run frontend:dev   # Start frontend only
npm run backend:dev    # Start backend only
npm run install:all    # Install all dependencies
```

**Production Management (Linux):**
```bash
ai-chat-manager start/stop/restart  # Backend and nginx control
ai-chat-manager status              # Service status
ai-chat-manager logs [backend|nginx] # View logs
ai-chat-manager update              # Update and redeploy application
```

### Environment Configuration

**Backend** (`.env`):
```env
# Environment
NODE_ENV=development

# Server Configuration
PORT=5000
HOST=0.0.0.0

# Database
DATABASE_PATH=./database.sqlite

# API Keys (Required)
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here

# CORS Origins
FRONTEND_URL=http://localhost:3000
CORS_ORIGIN=http://localhost:3000

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/backend.log
```

**Frontend** (`.env.local`):
```env
# API Configuration (Development)
REACT_APP_API_URL=http://localhost:5000/api

# Production builds use: REACT_APP_API_URL=http://localhost/api
```

## 🎨 Features in Detail

### Multi-Model Support
- **GPT-3.5 Turbo**: Fast, cost-effective conversations
- **GPT-4**: Advanced reasoning and complex tasks
- **DALL-E 2/3**: AI image generation from text descriptions
- **Claude 3**: Anthropic's advanced AI models (Haiku, Sonnet, Opus)

### Image Generation
- Support for DALL-E 2 and DALL-E 3
- Configurable image sizes, quality, and artistic styles
- Image download and full-view capabilities
- Prompt optimization and revision tracking

### Session Management
- Persistent conversation history
- Session titles and metadata
- Search and filter conversations
- Export conversation data

### Settings & Configuration
- API key management with testing
- Model parameter tuning (temperature, max tokens)
- Image generation settings
- Usage preferences and defaults

### Analytics & Reporting
- Usage statistics and token tracking
- Model performance metrics
- Session analytics and trends
- Data export capabilities

## 🔒 Security

### Development
- Environment variable configuration
- Input validation and sanitization
- Error handling and logging

### Production
- Dedicated service user (`aichat`)
- Systemd security features  
- Nginx static file serving with security headers
- API proxy with CORS protection
- Firewall configuration
- Log rotation and monitoring
- Automatic security updates

### Deployment Architecture
**Frontend**: React build files served directly by nginx from `/var/www/html`
- Static asset caching with long expiration times
- Gzip compression for optimal transfer
- Security headers (XSS protection, CSRF protection, etc.)
- SPA routing support with `try_files` directive

**Backend**: Node.js Express API server
- Systemd service management
- Process isolation and security restrictions
- Automatic restart on failure
- Structured logging to files

**Database**: SQLite with proper permissions
- Data directory: `/opt/ai-chat-interface/data/`
- Automatic schema initialization
- Regular backup capabilities

## 🚨 Troubleshooting

### Common Issues

**Port conflicts:**
```bash
# Check what's using ports
lsof -i :3000 -i :5000 -i :80
# Kill conflicting processes
kill -9 <PID>
```

**Database issues:**
```bash
# Reset database (development)
rm backend/database.sqlite
cd backend && npm run init-db

# Reset database (production)
sudo systemctl stop ai-chat-backend
sudo rm /opt/ai-chat-interface/data/database.sqlite
sudo -u aichat bash -c "cd /opt/ai-chat-interface/backend && npm run init-db"
sudo systemctl start ai-chat-backend
```

**Frontend not loading (Production):**
```bash
# Check if static files exist
ls -la /var/www/html/

# Verify nginx is serving files
curl -I http://localhost

# Rebuild and redeploy frontend
cd /opt/ai-chat-interface
sudo -u aichat npm run build
sudo rm -rf /var/www/html/*
sudo cp -r frontend/build/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html
sudo systemctl restart nginx
```

**API connection issues:**
```bash
# Check backend service status
ai-chat-manager status

# Test API directly
curl http://localhost/api/health

# Check nginx proxy configuration
sudo nginx -t
sudo systemctl reload nginx

# Verify backend is running on correct port
sudo netstat -tlnp | grep :5000
```

**Permission issues:**
```bash
# Fix web directory permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Fix application directory permissions
sudo chown -R aichat:aichat /opt/ai-chat-interface
```

**Nginx configuration issues:**
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx error logs
sudo tail -f /opt/ai-chat-interface/logs/nginx-error.log

# Restart nginx
sudo systemctl restart nginx

# Check if nginx is listening on port 80
sudo netstat -tlnp | grep :80
```

**API key issues:**
- Verify keys are correctly set in `/opt/ai-chat-interface/backend/.env`
- Check API key format and permissions
- Use the settings panel to test keys
- Restart backend after changing keys: `ai-chat-manager restart`

**Update/deployment issues:**
```bash
# Manual update process
cd /opt/ai-chat-interface
sudo systemctl stop ai-chat-backend
sudo -u aichat git pull
sudo -u aichat npm run install:all
sudo -u aichat npm run build

# Redeploy frontend
sudo rm -rf /var/www/html/*
sudo cp -r frontend/build/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html

# Restart services
sudo systemctl start ai-chat-backend
sudo systemctl restart nginx
```

**Linux deployment issues:**
See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive troubleshooting.

## 📈 Performance

### Optimization Tips
- Use appropriate model for task complexity
- Configure reasonable token limits
- Monitor usage via analytics dashboard
- Consider model switching based on requirements

### Production Scaling
- Nginx static file caching and compression
- Backend API load balancing for multiple instances
- Database optimization and backups
- Monitoring and alerting setup
- Resource management and limits

### Architecture Benefits
- **Faster Static Files**: Nginx serves React build files directly (no Node.js overhead)
- **Better Caching**: Nginx handles static asset caching efficiently
- **Reduced Memory**: Only backend Node.js process runs (frontend served statically)
- **Improved Security**: Security headers and CORS handling at nginx level

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenAI for GPT and DALL-E APIs
- Anthropic for Claude API
- React and Node.js communities
- Tailwind CSS for styling
- SQLite for reliable data storage

---

**Need help?** Check out [DEPLOYMENT.md](DEPLOYMENT.md) for detailed documentation or open an issue on GitHub. 