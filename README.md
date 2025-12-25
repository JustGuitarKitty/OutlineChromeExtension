# Outline Proxy - Chrome Extension

Расширение Chrome для подключения к Outline VPN серверам.

## Установка

### Windows

1. **Скачай** `OutlineProxy-Windows.zip` из [Releases](../../releases)
2. **Распакуй** в любую папку
3. **Запусти** `setup.bat`
4. В Chrome: `chrome://extensions` → Developer mode → Load unpacked → выбери папку `extension`
5. Скопируй Extension ID из Chrome и вставь в скрипт
6. Вставь `ss://...` ключ → Подключиться

### Linux / macOS

```bash
./install.sh
```

### Удаление

Windows: запусти `uninstall.bat` или `.\uninstall.ps1`
Linux/macOS: `./uninstall.sh`

---

## Сборка

```powershell
# Windows - собрать установщик
.\build-installer.ps1

# Разработка
.\install.ps1      # Windows
./install.sh       # Linux/macOS
```

---

## Как это работает

```
Chrome Extension
      │
      ▼ (Native Messaging)
Native Host + sslocal
      │
      ▼ (Shadowsocks)
Outline VPN Server
```

## Требования

- Windows 10/11, Linux или macOS
- Chrome, Edge или Brave
- Outline Access Key (`ss://...`)

## Лицензия

MIT

---

# English

# Outline Proxy - Chrome Extension

Chrome extension for connecting to Outline VPN servers.

## Installation

### Windows

1. **Download** `OutlineProxy-Windows.zip` from [Releases](../../releases)
2. **Extract** to any folder
3. **Run** `setup.bat`
4. In Chrome: `chrome://extensions` → Developer mode → Load unpacked → select `extension` folder
5. Copy Extension ID from Chrome and paste into the script
6. Paste your `ss://...` access key → Connect

### Linux / macOS

```bash
./install.sh
```

### Uninstall

Windows: run `uninstall.bat` or `.\uninstall.ps1`
Linux/macOS: `./uninstall.sh`

---

## Building

```powershell
# Windows - build installer
.\build-installer.ps1

# Development
.\install.ps1      # Windows
./install.sh       # Linux/macOS
```

---

## How it works

```
Chrome Extension
      │
      ▼ (Native Messaging)
Native Host + sslocal
      │
      ▼ (Shadowsocks)
Outline VPN Server
```

## Requirements

- Windows 10/11, Linux or macOS
- Chrome, Edge or Brave
- Outline Access Key (`ss://...`)

## License

MIT
