const NATIVE_HOST_NAME = 'com.outline.proxy';
const LOCAL_PROXY_PORT = 1080;

let state = {
  isConnected: false,
  nativeHostAvailable: true,
  nativePort: null,
  serverHost: null
};

// Update extension icon badge
function updateBadge(connected) {
  chrome.action.setBadgeText({ text: ' ' });
  if (connected) {
    chrome.action.setBadgeBackgroundColor({ color: '#22c55e' }); // green
  } else {
    chrome.action.setBadgeBackgroundColor({ color: '#ef4444' }); // red
  }
}

// Parse Outline/Shadowsocks access key
function parseAccessKey(accessKey) {
  try {
    // Format: ss://BASE64@host:port/?outline=1
    // or: ss://BASE64#name
    // BASE64 = method:password

    let url = accessKey.trim();

    // Remove ss:// prefix
    if (!url.startsWith('ss://')) {
      throw new Error('Invalid protocol');
    }

    url = url.substring(5);

    // Remove fragment (#name)
    const fragmentIndex = url.indexOf('#');
    if (fragmentIndex !== -1) {
      url = url.substring(0, fragmentIndex);
    }

    // Remove query string
    const queryIndex = url.indexOf('?');
    if (queryIndex !== -1) {
      url = url.substring(0, queryIndex);
    }

    // Check for userinfo@host:port format (SIP002)
    const atIndex = url.lastIndexOf('@');

    let method, password, host, port;

    if (atIndex !== -1) {
      // SIP002 format: base64(method:password)@host:port
      const userinfo = url.substring(0, atIndex);
      const hostPort = url.substring(atIndex + 1);

      // Decode userinfo
      const decoded = atob(userinfo);
      const colonIndex = decoded.indexOf(':');
      if (colonIndex === -1) {
        throw new Error('Invalid userinfo format');
      }
      method = decoded.substring(0, colonIndex);
      password = decoded.substring(colonIndex + 1);

      // Parse host:port
      const lastColon = hostPort.lastIndexOf(':');
      if (lastColon === -1) {
        throw new Error('Missing port');
      }
      host = hostPort.substring(0, lastColon);
      port = parseInt(hostPort.substring(lastColon + 1), 10);
    } else {
      // Legacy format: base64(method:password@host:port)
      const decoded = atob(url);
      const atIdx = decoded.lastIndexOf('@');
      if (atIdx === -1) {
        throw new Error('Invalid legacy format');
      }

      const methodPass = decoded.substring(0, atIdx);
      const hostPort = decoded.substring(atIdx + 1);

      const colonIdx = methodPass.indexOf(':');
      method = methodPass.substring(0, colonIdx);
      password = methodPass.substring(colonIdx + 1);

      const lastColon = hostPort.lastIndexOf(':');
      host = hostPort.substring(0, lastColon);
      port = parseInt(hostPort.substring(lastColon + 1), 10);
    }

    if (!method || !password || !host || !port) {
      throw new Error('Missing required fields');
    }

    return { method, password, host, port };
  } catch (e) {
    console.error('Parse error:', e);
    throw new Error('Неверный формат Outline ключа');
  }
}

// Connect to native host
function connectNativeHost() {
  return new Promise((resolve, reject) => {
    try {
      state.nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);

      state.nativePort.onMessage.addListener((msg) => {
        console.log('Native message:', msg);
        if (msg.type === 'READY') {
          state.nativeHostAvailable = true;
          resolve(true);
        } else if (msg.type === 'ERROR') {
          reject(new Error(msg.error));
        } else if (msg.type === 'CONNECTED') {
          // Proxy started successfully
        } else if (msg.type === 'DISCONNECTED') {
          state.isConnected = false;
          updateBadge(false);
          clearProxy();
        }
      });

      state.nativePort.onDisconnect.addListener(() => {
        const error = chrome.runtime.lastError;
        console.log('Native host disconnected:', error?.message);
        state.nativePort = null;

        if (error?.message?.includes('not found') ||
            error?.message?.includes('not installed')) {
          state.nativeHostAvailable = false;
          reject(new Error('Native host not installed'));
        }
      });

      // Wait a bit for connection
      setTimeout(() => {
        if (state.nativePort) {
          resolve(true);
        }
      }, 500);
    } catch (e) {
      state.nativeHostAvailable = false;
      reject(e);
    }
  });
}

// Send message to native host
function sendNativeMessage(msg) {
  return new Promise((resolve, reject) => {
    if (!state.nativePort) {
      reject(new Error('Native host not connected'));
      return;
    }

    const responseHandler = (response) => {
      state.nativePort.onMessage.removeListener(responseHandler);
      resolve(response);
    };

    state.nativePort.onMessage.addListener(responseHandler);
    state.nativePort.postMessage(msg);

    // Timeout
    setTimeout(() => {
      state.nativePort?.onMessage.removeListener(responseHandler);
      resolve({ type: 'TIMEOUT' });
    }, 10000);
  });
}

// Set Chrome proxy settings
async function setProxy(port) {
  const config = {
    mode: 'fixed_servers',
    rules: {
      singleProxy: {
        scheme: 'socks5',
        host: '127.0.0.1',
        port: port
      },
      bypassList: [
        'localhost',
        '127.0.0.1',
        '192.168.*',
        '10.*',
        '172.16.*',
        '172.17.*',
        '172.18.*',
        '172.19.*',
        '172.20.*',
        '172.21.*',
        '172.22.*',
        '172.23.*',
        '172.24.*',
        '172.25.*',
        '172.26.*',
        '172.27.*',
        '172.28.*',
        '172.29.*',
        '172.30.*',
        '172.31.*'
      ]
    }
  };

  return chrome.proxy.settings.set({
    value: config,
    scope: 'regular'
  });
}

// Clear proxy settings
async function clearProxy() {
  return chrome.proxy.settings.clear({ scope: 'regular' });
}

// Handle connect request
async function handleConnect(accessKey) {
  try {
    // Parse the access key
    const config = parseAccessKey(accessKey);
    state.serverHost = `${config.host}:${config.port}`;

    // Connect to native host if not connected
    if (!state.nativePort) {
      await connectNativeHost();
    }

    // Send start command to native host
    const response = await sendNativeMessage({
      type: 'START',
      config: {
        server: config.host,
        serverPort: config.port,
        localPort: LOCAL_PROXY_PORT,
        method: config.method,
        password: config.password
      }
    });

    if (response.type === 'ERROR') {
      throw new Error(response.error);
    }

    // Set Chrome proxy to use local SOCKS5
    await setProxy(LOCAL_PROXY_PORT);

    state.isConnected = true;
    updateBadge(true);

    // Save state
    await chrome.storage.local.set({
      isConnected: true,
      serverHost: state.serverHost
    });

    return {
      success: true,
      serverHost: state.serverHost
    };
  } catch (e) {
    console.error('Connect error:', e);
    return {
      success: false,
      error: e.message,
      nativeHostAvailable: state.nativeHostAvailable
    };
  }
}

// Handle disconnect request
async function handleDisconnect() {
  try {
    // Send stop command to native host
    if (state.nativePort) {
      await sendNativeMessage({ type: 'STOP' });
    }

    // Clear proxy
    await clearProxy();

    state.isConnected = false;
    state.serverHost = null;
    updateBadge(false);

    await chrome.storage.local.set({ isConnected: false });

    return { success: true };
  } catch (e) {
    console.error('Disconnect error:', e);
    // Clear proxy anyway
    await clearProxy();
    state.isConnected = false;
    updateBadge(false);
    return { success: true };
  }
}

// Message handler
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    switch (message.type) {
      case 'GET_STATUS':
        sendResponse({
          isConnected: state.isConnected,
          nativeHostAvailable: state.nativeHostAvailable,
          serverHost: state.serverHost
        });
        break;

      case 'CONNECT':
        const connectResult = await handleConnect(message.accessKey);
        sendResponse(connectResult);
        break;

      case 'DISCONNECT':
        const disconnectResult = await handleDisconnect();
        sendResponse(disconnectResult);
        break;

      default:
        sendResponse({ error: 'Unknown message type' });
    }
  })();

  return true; // Keep channel open for async response
});

// On install/update
chrome.runtime.onInstalled.addListener(async () => {
  // Check if we were connected before
  const stored = await chrome.storage.local.get(['isConnected', 'accessKey']);

  if (stored.isConnected && stored.accessKey) {
    // Try to reconnect
    console.log('Attempting to restore connection...');
    // We don't auto-reconnect for security, but we restore the state indicator
    state.isConnected = false;
    await chrome.storage.local.set({ isConnected: false });
  }
});

// Clean up on extension unload
chrome.runtime.onSuspend?.addListener(async () => {
  if (state.isConnected) {
    await handleDisconnect();
  }
});

// Initialize badge on startup
updateBadge(false);

console.log('Outline Proxy background script loaded');
