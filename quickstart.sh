#!/bin/bash
# Quick Start - STARGZ Lazy Loading Setup

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      STARGZ Lazy Loading - Quick Start Setup                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if we have the required files
echo "✓ Checking files..."

required_files=(
    "amd64-stargz-lazy-loading.html"
    "stargz-container-launcher.html"
    "src/stargz-lazy-loader.js"
    "src/stargz-container-launcher.js"
    "STARGZ-LAZY-LOADING.md"
    "IMPLEMENTATION-GUIDE.md"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Missing required files. Please ensure all files are present."
    exit 1
fi

echo ""
echo "✓ All required files present!"
echo ""

# Print quick start options
echo "════════════════════════════════════════════════════════════════"
echo "QUICK START OPTIONS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Option 1: USE DEFAULT WEB SERVER"
echo "  If you have Python 3 installed:"
echo "    python3 -m http.server 8000"
echo ""
echo "  If you have Node.js installed:"
echo "    npx http-server ."
echo ""
echo "  Then visit: http://localhost:8000"
echo ""

echo "Option 2: USE DOCKER"
echo "  docker run -p 8000:80 -v \$(pwd):/usr/share/nginx/html nginx:alpine"
echo "  Then visit: http://localhost:8000"
echo ""

echo "Option 3: DEPLOY TO GITHUB PAGES"
echo "  Push to main branch: git push origin main"
echo "  Then visit: https://<username>.github.io/dockerweb"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "NEXT STEPS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. START THE WEB SERVER (see options above)"
echo ""
echo "2. VISIT THE LAUNCHER"
echo "   Main demo:"
echo "     http://localhost:8000/amd64-stargz-lazy-loading.html"
echo "   Interactive launcher (recommended):"
echo "     http://localhost:8000/stargz-container-launcher.html"
echo ""
echo "3. SELECT AN IMAGE"
echo "   - Browse gallery of pre-built STARGZ containers"
echo "   - Or search for a specific image"
echo "   - Or enter a custom image URL"
echo ""
echo "4. LAUNCH AND INTERACT"
echo "   - Click 'Launch' button"
echo "   - Watch real-time download progress in metrics"
echo "   - Interact with container terminal"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "DOCUMENTATION"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "For more information:"
echo ""
echo "  Technical Deep Dive:"
echo "    Read: STARGZ-LAZY-LOADING.md"
echo ""
echo "  Developer Integration:"
echo "    Read: IMPLEMENTATION-GUIDE.md"
echo ""
echo "  Live Examples:"
echo "    Open: amd64-stargz-lazy-loading.html"
echo "    Open: stargz-container-launcher.html"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "AVAILABLE IMAGES"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Pre-built STARGZ container images from stargz-containers:"
echo ""
echo "  • ghcr.io/stargz-containers/alpine:latest"
echo "  • ghcr.io/stargz-containers/ubuntu:latest"
echo "  • ghcr.io/stargz-containers/debian:latest"
echo "  • ghcr.io/stargz-containers/python:3.11"
echo "  • ghcr.io/stargz-containers/node:18"
echo ""
echo "More at: https://github.com/stargz-containers"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo ""
echo "✨ Ready to get started? Fire up your web server and visit the"
echo "   STARGZ Container Launcher at /stargz-container-launcher.html"
echo ""
echo "Happy containerizing! 🐳"
echo ""
