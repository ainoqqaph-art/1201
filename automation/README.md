# Microsoft Rewards 自動化工具

這是一個用於自動化 Microsoft Rewards 點數收集的 Python 腳本，適合由 Windows Task Scheduler 或其他排程工具呼叫。

## 功能說明

此腳本執行以下三個主要步驟：

1. **抓取 Google Trends 熱門關鍵字**：從 Google Trends 抓取當前熱門的關鍵字（一次性操作）
2. **Bing 搜尋自動化**：針對抓取到的前 5 個關鍵字，在 Bing 上進行搜尋並擷取摘要
   - 每個關鍵字之間間隔 30-90 秒
   - 完成所有搜尋後休息 2-5 分鐘
3. **記錄 Microsoft Rewards 點數**：抓取當日點數並寫入 SQL Server 資料庫（一次性操作）

## 系統需求

### 軟體需求
- Python 3.7 或更高版本
- Microsoft Edge 瀏覽器
- Microsoft Edge WebDriver (msedgedriver.exe)
- SQL Server 與 ODBC Driver 17 for SQL Server
- Windows 作業系統（用於 Windows Authentication）

### Python 套件
```bash
pip install -r requirements.txt
```

主要依賴套件：
- `selenium>=4.15.0` - 網頁自動化
- `pyodbc>=5.0.0` - SQL Server 連接

## 安裝步驟

### 1. 下載 Microsoft Edge WebDriver

1. 檢查您的 Edge 版本：
   - 開啟 Edge 瀏覽器
   - 前往 `edge://settings/help`
   - 記下版本號碼

2. 下載對應版本的 WebDriver：
   - 訪問 https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/
   - 下載與您的 Edge 版本相符的 WebDriver
   - 解壓縮並將 `msedgedriver.exe` 放置於 `C:\自動化\` 目錄

### 2. 設定資料庫

執行以下 SQL 腳本建立所需的資料表：

```sql
-- 建立資料庫（如果不存在）
CREATE DATABASE MicrosoftRDB;
GO

USE MicrosoftRDB;
GO

-- 建立 TrendingKeywords 資料表
CREATE TABLE TrendingKeywords (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Keyword NVARCHAR(500) NOT NULL,
    Rank INT NOT NULL,
    SearchVolume NVARCHAR(100),
    FetchedAt DATETIME NOT NULL
);
GO

-- 建立 DailyPointsLog 資料表
CREATE TABLE DailyPointsLog (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Points INT NOT NULL,
    ActivityType NVARCHAR(100) NOT NULL,
    LoggedAt DATETIME NOT NULL
);
GO

-- 建立索引以提升查詢效能
CREATE INDEX IX_TrendingKeywords_FetchedAt ON TrendingKeywords(FetchedAt);
CREATE INDEX IX_DailyPointsLog_LoggedAt ON DailyPointsLog(LoggedAt);
GO
```

### 3. 安裝 Python 套件

```bash
cd automation
pip install -r requirements.txt
```

## 設定說明

編輯 `microsoft_rewards_automation.py` 檔案中的設定區：

```python
# ==================== 設定區 ====================
SQL_SERVER = 'localhost'  # SQL Server 位址
SQL_DATABASE = 'MicrosoftRDB'  # 資料庫名稱
DRIVER_PATH = r"C:\自動化\msedgedriver.exe"  # WebDriver 路徑

# Google Trends URL（可改地區或排序）
TRENDS_URL = "https://trends.google.com.tw/trending?geo=US&status=active&sort=search-volume"

# 前 N 名關鍵字要做額外搜尋
TOP_N = 5

# 前五關鍵字搜尋間隔（秒）
PER_KEYWORD_MIN = 30
PER_KEYWORD_MAX = 90

# 每完成所有關鍵字後的額外休息（秒）
AFTER_ALL_KEYWORDS_MIN = 120  # 2 分鐘
AFTER_ALL_KEYWORDS_MAX = 300  # 5 分鐘

# 若 Rewards 需要已登入 session，可啟用 Edge profile（選用）
EDGE_USER_DATA_DIR = None  # r"C:\Users\<YourUser>\AppData\Local\Microsoft\Edge\User Data"
EDGE_PROFILE = None  # "Default"
```

### 使用 Edge Profile（選用）

如果您想使用已登入 Microsoft 帳號的 Edge 設定檔：

1. 關閉所有 Edge 視窗
2. 找到您的 Edge User Data 目錄（通常在 `C:\Users\<YourUser>\AppData\Local\Microsoft\Edge\User Data`）
3. 在腳本中設定：
   ```python
   EDGE_USER_DATA_DIR = r"C:\Users\<YourUser>\AppData\Local\Microsoft\Edge\User Data"
   EDGE_PROFILE = "Default"  # 或其他設定檔名稱
   ```

## 使用方式

### 基本執行
```bash
python microsoft_rewards_automation.py
```

### 測試模式（不寫入資料庫）
```bash
python microsoft_rewards_automation.py --dry-run
```

### 跳過特定步驟
```bash
# 跳過 Google Trends 抓取
python microsoft_rewards_automation.py --skip-trends

# 跳過 Bing 搜尋
python microsoft_rewards_automation.py --skip-search

# 跳過 Rewards 點數抓取
python microsoft_rewards_automation.py --skip-rewards
```

### 組合使用
```bash
# 只執行 Bing 搜尋，跳過其他步驟
python microsoft_rewards_automation.py --skip-trends --skip-rewards
```

## Windows Task Scheduler 設定

1. 開啟「工作排程器」（Task Scheduler）
2. 建立基本工作：
   - 名稱：Microsoft Rewards 自動化
   - 觸發程序：每日（例如：每天早上 9:00）
   - 動作：啟動程式
     - 程式/指令碼：`python.exe`
     - 新增引數：`"C:\path\to\automation\microsoft_rewards_automation.py"`
     - 開始位置：`C:\path\to\automation\`
3. 進階設定：
   - 勾選「以最高權限執行」
   - 設定失敗時重試次數

## 日誌檔案

腳本會在執行目錄產生 `microsoft_rewards_automation.log` 日誌檔案，記錄所有操作與錯誤訊息。

範例日誌內容：
```
2026-02-16 10:00:00 - INFO - 成功連接到 SQL Server
2026-02-16 10:00:05 - INFO - Edge WebDriver 已啟動
2026-02-16 10:00:10 - INFO - === 步驟 1: 抓取 Google Trends 熱門關鍵字 ===
2026-02-16 10:00:15 - INFO - 發現關鍵字 #1: 熱門關鍵字範例
2026-02-16 10:00:20 - INFO - 成功抓取 5 個關鍵字
```

## 錯誤處理

腳本包含以下錯誤處理機制：

- **重試機制**：Google Trends 抓取失敗時會自動重試最多 3 次
- **指數退避**：重試間隔會逐漸增加（2秒、4秒、8秒）
- **資源清理**：無論執行成功或失敗，都會正確關閉 WebDriver 和資料庫連線
- **詳細日誌**：所有錯誤都會記錄在日誌檔案中，包含完整的堆疊追蹤

## 注意事項

1. **WebDriver 版本相容性**：確保 msedgedriver.exe 的版本與您的 Edge 瀏覽器版本相符
2. **Windows Authentication**：腳本使用 Windows Authentication 連接 SQL Server，請確保執行腳本的使用者有適當的資料庫權限
3. **網頁結構變化**：Google Trends 和 Microsoft Rewards 的網頁結構可能會改變，需要更新 CSS Selector
4. **帳號安全**：建議使用專用的 Microsoft 帳號，避免使用主要帳號
5. **執行頻率**：不建議過於頻繁執行，以免觸發反機器人機制

## 疑難排解

### WebDriver 無法啟動
- 確認 msedgedriver.exe 路徑正確
- 確認 Edge 瀏覽器已安裝
- 確認 WebDriver 版本與 Edge 版本相符

### 資料庫連線失敗
- 確認 SQL Server 服務正在運行
- 確認 ODBC Driver 17 for SQL Server 已安裝
- 確認使用者有資料庫存取權限

### 無法抓取關鍵字或點數
- 檢查網路連線
- 查看日誌檔案中的錯誤訊息
- 可能需要更新 CSS Selector（網頁結構已變化）

## 授權

此腳本僅供個人學習與研究使用。使用時請遵守 Microsoft 服務條款與相關法規。

## 版本歷史

- v1.0.0 (2026-02-16)
  - 初始版本
  - 實作 Google Trends 關鍵字抓取
  - 實作 Bing 搜尋自動化
  - 實作 Microsoft Rewards 點數記錄
  - 支援 Windows Authentication 連接 SQL Server
