#!/bin/bash

# AI Chat Interface - Linux Installation Script
# This script installs and configures the AI Chat application on Linux

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="ai-chat-interface"
APP_DIR="/opt/${APP_NAME}"
SERVICE_USER="aichat"
FRONTEND_PORT=3000
BACKEND_PORT=5000
NODE_VERSION="20"
WEB_DIR="/var/www/html"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons."
        print_status "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if user has sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo privileges."
        print_status "Please ensure your user is in the sudo group."
        exit 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
    print_status "Detected: $PRETTY_NAME"
}

# Function to install Node.js
install_nodejs() {
    print_status "Installing Node.js ${NODE_VERSION}..."
    
    # Install NodeSource repository
    if command -v node >/dev/null 2>&1; then
        NODE_CURRENT=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $NODE_CURRENT -ge $NODE_VERSION ]]; then
            print_success "Node.js ${NODE_CURRENT} is already installed"
            return 0
        fi
    fi

    case $DISTRO in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
            sudo dnf install -y nodejs npm || sudo yum install -y nodejs npm
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            print_status "Please install Node.js ${NODE_VERSION} manually"
            exit 1
            ;;
    esac
    
    # Configure npm to avoid permission issues
    print_status "Configuring npm permissions..."
    sudo mkdir -p /usr/local/lib/node_modules
    sudo chown -R root:staff /usr/local/lib/node_modules
    sudo chmod -R 775 /usr/local/lib/node_modules
    
    # Set npm prefix to avoid permission conflicts
    sudo npm config set prefix /usr/local --global
    
    # Fix npm permissions for the service user
    sudo mkdir -p /home/${SERVICE_USER}/.npm
    sudo chown -R ${SERVICE_USER}:${SERVICE_USER} /home/${SERVICE_USER}/.npm
    
    print_success "Node.js installed: $(node --version)"
    print_success "npm installed: $(npm --version)"
}

# Function to install system dependencies
install_system_deps() {
    print_status "Installing system dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl wget git build-essential python3 sqlite3 nginx unzip
            ;;
        centos|rhel|fedora)
            sudo dnf update -y || sudo yum update -y
            sudo dnf install -y curl wget git gcc-c++ make python3 sqlite nginx unzip || \
            sudo yum install -y curl wget git gcc-c++ make python3 sqlite nginx unzip
            ;;
        *)
            print_warning "Unknown distribution, skipping system dependencies"
            ;;
    esac
}

# Function to create service user
create_service_user() {
    print_status "Creating service user: ${SERVICE_USER}"
    
    if id "$SERVICE_USER" &>/dev/null; then
        print_success "User ${SERVICE_USER} already exists"
    else
        sudo useradd --system --shell /bin/bash --home-dir /home/${SERVICE_USER} \
                    --create-home --comment "AI Chat Service User" ${SERVICE_USER}
        print_success "Created user: ${SERVICE_USER}"
    fi
}

# Function to setup application directory
setup_app_directory() {
    print_status "Setting up application directory: ${APP_DIR}"
    
    # Create directory structure
    sudo mkdir -p ${APP_DIR}
    sudo mkdir -p ${APP_DIR}/logs
    sudo mkdir -p ${APP_DIR}/data
    
    # Debug: Check what files exist in current directory
    print_status "Checking current directory contents..."
    if [[ -f "package.json" ]]; then
        print_status "Found package.json in current directory"
    else
        print_status "No package.json in current directory"
    fi
    
    if [[ -d "backend" ]]; then
        print_status "Found backend directory"
    else
        print_status "No backend directory found"
    fi
    
    if [[ -d "frontend" ]]; then
        print_status "Found frontend directory"
    else
        print_status "No frontend directory found"
    fi
    
    # Always clone the repository to ensure we have all files
    print_status "Cloning application from repository..."
    TEMP_DIR=$(mktemp -d)
    print_status "Using temporary directory: ${TEMP_DIR}"
    
    # Configure git to be more robust
    git config --global http.postBuffer 524288000
    git config --global http.maxRequestBuffer 100M
    git config --global core.compression 0
    
    # Clone the correct repository with progressive fallback methods
    REPO_URL="https://github.com/djkiraly/EmbeddedAIChatv2.git"
    CLONE_SUCCESS=false
    
    # Method 1: Try shallow clone first (faster, less prone to fetch-pack issues)
    print_status "Attempting shallow clone..."
    if cd ${TEMP_DIR} && git clone --depth 1 ${REPO_URL} repo 2>/dev/null; then
        print_status "Shallow clone successful"
        CLONE_SUCCESS=true
    else
        print_warning "Shallow clone failed, trying full clone..."
        
        # Method 2: Full clone without single-branch restriction
        print_status "Attempting full clone..."
        if cd ${TEMP_DIR} && git clone ${REPO_URL} repo 2>/dev/null; then
            print_status "Full clone successful"
            CLONE_SUCCESS=true
        else
            print_warning "Full clone failed, trying with verbose output..."
            
            # Method 3: Clone with verbose output for debugging
            print_status "Attempting clone with debugging..."
            if cd ${TEMP_DIR} && git clone --verbose --progress ${REPO_URL} repo; then
                print_status "Clone with debugging successful"
                CLONE_SUCCESS=true
            else
                print_warning "Git clone failed, trying ZIP download fallback..."
                
                # Method 4: Download ZIP file as fallback
                print_status "Downloading repository as ZIP file..."
                if command -v wget >/dev/null 2>&1; then
                    if wget -q https://github.com/djkiraly/EmbeddedAIChatv2/archive/refs/heads/main.zip -O repo.zip; then
                        print_status "ZIP download successful, extracting..."
                        if command -v unzip >/dev/null 2>&1; then
                            if unzip -q repo.zip && mv EmbeddedAIChatv2-main repo; then
                                print_status "ZIP extraction successful"
                                CLONE_SUCCESS=true
                                rm -f repo.zip
                            else
                                print_error "ZIP extraction failed"
                            fi
                        else
                            print_error "unzip command not available"
                        fi
                    else
                        print_error "ZIP download failed"
                    fi
                elif command -v curl >/dev/null 2>&1; then
                    if curl -sL https://github.com/djkiraly/EmbeddedAIChatv2/archive/refs/heads/main.zip -o repo.zip; then
                        print_status "ZIP download successful, extracting..."
                        if command -v unzip >/dev/null 2>&1; then
                            if unzip -q repo.zip && mv EmbeddedAIChatv2-main repo; then
                                print_status "ZIP extraction successful"
                                CLONE_SUCCESS=true
                                rm -f repo.zip
                            else
                                print_error "ZIP extraction failed"
                            fi
                        else
                            print_error "unzip command not available"
                        fi
                    else
                        print_error "ZIP download failed"
                    fi
                else
                    print_error "Neither wget nor curl available for ZIP download"
                fi
                
                if [[ "$CLONE_SUCCESS" != "true" ]]; then
                    print_error "All download methods failed. Check network connectivity and repository access."
                    print_status "Manual installation required:"
                    print_status "1. Download: https://github.com/djkiraly/EmbeddedAIChatv2/archive/refs/heads/main.zip"
                    print_status "2. Extract to ${APP_DIR}"
                    print_status "3. Re-run this script"
                    rm -rf ${TEMP_DIR}
                    return 1
                fi
            fi
        fi
    fi
    
    if [[ "$CLONE_SUCCESS" != "true" ]]; then
        print_error "Repository cloning failed"
        rm -rf ${TEMP_DIR}
        return 1
    fi
    
    # Reset git configuration to avoid affecting other operations
    git config --global --unset http.postBuffer 2>/dev/null || true
    git config --global --unset http.maxRequestBuffer 2>/dev/null || true
    git config --global --unset core.compression 2>/dev/null || true
    
    # Move into the cloned directory
    cd repo || {
        print_error "Failed to enter cloned repository directory"
        rm -rf ${TEMP_DIR}
        return 1
    }
    
    # Validate that we have the expected project structure
    print_status "Validating repository contents..."
    if [[ ! -f "package.json" ]]; then
        print_error "Repository validation failed: package.json not found"
        rm -rf ${TEMP_DIR}
        return 1
    fi
    
    if [[ ! -d "backend" ]] || [[ ! -d "frontend" ]]; then
        print_error "Repository validation failed: backend or frontend directory missing"
        rm -rf ${TEMP_DIR}
        return 1
    fi
    
    print_success "Repository contents validated successfully"
        
        # Check git status and branch (only if it's a git repository)
        if [[ -d ".git" ]]; then
            print_status "Git repository information:"
            git status 2>/dev/null || echo "Git status not available"
            git branch -a 2>/dev/null || echo "Git branch not available"
            git ls-files | head -10 2>/dev/null || echo "Git ls-files not available"
        else
            print_status "Downloaded from ZIP archive (not a git repository)"
        fi
        
        # List files in temp directory for debugging (including hidden)
        print_status "Files in temp directory:"
        ls -la || echo "Failed to list temp directory contents"
        
        # Check if files exist but are in a subdirectory
        print_status "Looking for application files:"
        find . -name "package.json" -type f 2>/dev/null || echo "No package.json found anywhere"
        find . -name "backend" -type d 2>/dev/null || echo "No backend directory found anywhere"
        find . -name "frontend" -type d 2>/dev/null || echo "No frontend directory found anywhere"
        
        print_status "Copying cloned files to ${APP_DIR}..."
        
        # Clear the destination directory first to avoid conflicts
        sudo rm -rf ${APP_DIR}/* 2>/dev/null || true
        
        # Copy all files including hidden ones
        print_status "Copying cloned files to ${APP_DIR}..."
        if sudo cp -rv . ${APP_DIR}/ 2>&1; then
            print_status "Files copied successfully"
            COPY_SUCCESS=true
        else
            # Fallback method using rsync if cp fails
            print_status "Attempting fallback copy method: rsync"
            if command -v rsync >/dev/null 2>&1; then
                if sudo rsync -av ./ ${APP_DIR}/ 2>&1; then
                    print_status "Rsync copy succeeded"
                    COPY_SUCCESS=true
                else
                    print_error "Rsync copy failed"
                    cd - > /dev/null
                    rm -rf ${TEMP_DIR}
                    return 1
                fi
            else
                print_error "Copy failed and rsync not available"
                cd - > /dev/null
                rm -rf ${TEMP_DIR}
                return 1
            fi
        fi
        
        # Return to original directory and cleanup
        cd - > /dev/null
        rm -rf ${TEMP_DIR}
        
        # Verify files were copied and show what's actually there
        print_status "Verifying copied files..."
        print_status "Contents of ${APP_DIR}:"
        sudo ls -la ${APP_DIR}/ || echo "Failed to list destination directory"
        
        # Check for critical files
        if [[ -f "${APP_DIR}/package.json" ]]; then
            print_status "✓ package.json found"
        else
            print_error "✗ package.json NOT found"
        fi
        
        if [[ -d "${APP_DIR}/backend" ]]; then
            print_status "✓ backend directory found"
        else
            print_error "✗ backend directory NOT found"
        fi
        
        if [[ -d "${APP_DIR}/frontend" ]]; then
            print_status "✓ frontend directory found"
        else
            print_error "✗ frontend directory NOT found"
        fi
        
        # Final check
        if [[ -f "${APP_DIR}/package.json" && -d "${APP_DIR}/backend" && -d "${APP_DIR}/frontend" ]]; then
            print_success "Repository cloned and files copied successfully"
        else
            print_error "Critical files/directories missing - copy failed"
            return 1
        fi
        
    # Set ownership
    sudo chown -R ${SERVICE_USER}:${SERVICE_USER} ${APP_DIR}
    
    print_success "Application directory setup complete"
}

# Function to install application dependencies
install_app_deps() {
    print_status "Installing application dependencies..."
    
    # Ensure service user has proper npm configuration
    print_status "Setting up npm for service user..."
    sudo -u ${SERVICE_USER} bash << 'EOF'
        # Set up npm configuration for user
        npm config set prefix ~/.npm-global
        echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
        echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.profile
        source ~/.bashrc 2>/dev/null || true
EOF
    
    # Switch to service user and install dependencies
    sudo -u ${SERVICE_USER} bash << EOF
        cd ${APP_DIR}
        
        # Set up PATH for this session
        export PATH=~/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:\$PATH
        export NODE_PATH=\$NODE_PATH:~/.npm-global/lib/node_modules
        
        # Install all dependencies using the project's convenience script
        echo "Installing dependencies..."
        if ! npm run install:all; then
            echo "npm run install:all failed, trying individual installs..."
            npm install || exit 1
            cd frontend && npm install && cd ..
            cd backend && npm install && cd ..
        fi
        
        # Ensure node_modules/.bin has proper permissions
        if [ -d "${APP_DIR}/frontend/node_modules/.bin" ]; then
            chmod +x ${APP_DIR}/frontend/node_modules/.bin/*
        fi
        if [ -d "${APP_DIR}/backend/node_modules/.bin" ]; then
            chmod +x ${APP_DIR}/backend/node_modules/.bin/*
        fi
        if [ -d "${APP_DIR}/node_modules/.bin" ]; then
            chmod +x ${APP_DIR}/node_modules/.bin/*
        fi
        
        # Build frontend for production
        echo "Building frontend..."
        if ! npm run build; then
            echo "npm run build failed, trying direct build..."
            cd frontend
            if ! npm run build; then
                echo "Direct npm run build failed, trying npx..."
                npx react-scripts build || exit 1
            fi
            cd ..
        fi
EOF
    
    # Copy built frontend to nginx web directory
    print_status "Deploying frontend to nginx web directory..."
    
    # Create web directory if it doesn't exist
    sudo mkdir -p ${WEB_DIR}
    
    # Remove any existing content
    sudo rm -rf ${WEB_DIR}/*
    
    # Copy built frontend files
    if [[ -d "${APP_DIR}/frontend/build" ]]; then
        sudo cp -r ${APP_DIR}/frontend/build/* ${WEB_DIR}/
        print_success "Frontend deployed to ${WEB_DIR}"
    else
        print_error "Frontend build directory not found at ${APP_DIR}/frontend/build"
        return 1
    fi
    
    # Set proper ownership and permissions
    sudo chown -R www-data:www-data ${WEB_DIR}
    sudo chmod -R 755 ${WEB_DIR}
    sudo find ${WEB_DIR} -type f -exec chmod 644 {} \;
    
    print_success "Application dependencies installed and frontend deployed"
}

# Function to create environment configuration
create_env_config() {
    print_status "Creating environment configuration..."
    
    # Create backend .env file
    sudo -u ${SERVICE_USER} tee ${APP_DIR}/backend/.env > /dev/null << EOF
# Environment
NODE_ENV=production

# Server Configuration
PORT=${BACKEND_PORT}
HOST=0.0.0.0

# Database
DATABASE_PATH=${APP_DIR}/data/database.sqlite

# CORS Origins
FRONTEND_URL=http://localhost:${FRONTEND_PORT}
CORS_ORIGIN=http://localhost:${FRONTEND_PORT}

# API Keys (Configure these after installation)
# OPENAI_API_KEY=your_openai_api_key_here
# ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Logging
LOG_LEVEL=info
LOG_FILE=${APP_DIR}/logs/backend.log
EOF

    # Create frontend .env file
    sudo -u ${SERVICE_USER} tee ${APP_DIR}/frontend/.env.production > /dev/null << EOF
# API Configuration
REACT_APP_API_URL=http://localhost/api

# Build Configuration
GENERATE_SOURCEMAP=false
EOF

    # Also create .env.local for development compatibility
    sudo -u ${SERVICE_USER} tee ${APP_DIR}/frontend/.env.local > /dev/null << EOF
# API Configuration
REACT_APP_API_URL=http://localhost/api
EOF
    
    print_success "Environment configuration created"
    print_warning "Remember to configure your API keys in ${APP_DIR}/backend/.env"
}

# Function to create systemd services
create_systemd_services() {
    print_status "Creating systemd services..."
    
    # Backend service
    sudo tee /etc/systemd/system/ai-chat-backend.service > /dev/null << EOF
[Unit]
Description=AI Chat Interface Backend
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${APP_DIR}/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
StandardOutput=append:${APP_DIR}/logs/backend.log
StandardError=append:${APP_DIR}/logs/backend-error.log

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${APP_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable services
    sudo systemctl enable ai-chat-backend.service
    
    print_success "Systemd service created and enabled"
    print_status "Frontend is served directly by nginx from ${WEB_DIR}"
}

# Function to setup nginx reverse proxy
setup_nginx() {
    print_status "Setting up Nginx reverse proxy..."
    
    # Create nginx configuration
    sudo tee /etc/nginx/sites-available/ai-chat-interface > /dev/null << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost _;
    
    # Document root for static files
    root ${WEB_DIR};
    index index.html index.htm;
    
    # Frontend - serve static files directly
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    }
    
    # Backend API - proxy to Node.js server
    location /api/ {
        proxy_pass http://localhost:${BACKEND_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin "http://localhost" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
        add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin "http://localhost";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # Logs
    access_log ${APP_DIR}/logs/nginx-access.log;
    error_log ${APP_DIR}/logs/nginx-error.log;
}
EOF
    
    # Enable site
    if [[ -d /etc/nginx/sites-enabled ]]; then
        sudo ln -sf /etc/nginx/sites-available/ai-chat-interface /etc/nginx/sites-enabled/
        # Remove default site
        sudo rm -f /etc/nginx/sites-enabled/default
    else
        # For CentOS/RHEL/Fedora
        sudo ln -sf /etc/nginx/sites-available/ai-chat-interface /etc/nginx/conf.d/ai-chat-interface.conf
    fi
    
    # Test nginx configuration
    if sudo nginx -t; then
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        print_success "Nginx configured and started"
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
}

# Function to setup log rotation
setup_logrotate() {
    print_status "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/ai-chat-interface > /dev/null << EOF
${APP_DIR}/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ${SERVICE_USER} ${SERVICE_USER}
    postrotate
        systemctl reload ai-chat-backend || true
        systemctl reload ai-chat-frontend || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Function to create management script
create_management_script() {
    print_status "Creating management script..."
    
    sudo tee /usr/local/bin/ai-chat-manager > /dev/null << 'EOF'
#!/bin/bash

# AI Chat Interface Management Script

SERVICE_USER="aichat"
APP_DIR="/opt/ai-chat-interface"

case "$1" in
    start)
        echo "Starting AI Chat Interface..."
        sudo systemctl start ai-chat-backend
        sudo systemctl start nginx
        echo "Services started"
        ;;
    stop)
        echo "Stopping AI Chat Interface..."
        sudo systemctl stop ai-chat-backend
        echo "Services stopped (nginx continues to serve static files)"
        ;;
    restart)
        echo "Restarting AI Chat Interface..."
        sudo systemctl restart ai-chat-backend
        sudo systemctl restart nginx
        echo "Services restarted"
        ;;
    status)
        echo "AI Chat Interface Status:"
        echo "========================"
        echo -n "Backend: "
        sudo systemctl is-active ai-chat-backend
        echo -n "Nginx: "
        sudo systemctl is-active nginx
        echo "Frontend: served directly by nginx from /var/www/html"
        ;;
    logs)
        case "$2" in
            backend)
                sudo journalctl -u ai-chat-backend -f
                ;;
            nginx)
                sudo tail -f ${APP_DIR}/logs/nginx-*.log
                ;;
            *)
                echo "Usage: $0 logs {backend|nginx}"
                echo "Note: Frontend is served statically by nginx (no separate logs)"
                ;;
        esac
        ;;
    update)
        echo "Updating application..."
        cd ${APP_DIR}
        sudo systemctl stop ai-chat-backend
        sudo -u ${SERVICE_USER} git pull
        
        # Update with proper environment setup
        sudo -u ${SERVICE_USER} bash << 'UPDATE_EOF'
            export PATH=~/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH
            export NODE_PATH=$NODE_PATH:~/.npm-global/lib/node_modules
            
            if ! npm run install:all; then
                echo "npm run install:all failed, trying individual installs..."
                npm install || exit 1
                cd frontend && npm install && cd ..
                cd backend && npm install && cd ..
            fi
            
            # Fix permissions
            find . -name "node_modules" -type d -exec chmod -R +x {}/\.bin \; 2>/dev/null || true
            
            if ! npm run build; then
                echo "npm run build failed, trying direct build..."
                cd frontend
                if ! npm run build; then
                    echo "Direct npm run build failed, trying npx..."
                    npx react-scripts build || exit 1
                fi
                cd ..
            fi
UPDATE_EOF
        
        # Redeploy frontend to nginx web directory
        echo "Redeploying frontend..."
        sudo rm -rf /var/www/html/*
        sudo cp -r ${APP_DIR}/frontend/build/* /var/www/html/
        sudo chown -R www-data:www-data /var/www/html
        sudo chmod -R 755 /var/www/html
        sudo find /var/www/html -type f -exec chmod 644 {} \;
        
        sudo systemctl restart ai-chat-backend
        sudo systemctl restart nginx
        echo "Application updated and redeployed"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        echo ""
        echo "Commands:"
        echo "  start    - Start backend and nginx services"
        echo "  stop     - Stop backend service (nginx continues serving static files)"
        echo "  restart  - Restart backend and nginx services"
        echo "  status   - Show service status"
        echo "  logs     - View logs (backend|nginx)"
        echo "  update   - Update application from git and redeploy"
        echo ""
        echo "Note: Frontend is served directly by nginx from /var/www/html"
        exit 1
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/ai-chat-manager
    print_success "Management script created: /usr/local/bin/ai-chat-manager"
}

# Function to setup firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 22/tcp    # SSH
        sudo ufw allow 80/tcp    # HTTP
        sudo ufw allow 443/tcp   # HTTPS
        print_success "UFW firewall configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        print_success "Firewalld configured"
    else
        print_warning "No firewall detected. Consider configuring iptables manually."
    fi
}

# Function to start services
start_services() {
    print_status "Starting services..."
    
    # Initialize database
    sudo -u ${SERVICE_USER} bash << EOF
        cd ${APP_DIR}/backend
        npm run init-db
EOF
    
    # Start services
    sudo systemctl start ai-chat-backend
    sleep 5
    
    # Check if services started successfully
    if sudo systemctl is-active --quiet ai-chat-backend; then
        print_success "Backend service started successfully"
        print_status "Frontend is served directly by nginx"
    else
        print_error "Backend service failed to start"
        print_status "Check logs with: ai-chat-manager logs backend"
        return 1
    fi
}

# Function to print installation summary
print_summary() {
    print_success "==================================="
    print_success "AI Chat Interface Installation Complete!"
    print_success "==================================="
    echo ""
    print_status "Application URL: http://localhost (or your server IP)"
    print_status "Backend API: http://localhost/api"
    print_status "Application Directory: ${APP_DIR}"
    print_status "Web Directory: ${WEB_DIR}"
    print_status "Service User: ${SERVICE_USER}"
    echo ""
    print_status "Architecture:"
    echo "  Frontend: Static files served by nginx from ${WEB_DIR}"
    echo "  Backend: Node.js API server proxied through nginx"
    echo ""
    print_status "Management Commands:"
    echo "  ai-chat-manager start     - Start backend and nginx"
    echo "  ai-chat-manager stop      - Stop backend (nginx continues)"
    echo "  ai-chat-manager restart   - Restart backend and nginx"
    echo "  ai-chat-manager status    - Check status"
    echo "  ai-chat-manager logs      - View logs (backend|nginx)"
    echo "  ai-chat-manager update    - Update and redeploy application"
    echo ""
    print_warning "IMPORTANT: Configure your API keys in ${APP_DIR}/backend/.env"
    echo ""
    print_status "To configure API keys:"
    echo "  sudo -u ${SERVICE_USER} nano ${APP_DIR}/backend/.env"
    echo "  ai-chat-manager restart"
    echo ""
    print_success "Installation completed successfully!"
}

# Main installation function
main() {
    print_status "Starting AI Chat Interface installation..."
    
    check_root
    check_sudo
    detect_distro
    
    install_system_deps
    install_nodejs
    create_service_user
    setup_app_directory
    install_app_deps
    create_env_config
    create_systemd_services
    setup_nginx
    setup_logrotate
    create_management_script
    setup_firewall
    start_services
    
    print_summary
}

# Run installation
main "$@" 