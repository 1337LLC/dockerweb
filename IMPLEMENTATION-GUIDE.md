# STARGZ Container Lazy Loading Implementation Guide

## Quick Reference

This repository now includes a complete implementation for running arbitrary Docker images in the browser with lazy loading. Here's what's included:

### Files and Components

| File | Purpose |
|------|---------|
| `amd64-stargz-lazy-loading.html` | Basic STARGZ lazy loading demo with metrics |
| `stargz-container-launcher.html` | Full-featured launcher for discovering and running images |
| `src/stargz-lazy-loader.js` | Core lazy loading functionality with progress tracking |
| `src/stargz-container-launcher.js` | High-level API for image discovery and launching |
| `STARGZ-LAZY-LOADING.md` | Comprehensive technical guide |

## Overview

The implementation enables high-performance, lazy-loaded container execution in the browser by:

1. **Progressive Chunking**: Container images are split into chunks that are downloaded on-demand
2. **HTTP Range Requests**: Uses standard browser HTTP range requests for efficient streaming
3. **Metrics Tracking**: Real-time progress monitoring of chunk downloads
4. **Image Discovery**: Integration with stargz-containers registry
5. **Retry Logic**: Automatic retry on failed chunk downloads
6. **Caching**: In-memory caching of downloaded chunks

## Getting Started

### For End Users

1. Navigate to [stargz-container-launcher.html](./stargz-container-launcher.html)
2. Browse available images or search for specific ones
3. Click "Launch" to run the container
4. Interact with the container terminal

### For Developers

#### Using the High-Level API

```javascript
// Create a launcher instance
const launcher = new STARGZLauncher({
    containerElement: 'terminal',
    workerScript: './src/worker.js',
    enableNetworking: true,
    metricsCallback: function(metrics) {
        console.log(`Progress: ${metrics.progress.toFixed(1)}%`);
    }
});

// Launch an image
await launcher.loadImage('ghcr.io/stargz-containers/alpine:latest');

// Get metrics
const metrics = launcher.getMetrics();
console.log(`Downloaded: ${metrics.loadedSize / 1024 / 1024}MB`);
```

#### Using the Image Registry Browser

```javascript
// List all available images
const registry = new ContainerRegistryBrowser('stargz-containers');
const images = await registry.listImages();

// Search for specific images
const pythonImages = await registry.searchImages('python');

// Get image details
const imageDetails = await registry.getImageDetails('ghcr.io/stargz-containers/alpine:latest');
```

#### Direct Lazy Loading API

```javascript
// For fine-grained control
startLazyWasi(
    'terminal-id',
    './src/worker.js',
    '/containers/my-image-container',
    5, // number of chunks
    {
        onChunkLoad: function(idx, total, loaded, totalSize) {
            updateProgressBar(loaded / totalSize);
        },
        onReady: function() {
            enableTerminalInput();
        },
        fetchOptions: {
            headers: { 'Custom-Header': 'value' }
        }
    }
);

// Monitor metrics
const metrics = getLazyLoadMetrics();
console.log(metrics);
```

## Architecture

### Component Interaction

```
┌─────────────────────────────────────────────┐
│   User Interface Layer                      │
│  ┌───────────────────────────────────────┐  │
│  │ stargz-container-launcher.html        │  │
│  │ (UI for discovery & launching)        │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────┐
│   API Layer                                 │
│  ┌───────────────────────────────────────┐  │
│  │ STARGZLauncher (high-level API)       │  │
│  │ ContainerRegistryBrowser (discovery)  │  │
│  │ ContainerLauncherUI (UI builders)     │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────┐
│   Runtime Layer                             │
│  ┌───────────────────────────────────────┐  │
│  │ startLazyWasi() (core loader)         │  │
│  │ loadChunksLazy() (chunk management)   │  │
│  │ loadChunkWithMetrics() (per-chunk)    │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────┐
│   Browser/Runtime                           │
│  ┌───────────────────────────────────────┐  │
│  │ Web Worker + WASM VM (container2wasm) │  │
│  │ xterm.js (terminal rendering)         │  │
│  │ Fetch API (chunk download)            │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## Implementation Details

### Chunk Loading Strategy

The system loads chunks in parallel with automatic retry:

```javascript
// All chunks load in parallel
Promise.all(chunkUrls.map(url => loadChunkWithRetry(url)))
    .then(chunks => initializeContainer(chunks))
```

### Metrics Tracking

Real-time metrics are collected for each chunk:

```javascript
{
    chunks: [
        { index: 0, loaded: true, size: 104857600, loadTime: 2345 },
        { index: 1, loaded: true, size: 104857600, loadTime: 1234 },
        // ...
    ],
    totalSize: 524288000,
    loadedSize: 524288000,
    allLoaded: true,
    elapsedTime: 8234,
    averageLoadTime: 1648
}
```

### Error Handling and Retries

Failed chunk loads are automatically retried:

```javascript
// Exponential backoff retry
async function loadChunkWithRetry(url, index, maxRetries, attempt = 0) {
    try {
        return await fetch(url);
    } catch (error) {
        if (attempt < maxRetries) {
            await delay(1000 * (attempt + 1)); // exponential backoff
            return loadChunkWithRetry(url, index, maxRetries, attempt + 1);
        }
        throw error;
    }
}
```

## Custom Integration

### Integrating with Your Registry

```javascript
class MyCustomRegistry extends ContainerRegistryBrowser {
    async listImages() {
        const response = await fetch('/api/my-registry/images');
        return response.json();
    }
    
    async fetchImageMetadata(imageRef) {
        const response = await fetch(`/api/my-registry/info/${imageRef}`);
        return response.json();
    }
}

// Use your custom registry
const registry = new MyCustomRegistry();
```

### Custom Fetch Implementation

```javascript
const launcher = new STARGZLauncher({
    fetchOptions: {
        headers: {
            'Authorization': `Bearer ${token}`,
            'X-Custom-Header': 'value'
        },
        credentials: 'include' // for cookies
    }
});
```

### Custom UI

```javascript
// Create custom UI using the API
async function renderMyCustomUI() {
    const registry = new ContainerRegistryBrowser();
    const images = await registry.listImages();
    
    images.forEach(img => {
        const button = createButton(img.name, () => {
            launcher.loadImage(img.ref);
        });
        document.body.appendChild(button);
    });
}
```

## Performance Optimization

### Chunk Size Selection

```
Small (25MB):  ✓ Fast initial response  ✗ More HTTP requests
Medium (100MB): ✓ Good balance          
Large (250MB): ✗ Slow initial response  ✓ Fewer HTTP requests
```

### CDN Deployment

```javascript
// Use CDN for chunks
const launcher = new STARGZLauncher({
    baseUrl: 'https://cdn.example.com/containers/'
});
```

### Prefetching Optimization

```javascript
// Predict and prefetch likely chunks
function setupPrefetch() {
    const link = document.createElement('link');
    link.rel = 'prefetch';
    link.href = '/containers/image-chunk-01.wasm';
    document.head.appendChild(link);
}
```

### HTTP/2 Server Push

Configure your server to push early chunks:

```
Link: </containers/image-chunk-00.wasm>; rel=preload; as=fetch
```

## Deployment

### Local Testing

```bash
# Install a local web server
npm install -g http-server

# Serve the directory
http-server .

# Access at http://localhost:8080
```

### Production Deployment

```bash
# Example with nginx
# nginx.conf
location /containers/ {
    types {
        application/wasm wasm;
    }
    add_header Accept-Ranges bytes;
    add_header Cache-Control "public, max-age=31536000";
}

# Example with Apache
<Directory "/var/www/containers">
    AddType application/wasm .wasm
    Header set Accept-Ranges bytes
    Header set Cache-Control "public, max-age=31536000"
</Directory>
```

### Docker Deployment

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Troubleshooting

### Chunk Download Failures

Check browser DevTools Network tab for:
- HTTP status codes (should be 200/206)
- Content-Length headers
- CORS errors
- Timeout issues

```javascript
// Enable debug logging
function enableDebugLogging() {
    const origFetch = window.fetch;
    window.fetch = function(...args) {
        console.log('Fetch:', args[0]);
        return origFetch.apply(this, args)
            .then(r => (console.log('Response:', r.status), r))
            .catch(e => (console.error('Error:', e), Promise.reject(e)));
    };
}
```

### Slow Performance

Profile using metrics:

```javascript
const metrics = getLazyLoadMetrics();
console.log(`Average chunk load time: ${metrics.averageLoadTime}ms`);
console.log(`Chunk breakdown:`, metrics.chunks.map(c => `${c.index}: ${c.loadTime}ms`));
```

### Container Startup Issues

Check browser console for errors. Ensure:
- WASM runtime support (SharedArrayBuffer)
- Sufficient memory available
- All dependencies loaded

## Testing

### Unit Testing Example

```javascript
// Test chunk loading
async function testChunkLoading() {
    const launcher = new STARGZLauncher();
    const metadata = await launcher.resolveImage('test-image');
    assert(metadata.size > 0);
    assert(metadata.layers > 0);
}

// Test metrics
function testMetrics() {
    const metrics = getLazyLoadMetrics();
    assert(metrics.chunks.length > 0);
    assert(metrics.totalSize > 0);
}
```

## Contributing

To add improvements:

1. Create new examples in `*.html` files
2. Extend `STARGZLauncher` class with new features
3. Add support for more registries in `ContainerRegistryBrowser`
4. Update documentation with findings

## References

- [container2wasm](https://github.com/ktock/container2wasm) - WebAssembly container runtime
- [STARGZ Snapshotter](https://github.com/containerd/stargz-snapshotter) - Lazy loading snapshotter
- [stargz-containers](https://github.com/stargz-containers) - Pre-built STARGZ images
- [xterm.js](https://xtermjs.org/) - Terminal emulator
- [Web Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API) - Parallel execution
- [HTTP Range Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range) - Partial content fetching

## FAQ

**Q: Can I use this with any Docker image?**
A: Only images that have been converted to STARGZ format. Pre-built images are available from stargz-containers.

**Q: What's the maximum image size?**
A: Limited by available browser memory and disk space. Typical ~1-2GB is practical.

**Q: Can multiple users launch containers simultaneously?**
A: Yes! The lazy loading approach enables efficient multi-user scenarios.

**Q: What about offline support?**
A: Service Worker integration could enable offline caching. See coi-serviceworker.js for COI handling.

**Q: How do I monitor performance?**
A: Use `getLazyLoadMetrics()` and `logLazyLoadMetrics()` functions for detailed breakdown.

## License

Same as the parent project (dockerweb). See LICENSE file for details.
