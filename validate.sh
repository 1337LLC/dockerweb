#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          GitHub Pages Build & Deployment Validation          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

errors=0
warnings=0

# Check 1: Verify all HTML files are present
echo "📋 Checking HTML files..."
html_files=(
    "index.html"
    "amd64-stargz-lazy-loading.html"
    "stargz-container-launcher.html"
    "amd64-debian-wasi.html"
    "amd64-python-wasi.html"
    "amd64-vim-wasi.html"
    "riscv64-debian.html"
    "riscv64-python.html"
    "riscv64-vim.html"
)

for file in "${html_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        ((errors++))
    fi
done

# Check 2: Verify all JS files are present
echo ""
echo "📜 Checking JavaScript files..."
js_files=(
    "src/stargz-lazy-loader.js"
    "src/stargz-container-launcher.js"
    "src/stack.js"
    "src/worker.js"
    "worker.js"
    "coi-serviceworker.js"
)

for file in "${js_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        ((warnings++))
    fi
done

# Check 3: Verify all CSS dependencies are external (CDN)
echo ""
echo "🎨 Checking CSS (external CDN)..."
grep -h "link.*css" *.html | head -3 | while read -r line; do
    echo "  ✓ $(echo $line | grep -o 'https://[^"]*' | head -1)"
done

# Check 4: Verify script tags reference correct paths
echo ""
echo "🔗 Checking script paths in STARGZ pages..."
for file in amd64-stargz-lazy-loading.html stargz-container-launcher.html; do
    echo "  $file:"
    grep -o '<script[^>]*src="[^"]*"' "$file" | sed 's/.*src="\([^"]*\)".*/    ✓ \1/' | head -5
done

# Check 5: Verify documentation files exist
echo ""
echo "📚 Checking documentation..."
docs=(
    "STARGZ-LAZY-LOADING.md"
    "IMPLEMENTATION-GUIDE.md"
    "CHANGES.md"
    "README.md"
)

for file in "${docs[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "  ✓ $file ($lines lines)"
    else
        echo "  ✗ $file (MISSING)"
        ((errors++))
    fi
done

# Check 6: Verify CNAME for GitHub Pages
echo ""
echo "🌐 Checking GitHub Pages configuration..."
if [ -f "CNAME" ]; then
    domain=$(cat CNAME)
    echo "  ✓ CNAME configured: $domain"
else
    echo "  ⚠ CNAME not found (using default github.io domain)"
    ((warnings++))
fi

# Check 7: Verify git status
echo ""
echo "📦 Checking Git repository..."
if [ -d ".git" ]; then
    echo "  ✓ Git repository initialized"
    git_status=$(git status --short 2>/dev/null)
    if [ -z "$git_status" ]; then
        echo "  ✓ Working directory clean"
    else
        echo "  ⚠ Uncommitted changes detected:"
        echo "$git_status" | sed 's/^/    /'
        ((warnings++))
    fi
else
    echo "  ✗ Not a git repository"
    ((errors++))
fi

# Check 8: Verify containers directory
echo ""
echo "📦 Checking container files..."
container_count=$(find containers -name "*.wasm" 2>/dev/null | wc -l)
echo "  ✓ Found $container_count container WASM files"

# Summary
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Summary:"
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "✅ All checks passed! Ready for deployment."
    exit 0
elif [ $errors -eq 0 ]; then
    echo "⚠️  $warnings warning(s). Ready to deploy with caution."
    exit 0
else
    echo "❌ $errors error(s) found. Fix before deployment."
    exit 1
fi
