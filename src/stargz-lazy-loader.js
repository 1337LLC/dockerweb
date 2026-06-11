/**
 * STARGZ Lazy Loader for Container WASM
 * 
 * This module provides lazy loading capabilities for containers converted to WASM,
 * with support for progressive chunk loading and performance metrics tracking.
 * 
 * Usage:
 *   startLazyWasi(elementId, workerPath, imageNamePrefix, numChunks, options)
 * 
 * Options:
 *   - onChunkLoad: callback(chunkIndex, totalChunks, bytesLoaded, totalBytes)
 *   - onReady: callback() - called when container is ready
 *   - onError: callback(error) - called on load error
 *   - fetchOptions: custom fetch options (e.g., headers, credentials)
 */

var lazyWorker;
var lazyStackWorker;
var lazyLoadMetrics = {
  chunks: [],
  totalSize: 0,
  loadedSize: 0,
  startTime: 0,
  chunkSizes: {}
};

/**
 * Start WASI container with lazy loading of chunks
 * @param {string} elemId - Terminal element ID
 * @param {string} workerFileName - Worker script path
 * @param {string} imageNamePrefix - Base path for container chunks
 * @param {number} numChunks - Number of chunks to load
 * @param {object} options - Configuration options
 */
function startLazyWasi(elemId, workerFileName, imageNamePrefix, numChunks, options) {
  options = options || {};
  lazyLoadMetrics.startTime = Date.now();
  
  // Initialize metrics
  lazyLoadMetrics.chunks = [];
  lazyLoadMetrics.loadedSize = 0;
  for (let i = 0; i < numChunks; i++) {
    lazyLoadMetrics.chunks.push({
      index: i,
      loaded: false,
      size: 0,
      startTime: null,
      endTime: null
    });
  }
  
  const xterm = new Terminal();
  xterm.open(document.getElementById(elemId));
  const { master, slave } = openpty();
  var termios = slave.ioctl("TCGETS");
  termios.iflag &= ~(/*IGNBRK | BRKINT | PARMRK |*/ ISTRIP | INLCR | IGNCR | ICRNL | IXON);
  termios.oflag &= ~(OPOST);
  termios.lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
  slave.ioctl("TCSETS", new Termios(termios.iflag, termios.oflag, termios.cflag, termios.lflag, termios.cc));
  xterm.loadAddon(master);
  
  lazyWorker = new Worker(workerFileName);
  
  // Load chunks with lazy loading strategy
  loadChunksLazy(imageNamePrefix, numChunks, options, function(chunks) {
    var nwStack;
    var netParam = getNetParam();
    if (!netParam || netParam.mode != 'none') {
      lazyStackWorker = new Worker("./src/stack-worker.js"+location.search);
      nwStack = newStack(lazyWorker, imageNamePrefix, chunks, new URL("./src/c2w-net-proxy.wasm", location.href).href);
    }
    if (!nwStack) {
      lazyWorker.postMessage({type: "init", imagename: imageNamePrefix, chunks: chunks});
    }
    new TtyServer(slave).start(lazyWorker, nwStack);
    
    // Call ready callback
    if (options.onReady) {
      options.onReady();
    }
  });
}

/**
 * Load container chunks with lazy loading and progress tracking
 * @param {string} baseUrl - Base URL for chunks
 * @param {number} numChunks - Number of chunks
 * @param {object} options - Configuration options
 * @param {function} onComplete - Callback when ready to start
 */
function loadChunksLazy(baseUrl, numChunks, options, onComplete) {
  const chunkUrls = [];
  for (let i = 0; i < numChunks; i++) {
    chunkUrls.push(`${baseUrl}${String(i).padStart(2, '0')}.wasm`);
  }
  
  // Start loading all chunks, but process them for the metrics
  const chunkPromises = chunkUrls.map((url, index) => {
    return loadChunkWithMetrics(url, index, numChunks, options);
  });
  
  // Once all chunks are loaded
  Promise.all(chunkPromises).then(chunks => {
    lazyLoadMetrics.loadedSize = lazyLoadMetrics.totalSize;
    
    // Notify final progress
    if (options.onChunkLoad) {
      options.onChunkLoad(numChunks - 1, numChunks, lazyLoadMetrics.loadedSize, lazyLoadMetrics.totalSize);
    }
    
    onComplete(chunks);
  }).catch(err => {
    if (options.onError) {
      options.onError(err);
    }
    console.error('Failed to load container chunks:', err);
  });
}

/**
 * Load a single chunk with progress tracking
 * @param {string} url - Chunk URL
 * @param {number} index - Chunk index
 * @param {number} totalChunks - Total number of chunks
 * @param {object} options - Configuration options
 * @returns {Promise<Uint8Array>} - Loaded chunk data
 */
function loadChunkWithMetrics(url, index, totalChunks, options) {
  return new Promise((resolve, reject) => {
    lazyLoadMetrics.chunks[index].startTime = Date.now();
    
    const fetchOpts = options.fetchOptions || {};
    
    fetch(url, fetchOpts)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: Failed to fetch ${url}`);
        }
        
        // Get content length for progress tracking
        const contentLength = parseInt(response.headers.get('content-length'), 10);
        lazyLoadMetrics.chunks[index].size = contentLength;
        lazyLoadMetrics.totalSize += contentLength;
        
        return response.arrayBuffer();
      })
      .then(buffer => {
        const uint8Array = new Uint8Array(buffer);
        lazyLoadMetrics.chunks[index].loaded = true;
        lazyLoadMetrics.chunks[index].endTime = Date.now();
        lazyLoadMetrics.loadedSize += uint8Array.length;
        
        // Call progress callback
        if (options.onChunkLoad) {
          options.onChunkLoad(index, totalChunks, lazyLoadMetrics.loadedSize, lazyLoadMetrics.totalSize);
        }
        
        resolve(uint8Array);
      })
      .catch(reject);
  });
}

/**
 * Get container network parameters from URL
 * @returns {object|null} - Network parameters or null
 */
function getNetParam() {
  var vars = location.search.substring(1).split('&');
  for (var i = 0; i < vars.length; i++) {
    var kv = vars[i].split('=');
    if (decodeURIComponent(kv[0]) == 'net') {
      return {
        mode: kv[1],
        param: kv[2],
      };
    }
  }
  return null;
}

/**
 * Get current lazy loading metrics
 * @returns {object} - Metrics object
 */
function getLazyLoadMetrics() {
  const elapsedTime = Date.now() - lazyLoadMetrics.startTime;
  const allLoaded = lazyLoadMetrics.chunks.every(c => c.loaded);
  
  return {
    chunks: lazyLoadMetrics.chunks.map(c => ({
      index: c.index,
      loaded: c.loaded,
      size: c.size,
      loadTime: c.endTime && c.startTime ? c.endTime - c.startTime : null
    })),
    totalSize: lazyLoadMetrics.totalSize,
    loadedSize: lazyLoadMetrics.loadedSize,
    allLoaded: allLoaded,
    elapsedTime: elapsedTime,
    averageLoadTime: allLoaded ? elapsedTime / lazyLoadMetrics.chunks.length : null
  };
}

/**
 * Log detailed lazy loading metrics to console
 */
function logLazyLoadMetrics() {
  const metrics = getLazyLoadMetrics();
  console.log('=== STARGZ Lazy Load Metrics ===');
  console.log(`Total Size: ${(metrics.totalSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`Loaded Size: ${(metrics.loadedSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`All Loaded: ${metrics.allLoaded}`);
  console.log(`Total Time: ${metrics.elapsedTime}ms`);
  console.log(`Average Load Time: ${metrics.averageLoadTime ? metrics.averageLoadTime.toFixed(2) : 'N/A'}ms`);
  console.log('Chunks:');
  metrics.chunks.forEach(chunk => {
    console.log(`  [${chunk.index}] ${chunk.loaded ? '✓' : '✗'} ${(chunk.size / 1024).toFixed(1)}KB ${chunk.loadTime ? `(${chunk.loadTime}ms)` : ''}`);
  });
}
