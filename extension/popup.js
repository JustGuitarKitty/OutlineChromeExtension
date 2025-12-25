const NATIVE_HOST_NAME = 'com.outline.proxy';

class OutlinePopup {
  constructor() {
    this.isConnected = false;
    this.nativeHostAvailable = false;

    this.elements = {
      toggleBtn: document.getElementById('toggleBtn'),
      statusDot: document.getElementById('statusDot'),
      statusText: document.getElementById('statusText'),
      accessKey: document.getElementById('accessKey'),
      errorMsg: document.getElementById('errorMsg'),
      nativeWarning: document.getElementById('nativeWarning'),
      serverInfo: document.getElementById('serverInfo'),
      installLink: document.getElementById('installLink'),
      extId: document.getElementById('extId')
    };

    this.init();
  }

  async init() {
    // Show extension ID in footer
    const footerExtId = document.getElementById('footerExtId');
    if (footerExtId) {
      footerExtId.textContent = chrome.runtime.id;
    }

    // Load saved state
    const stored = await chrome.storage.local.get(['accessKey', 'isConnected', 'serverHost']);

    if (stored.accessKey) {
      this.elements.accessKey.value = stored.accessKey;
    }

    // Check connection status from background
    try {
      const response = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });
      this.isConnected = response?.isConnected || false;
      this.nativeHostAvailable = response?.nativeHostAvailable ?? true;

      if (response?.serverHost) {
        this.elements.serverInfo.textContent = `Сервер: ${response.serverHost}`;
      }
    } catch (e) {
      console.error('Failed to get status:', e);
    }

    this.updateUI();
    this.bindEvents();
  }

  bindEvents() {
    this.elements.toggleBtn.addEventListener('click', () => this.toggle());

    this.elements.accessKey.addEventListener('input', () => {
      chrome.storage.local.set({ accessKey: this.elements.accessKey.value });
      this.hideError();
    });

    this.elements.installLink.addEventListener('click', (e) => {
      e.preventDefault();
      chrome.tabs.create({ url: chrome.runtime.getURL('install.html') });
    });
  }

  async toggle() {
    const accessKey = this.elements.accessKey.value.trim();

    if (!this.isConnected) {
      // Connect
      if (!accessKey) {
        this.showError('Введите Outline Access Key');
        return;
      }

      if (!accessKey.startsWith('ss://')) {
        this.showError('Неверный формат ключа. Должен начинаться с ss://');
        return;
      }

      this.elements.toggleBtn.disabled = true;
      this.elements.toggleBtn.textContent = 'Подключение...';

      try {
        const response = await chrome.runtime.sendMessage({
          type: 'CONNECT',
          accessKey: accessKey
        });

        if (response.success) {
          this.isConnected = true;
          this.elements.serverInfo.textContent = `Сервер: ${response.serverHost}`;
          chrome.storage.local.set({ serverHost: response.serverHost });
        } else {
          this.showError(response.error || 'Не удалось подключиться');
          this.nativeHostAvailable = response.nativeHostAvailable ?? true;
        }
      } catch (e) {
        this.showError('Ошибка: ' + e.message);
      }
    } else {
      // Disconnect
      this.elements.toggleBtn.disabled = true;
      this.elements.toggleBtn.textContent = 'Отключение...';

      try {
        await chrome.runtime.sendMessage({ type: 'DISCONNECT' });
        this.isConnected = false;
        this.elements.serverInfo.textContent = '';
      } catch (e) {
        this.showError('Ошибка: ' + e.message);
      }
    }

    this.updateUI();
  }

  updateUI() {
    this.elements.toggleBtn.disabled = false;

    if (this.isConnected) {
      this.elements.statusDot.classList.add('connected');
      this.elements.statusText.textContent = 'Подключено';
      this.elements.toggleBtn.textContent = 'Отключиться';
      this.elements.toggleBtn.classList.remove('connect');
      this.elements.toggleBtn.classList.add('disconnect');
      this.elements.accessKey.disabled = true;
    } else {
      this.elements.statusDot.classList.remove('connected');
      this.elements.statusText.textContent = 'Отключено';
      this.elements.toggleBtn.textContent = 'Подключиться';
      this.elements.toggleBtn.classList.remove('disconnect');
      this.elements.toggleBtn.classList.add('connect');
      this.elements.accessKey.disabled = false;
    }

    // Show native host warning if not available
    if (!this.nativeHostAvailable) {
      this.elements.nativeWarning.style.display = 'block';
      this.elements.extId.textContent = chrome.runtime.id;
    } else {
      this.elements.nativeWarning.style.display = 'none';
    }
  }

  showError(msg) {
    this.elements.errorMsg.textContent = msg;
    this.elements.errorMsg.style.display = 'block';
  }

  hideError() {
    this.elements.errorMsg.style.display = 'none';
  }
}

document.addEventListener('DOMContentLoaded', () => {
  new OutlinePopup();
});
