# Edge WebDriver 疑難排解指南

## 常見錯誤：session not created: Chrome instance exited

### 問題描述
當您看到以下錯誤訊息時：
```
ERROR - 啟動 Edge WebDriver 失敗: Message: session not created: Chrome instance exited
```

這表示 msedgedriver 無法成功啟動 Edge 瀏覽器。

---

## 解決方案

### 方案 1：確認版本兼容性（最常見原因）

#### 步驟 1：檢查 Edge 瀏覽器版本
1. 開啟 Edge 瀏覽器
2. 點擊右上角的「...」→「說明及意見反應」→「關於 Microsoft Edge」
3. 記下版本號，例如：`120.0.2210.133`

#### 步驟 2：檢查 msedgedriver 版本
```batch
cd C:\自動化
msedgedriver.exe --version
```
輸出範例：`MSEdgeDriver 120.0.2210.133`

#### 步驟 3：確認主版本號是否一致
- Edge 版本：**120**.0.2210.133
- Driver 版本：**120**.0.2210.133
- 主版本號（第一個數字）必須相同！

#### 步驟 4：下載相符版本的 msedgedriver
如果版本不符，請前往：
https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/

1. 選擇與您的 Edge 版本相符的 msedgedriver
2. 下載並解壓縮
3. 將 `msedgedriver.exe` 複製到 `C:\自動化\`
4. 覆蓋舊檔案

---

### 方案 2：手動設定 Edge 瀏覽器路徑

有時 Selenium 無法自動找到 Edge 的安裝位置。

#### 步驟 1：找到 Edge 安裝路徑
常見位置：
- `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- `C:\Program Files\Microsoft\Edge\Application\msedge.exe`

#### 步驟 2：在設定檔中指定路徑
編輯 `config.template.py` 或在腳本開頭設定：

```python
# 手動設定 Edge 瀏覽器路徑
EDGE_BINARY_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
```

**注意**：使用 `r"..."` 以避免反斜線轉義問題

---

### 方案 3：檢查檔案路徑

#### 檢查 msedgedriver.exe 是否存在
```batch
dir "C:\自動化\msedgedriver.exe"
```

如果顯示「找不到檔案」：
1. 確認 msedgedriver.exe 已下載並放置在正確位置
2. 確認路徑設定正確（注意中文字元）

#### 檢查路徑設定
在腳本中確認：
```python
DRIVER_PATH = r"C:\自動化\msedgedriver.exe"
```

---

### 方案 4：權限問題

#### 解決方法：以系統管理員身分執行

1. 右鍵點擊「命令提示字元」或「PowerShell」
2. 選擇「以系統管理員身分執行」
3. 切換到腳本目錄並執行：
   ```batch
   cd C:\自動化
   python google_trends_automation.py
   ```

---

### 方案 5：檢查 ODBC Driver

確保已安裝正確版本的 ODBC Driver。

#### 檢查已安裝的 ODBC Driver
```python
import pyodbc
print(pyodbc.drivers())
```

應該看到類似：
```
['SQL Server', 'ODBC Driver 17 for SQL Server', 'ODBC Driver 18 for SQL Server']
```

#### 如果缺少 ODBC Driver
下載並安裝：
https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

---

## 診斷工具

### 自動版本檢查
腳本已內建版本檢查功能，執行時會自動顯示：

```
============================================================
檢查 Edge WebDriver 版本兼容性
============================================================
✓ Edge 瀏覽器版本: 120.0.2210.133
  安裝路徑: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
✓ msedgedriver 版本: 120.0.2210.133
✓ 版本兼容 (主版本皆為 120)
============================================================
```

### 查看詳細錯誤日誌
腳本會產生詳細的日誌檔案：

1. **msedgedriver.log** - WebDriver 詳細日誌
2. **google_trends_automation.log** - 主程式日誌

檢查這些檔案以獲得更多診斷資訊。

---

## 測試 WebDriver 連線

建立測試腳本 `test_webdriver.py`：

```python
# -*- coding: utf-8 -*-
import os
from selenium import webdriver
from selenium.webdriver.edge.service import Service

# 設定
DRIVER_PATH = r"C:\自動化\msedgedriver.exe"
EDGE_BINARY_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

print("測試 Edge WebDriver...")
print(f"Driver 路徑: {DRIVER_PATH}")
print(f"Driver 存在: {os.path.exists(DRIVER_PATH)}")
print(f"Edge 路徑: {EDGE_BINARY_PATH}")
print(f"Edge 存在: {os.path.exists(EDGE_BINARY_PATH)}")

try:
    options = webdriver.EdgeOptions()
    options.binary_location = EDGE_BINARY_PATH
    
    service = Service(DRIVER_PATH)
    driver = webdriver.Edge(service=service, options=options)
    
    print("✓ WebDriver 啟動成功！")
    
    # 測試導航
    driver.get("https://www.bing.com")
    print(f"✓ 頁面標題: {driver.title}")
    
    driver.quit()
    print("✓ 測試完成！")
    
except Exception as e:
    print(f"✗ 錯誤: {e}")
```

執行測試：
```batch
python test_webdriver.py
```

---

## 常見問題 FAQ

### Q1: 為什麼錯誤訊息提到 "Chrome" 但我用的是 Edge？
**A:** Edge 基於 Chromium 引擎，因此內部錯誤訊息可能包含 "Chrome" 字樣，這是正常的。

### Q2: 我已經下載了最新的 msedgedriver，但還是失敗？
**A:** 確保 msedgedriver 版本與您的 Edge **當前安裝版本**相符，而不是最新版本。Edge 可能沒有自動更新到最新版。

### Q3: 使用 Selenium Manager 自動管理 WebDriver？
**A:** Selenium 4.6+ 支援自動下載 WebDriver，但目前的腳本使用手動指定路徑以獲得更好的控制。如果您想使用自動管理：
```python
# 不指定 service，讓 Selenium Manager 處理
driver = webdriver.Edge(options=options)
```

### Q4: 如何確認腳本使用的是哪個 Edge 路徑？
**A:** 查看腳本輸出的日誌：
```
使用自動偵測的 Edge 路徑: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
```

### Q5: 我使用的是 Canary 或 Dev 版本的 Edge，如何處理？
**A:** 這些版本有不同的路徑和 WebDriver，請：
1. 下載對應版本的 msedgedriver
2. 指定正確的 binary_location
3. 例如 Canary: `C:\Users\[User]\AppData\Local\Microsoft\Edge SxS\Application\msedge.exe`

---

## 進階診斷

### 啟用 WebDriver 詳細日誌
在建立 Service 時啟用詳細日誌：

```python
service = Service(DRIVER_PATH)
service.log_path = "msedgedriver_verbose.log"
service.service_args = ['--verbose']
```

### 檢查系統環境變數
確認 PATH 環境變數沒有衝突的 WebDriver：
```batch
echo %PATH%
where msedgedriver.exe
```

---

## 仍然無法解決？

### 提供以下資訊以獲得幫助：

1. **Edge 版本**（從 Edge 瀏覽器查看）
2. **msedgedriver 版本**（執行 `msedgedriver.exe --version`）
3. **Python 版本**（執行 `python --version`）
4. **Selenium 版本**（執行 `pip show selenium`）
5. **完整錯誤訊息**（從 `google_trends_automation.log`）
6. **msedgedriver.log 內容**

### 聯絡支援
將上述資訊整理後，可以：
- 在 GitHub Issues 中提問
- 查看 Selenium 官方文檔
- 搜尋 Stack Overflow 相關問題

---

**更新日期**: 2026-02-16  
**適用版本**: V2 Google Trends Automation
