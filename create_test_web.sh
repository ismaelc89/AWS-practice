#!/bin/bash
set -e

# Define directory and application file
APP_DIR="$HOME/app"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "==> Creating test HTML file..."
cat << 'EOF' > index.html
Private App Server
Hello from the Private Subnet App Server on AWS!
EOF

echo "==> Starting Python HTTP server on port 8080 in the background..."

#Kill any existing server on port 8080 if running
pkill -f "python3 -m http.server 8080" || true

#Run Python server in background using nohup
nohup python3 -m http.server 8080 > app.log 2>&1 &

echo "> Success! Web server is running on port 8080."
echo "> Serving files from: $APP_DIR"