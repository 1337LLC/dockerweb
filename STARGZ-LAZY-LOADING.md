# STARGZ Lazy Loading Guide

## Overview

This guide explains how to implement high-performance lazy loading of Docker containers in the browser using STARGZ format and WebAssembly. Lazy loading allows users to run arbitrary Docker images without modifying them, streaming only the necessary layers on-demand.

## What is STARGZ?

**STARGZ** (Seekable TAR GZ) is a container image format that enables lazy loading - only downloading the necessary layers and files when they're needed. Key features:

- **HTTP Range Requests**: Built on standard HTTP range requests supported by all modern browsers
- **No Special Infrastructure**: Works with standard web servers; no custom protocols needed
- **Format Preservation**: Images maintain compatibility with container standards
- **Transparent Streaming**: Additional layers download automatically as needed

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Browser                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │           Terminal (xterm.js)                    │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │  WASI Container Runtime (container2wasm)         │   │
│  │  ┌───────────────────────────────────────────┐   │   │
│  │  │  Lazy Loader (stargz-lazy-loader.js)      │   │   │
│  │  │  - Tracks chunk progress                  │   │   │
│  │  │  - Manages HTTP range requests            │   │   │
│  │  │  - Buffers and caches layers              │   │   │
│  │  └───────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
           ↓ (HTTP Range Requests)
┌─────────────────────────────────────────────────────────┐
│              Web Server (static or CDN)                 │
│  - amd64-debian-wasi-container00.wasm                   │
│  - amd64-debian-wasi-container01.wasm                   │
│  - amd64-debian-wasi-container02.wasm                   │
│  - ...                                                  │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Use Pre-built STARGZ Images

Pre-built STARGZ images are available from [stargz-containers](https://github.com/stargz-containers):

```bash
# List available images
curl https://api.github.com/repos/stargz-containers/alpine/releases/latest

# Available images include:
# - ghcr.io/stargz-containers/alpine:latest
# - ghcr.io/stargz-containers/ubuntu:latest
# - ghcr.io/stargz-containers/debian:latest
# - And many others optimized for lazy loading
```

### 2. Convert to WASM

```bash
# Install container2wasm
# See: https://github.com/ktock/container2wasm

# Convert STARGZ image to WASM
container2wasm ghcr.io/stargz-containers/alpine:latest alpine-wasi.wasm

# Or with custom optimization
container2wasm --stargz ghcr.io/stargz-containers/alpine:latest alpine-wasi.wasm
```

### 3. Split into Chunks

```bash
# Split the WASM file into manageable chunks (e.g., 100MB each)
split -b 100M alpine-wasi.wasm alpine-wasi-container

# This creates:
# - alpine-wasi-container00
# - alpine-wasi-container01
# - alpine-wasi-container02
# - etc.

# Rename with .wasm extension
for f in alpine-wasi-container??; do mv "$f" "$f.wasm"; done

# Place in your containers/ directory
```

### 4. Create an HTML Page

Create a new HTML file similar to `amd64-stargz-lazy-loading.html`:

```html
<!doctype html>
<html>
<head>
    <title>My Custom Container</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.1.0/css/xterm.css">
</head>
<body>
<main class="container">
    <h1>My Custom Lazy-Loaded Container</h1>
    <div id="terminal"></div>
    <p><a href="?args=sh" class="btn btn-primary">Launch Shell</a></p>
</main>

<script src="./coi-serviceworker.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xterm@5.1.0/lib/xterm.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xterm-pty@0.9.4/index.js"></script>
<script src="./src/stack.js"></script>
<script src="./src/stargz-lazy-loader.js"></script>
<script src="./worker.js"></script>
<script>
startLazyWasi(
    "terminal",                    // Element ID
    "./src/worker.js"+location.search,
    "/containers/my-image-container",  // Base path for chunks
    5,                             // Number of chunks
    {
        onChunkLoad: function(idx, total, loaded, totalSize) {
            console.log(`Loading: ${idx}/${total} (${(loaded/1024/1024).toFixed(1)}MB)`);
        },
        onReady: function() {
            console.log("Container ready!");
        }
    }
);
</script>
</body>
</html>
```

### 5. Update index.html

Add your demo to the table in `index.html`:

```html
<tr>
<td><a href="https://github.com/yourusername/dockerweb">Your Image</a></td>
<td><pre><code>Your image description</code></pre></td>
<td><a href="./your-image-demo.html">start</a>(on-demand)</td>
</tr>
```

## Advanced Usage

### Custom Fetch Options

```javascript
startLazyWasi(
    "terminal",
    "./src/worker.js"+location.search,
    "/containers/my-image-container",
    5,
    {
        fetchOptions: {
            headers: {
                'Authorization': 'Bearer token'
            },
            credentials: 'include'
        }
    }
);
```

### Performance Monitoring

```javascript
// Get metrics after loading
const metrics = getLazyLoadMetrics();
console.log(`Total: ${metrics.totalSize / 1024 / 1024}MB`);
console.log(`Loaded: ${metrics.loadedSize / 1024 / 1024}MB`);
console.log(`Time: ${metrics.elapsedTime}ms`);

// Log detailed breakdown
logLazyLoadMetrics();
```

### Custom Chunk Loading

Implement your own chunk loader for advanced scenarios:

```javascript
function startLazyWasi(elemId, workerFileName, imageNamePrefix, numChunks, options) {
    // ... initialization code ...
    
    loadChunksLazy(imageNamePrefix, numChunks, options, function(chunks) {
        // Process loaded chunks
        lazyWorker.postMessage({
            type: "init",
            imagename: imageNamePrefix,
            chunks: chunks
        });
    });
}
```

## Building Your Own STARGZ Images

### Method 1: Using containerd tools

```bash
# 1. Install containerd and stargz-snapshotter
# See: https://github.com/containerd/stargz-snapshotter/blob/main/docs/quickstart.md

# 2. Convert image to eStargz format
ctr-remote images convert \
  your-image:tag \
  your-image:stargz

# 3. Verify the conversion
ctr-remote images info your-image:stargz
```

### Method 2: Using BuildKit

```dockerfile
# Dockerfile (with --cache-from flag for efficiency)
FROM alpine:latest
RUN apk add --no-cache curl wget
COPY app /app
WORKDIR /app
ENTRYPOINT ["./app"]
```

```bash
# Build with eStargz format support
docker buildx build \
  --output type=oci,format=stargz \
  -t ghcr.io/yourorg/your-image:stargz .

# Push to registry
docker push ghcr.io/yourorg/your-image:stargz
```

### Method 3: Using nerdctl

```bash
# Pull and convert
nerdctl pull ghcr.io/library/alpine:latest
nerdctl images convert alpine:latest ghcr.io/yourorg/alpine:stargz

# Push
nerdctl push ghcr.io/yourorg/alpine:stargz
```

## Performance Optimization

### 1. Chunk Size Selection

```bash
# Small chunks (10-50MB): Faster initial response, more HTTP requests
split -b 25M image.wasm image-chunk-

# Medium chunks (50-150MB): Good balance
split -b 100M image.wasm image-chunk-

# Large chunks (150MB+): Fewer requests, slower initial response
split -b 200M image.wasm image-chunk-
```

### 2. CDN Integration

Host chunks on a CDN for optimal performance:

```javascript
// Use CDN URL instead of local path
startLazyWasi(
    "terminal",
    "./src/worker.js"+location.search,
    "https://cdn.example.com/containers/my-image-container",
    5
);
```

### 3. Prefetching Strategy

```javascript
// Prefetch likely-needed chunks
function prefetchChunks(baseUrl, indices) {
    indices.forEach(i => {
        const link = document.createElement('link');
        link.rel = 'prefetch';
        link.href = `${baseUrl}${String(i).padStart(2, '0')}.wasm`;
        document.head.appendChild(link);
    });
}

// Prefetch chunks 1-3 (app dependencies)
prefetchChunks("/containers/my-image-container", [1, 2, 3]);
```

## Troubleshooting

### "Failed to fetch chunk" errors

1. Verify chunks are hosted at correct URLs
2. Check browser console for network errors
3. Ensure CORS headers are set if cross-origin
4. Verify Content-Length header is present

### Slow initial load

1. Check network bandwidth with DevTools
2. Reduce chunk size for faster initial response
3. Use CDN for better geographic distribution
4. Implement HTTP/2 Server Push for common chunks

### Container startup delays

1. Monitor which chunks are requested first
2. Ensure metadata chunks load early
3. Profile with `logLazyLoadMetrics()`
4. Adjust container format if possible

## Example Use Cases

### 1. Arbitrary Image Launcher

Users can paste an image URL, which is lazily loaded and run:

```javascript
function launchCustomImage(imageUrl, numChunks) {
    startLazyWasi(
        "terminal",
        "./src/worker.js"+location.search,
        imageUrl,
        numChunks || 5,
        {
            onError: err => alert("Failed to load: " + err),
            onReady: () => console.log("Ready to use!")
        }
    );
}
```

### 2. Interactive Image Gallery

Display available STARGZ images with one-click launch:

```html
<div id="image-gallery">
    <!-- Images dynamically loaded -->
</div>

<script>
const images = [
    { name: 'Alpine', chunks: 3, url: '/containers/alpine' },
    { name: 'Ubuntu', chunks: 8, url: '/containers/ubuntu' },
    { name: 'Python', chunks: 5, url: '/containers/python' }
];

images.forEach(img => {
    const btn = document.createElement('button');
    btn.textContent = img.name;
    btn.onclick = () => startLazyWasi('terminal', './src/worker.js', img.url, img.chunks);
    document.getElementById('image-gallery').appendChild(btn);
});
</script>
```

### 3. Performance Comparison Dashboard

```javascript
// Compare performance metrics
function compareChunkStrategies() {
    const metrics = getLazyLoadMetrics();
    return {
        dataPerChunk: metrics.totalSize / metrics.chunks.length,
        timePerChunk: metrics.elapsedTime / metrics.chunks.length,
        efficiency: (metrics.loadedSize / metrics.totalSize) * 100
    };
}
```

## Resources

- **container2wasm**: https://github.com/ktock/container2wasm
- **STARGZ Snapshotter**: https://github.com/containerd/stargz-snapshotter
- **stargz-containers**: https://github.com/stargz-containers
- **eStargz Spec**: https://github.com/containerd/stargz-snapshotter/blob/main/docs/estargz.md
- **HTTP Range Requests**: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range

## Contributing

To add more examples or improve lazy loading:

1. Create new container images
2. Add HTML demo pages
3. Update this guide with your findings
4. Submit pull requests with improvements

## License

This implementation follows the same license as the [dockerweb](https://github.com/ktock/dockerweb) project.
