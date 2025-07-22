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
git clone https://github.com/djkiraly/embeddedAiAgent.git
cd embeddedAiAgent

# Install all dependencies
npm run install:all

# Configure API keys
cp backend/.env.example backend/.env
# Edit backend/.env and add your API keys

# Start development servers
npm start
```

Visit `http://localhost:3000` to access the application.

### 🐧 Linux Production Deployment

For production deployment on Linux servers, use our automated installation scripts:

#### One-Line Installation
```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/djkiraly/embeddedAiAgent/main/install.sh | bash
```

#### Manual Installation
```bash
# Clone the repository
git clone https://github.com/djkiraly/embeddedAiAgent.git
cd embeddedAiAgent

# Make scripts executable
chmod +x install.sh uninstall.sh update.sh

# Run installation
./install.sh
```

**What gets installed:**
- ✅ Node.js 18+ and all system dependencies
- ✅ Complete application with production build
- ✅ Systemd services for auto-start and management
- ✅ Nginx reverse proxy configuration
- ✅ SQLite database with proper schema
- ✅ Security hardening and firewall setup
- ✅ Log rotation and monitoring
- ✅ Management tools and scripts

**Post-installation:**
```bash
# Configure API keys
sudo -u aichat nano /opt/ai-chat-interface/backend/.env

# Restart services
ai-chat-manager restart

# Check status
ai-chat-manager status
```

**Management commands:**
- `ai-chat-manager start/stop/restart` - Service control
- `ai-chat-manager status` - Check service status
- `ai-chat-manager logs backend/frontend/nginx` - View logs
- `ai-chat-manager update` - Update application

**Complete deployment documentation:** See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed Linux deployment guide, troubleshooting, and advanced configuration.

## 📋 Requirements

### Development
- Node.js 18+ and npm
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
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    Frontend     │    │    Backend      │
│   (Port 80)     │───▶│   (Port 3000)   │───▶│   (Port 5000)   │
│  Reverse Proxy  │    │   React App     │    │   Express API   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
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
ai-chat-manager start/stop/restart  # Service control
ai-chat-manager status              # Service status
ai-chat-manager logs [service]      # View logs
ai-chat-manager update              # Update application
```

### Environment Configuration

**Backend** (`.env`):
```env
NODE_ENV=development
PORT=5000
DATABASE_PATH=./database.sqlite

# API Keys
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here

# Optional
FRONTEND_URL=http://localhost:3000
LOG_LEVEL=info
```

**Frontend** (`.env`):
```env
REACT_APP_API_URL=http://localhost:5000/api
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
- Nginx reverse proxy with security headers
- Firewall configuration
- Log rotation and monitoring
- Automatic security updates

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
# Reset database
rm backend/database.sqlite
npm run backend:dev  # Recreates database
```

**API key issues:**
- Verify keys are correctly set in `.env`
- Check API key format and permissions
- Use the settings panel to test keys

**Linux deployment issues:**
See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive troubleshooting.

## 📈 Performance

### Optimization Tips
- Use appropriate model for task complexity
- Configure reasonable token limits
- Monitor usage via analytics dashboard
- Consider model switching based on requirements

### Production Scaling
- Nginx load balancing for multiple instances
- Database optimization and backups
- Monitoring and alerting setup
- Resource management and limits

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