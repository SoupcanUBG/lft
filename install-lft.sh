#!/bin/bash

set -e

echo "📥 Downloading lft.sh..."
curl -sSL https://raw.githubusercontent.com/yourusername/lft/main/lft.sh -o /tmp/lft.sh

echo "🔐 Setting permissions..."
chmod +x /tmp/lft.sh

echo "🛠️ Installing to /usr/bin/lft (requires sudo)..."
sudo mv /tmp/lft.sh /usr/bin/lft

echo "✅ Installed as 'lft'. You can now run:"
echo "   lft signup"
