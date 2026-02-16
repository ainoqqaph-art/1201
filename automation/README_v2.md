# Google Trends 關鍵字自動化抓取工具

這是一個用於自動化抓取 Google Trends 熱門關鍵字並進行 Bing 搜尋的 Python 腳本，適合由 Windows Task Scheduler 或其他排程工具呼叫。

## ⚠️ 重大變更說明

**版本 2.0**：本版本已移除 Microsoft Rewards 點數抓取功能，專注於 Google Trends 關鍵字收集與分析。

### 主要變更
- ✅ **移除** Microsoft Rewards 點數抓取功能
- ✅ **新增** 搜尋量（Search Volume）抓取功能
- ✅ **增加** 每個地區從 5 個關鍵字提升至 **20 個關鍵字**
- ✅ **新增** 資料庫欄位：SearchVolume、Region、TrendRank
- ✅ **簡化** 執行流程，只保留關鍵字抓取與搜尋

## 功能說明

此腳本執行以下兩個主要步驟：

1. **抓取 Google Trends 熱門關鍵字**：從多個地區抓取當前熱門的關鍵字
   - 支援 6 個地區：美國、台灣、日本、英國、香港、澳洲
   - **每個地區抓取 20 個關鍵字**（可配置）
   - **抓取並儲存搜尋量資訊**
   - 自動記錄關鍵字來源地區和排名

2. **Bing 搜尋自動化**：針對抓取到的前 20 個關鍵字，在 Bing 上進行搜尋並擷取摘要
   - 每個關鍵字之間間隔 30-90 秒
   - 完成所有搜尋後休息 2-5 分鐘

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

## 資料庫設定

### 步驟 1: 執行資料庫更新腳本

**重要**：執行以下 SQL 腳本以更新資料庫結構：

```bash
# 在 SQL Server Management Studio 中執行
database_update.sql
```

此腳本會：
- 為 KeywordsMaster 表新增 `SearchVolume`、`Region`、`TrendRank` 欄位
- 更新觸發器以支援新欄位
- 建立索引以提升查詢效能
- 建立實用的視圖和預存程序

### 資料表結構

#### KeywordsMaster（關鍵字主檔）
- `KeywordID` (INT, PRIMARY KEY) - 由觸發器自動管理
- `Keyword` (NVARCHAR(200)) - 關鍵字文字
- `Category` (NVARCHAR(50)) - 分類（例如：'Google Trends'）
- `SearchIntent` (NVARCHAR(50)) - 搜尋意圖（例如：'Trending'）
- **`SearchVolume` (NVARCHAR(100))** - **搜尋量（新增）**
- **`Region` (NVARCHAR(10))** - **地區代碼（新增，例如：'US', 'TW'）**
- **`TrendRank` (INT)** - **該地區的排名 1-20（新增）**
- `CreatedAt` (DATETIME) - 建立時間

#### KeywordsLog（搜尋記錄）
- `LogID` (INT, PRIMARY KEY) - 由觸發器自動管理
- `KeywordID` (INT, NOT NULL) - 關鍵字 ID（外鍵）
- `LogDate` (DATE) - 記錄日期
- `CrawlTime` (DATETIME) - 爬取時間
- `SummaryText` (NVARCHAR(MAX)) - 搜尋結果摘要
- `Status` (NVARCHAR(50)) - 狀態（'Success' 或 'Fail'）
- `ScreenshotPath` (NVARCHAR(500)) - 截圖路徑（選用）
- `ErrorMessage` (NVARCHAR(1000)) - 錯誤訊息
- `CreatedAt` (DATETIME) - 建立時間

## 安裝步驟

### 1. 下載 Microsoft Edge WebDriver

1. 開啟 Edge 並檢查版本：
   - 網址列輸入：`edge://settings/help`
   - 記下版本號（例如：120.0.2210.144）

2. 下載對應版本：
   - 前往：https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/
   - 下載與您 Edge 版本相符的 WebDriver
   - 解壓縮 `msedgedriver.exe`

3. 建立目錄並放置檔案：
   ```cmd
   mkdir C:\自動化
   ```
   將 `msedgedriver.exe` 複製到 `C:\自動化\`

### 2. 安裝 Python 套件

```bash
cd automation
pip install -r requirements.txt
```

### 3. 執行資料庫更新

在 SQL Server Management Studio 中執行 `database_update.sql`

## 使用方式

### 基本執行
```bash
python google_trends_automation.py
```

### 測試模式（不寫入資料庫）
```bash
python google_trends_automation.py --dry-run
```

### 跳過特定步驟
```bash
# 跳過 Google Trends 抓取
python google_trends_automation.py --skip-trends

# 跳過 Bing 搜尋
python google_trends_automation.py --skip-search
```

## 設定說明

編輯 `google_trends_automation.py` 檔案中的設定區：

```python
# 每個地區抓取的關鍵字數量（現在是 20）
KEYWORDS_PER_REGION = 20

# 從所有地區總共選取前 N 名進行搜尋
TOP_N = 20

# 搜尋間隔（秒）
PER_KEYWORD_MIN = 30
PER_KEYWORD_MAX = 90
```

## 日誌檔案

腳本會在執行目錄產生 `google_trends_automation.log` 日誌檔案。

範例日誌內容：
```
2026-02-16 10:00:00 - INFO - === 步驟 1: 抓取 Google Trends 熱門關鍵字 ===
2026-02-16 10:00:05 - INFO - 發現關鍵字 (US) #1: Example Keyword (搜尋量: 100K+)
2026-02-16 10:00:07 - INFO - 從 US 成功抓取 20 個關鍵字
...
2026-02-16 10:05:00 - INFO - === 步驟 2: 在 Bing 搜尋前 20 個關鍵字 ===
2026-02-16 10:05:00 - INFO - [1/20] 搜尋關鍵字: Example (地區:US, 排名:#1, 搜尋量:100K+)
```

## 實用查詢範例

### 查看今日所有關鍵字
```sql
SELECT * FROM vw_TodayKeywords ORDER BY Region, TrendRank;
```

### 查看特定地區的 Top 20 關鍵字
```sql
EXEC sp_GetTopKeywordsByRegion @Region = 'US', @TopN = 20;
```

### 查看各地區統計
```sql
EXEC sp_GetSearchStats @DaysBack = 7;
```

### 查詢各地區關鍵字搜尋量分布
```sql
SELECT 
    Region AS 地區,
    COUNT(*) AS 關鍵字數量,
    AVG(TrendRank) AS 平均排名
FROM KeywordsMaster
WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY Region
ORDER BY 關鍵字數量 DESC;
```

## Windows Task Scheduler 設定

1. 開啟「工作排程器」
2. 建立基本工作：
   - 名稱：Google Trends 每日自動化
   - 觸發程序：每日 09:00
   - 動作：啟動程式
     - 程式：`C:\Python3\python.exe`
     - 引數：`"C:\automation\google_trends_automation.py"`
     - 開始位置：`C:\automation\`

## 疑難排解

### WebDriver 無法啟動
- 確認 msedgedriver.exe 路徑正確
- 確認 WebDriver 版本與 Edge 版本相符

### 資料庫連線失敗
- 確認 SQL Server 服務正在運行
- 確認 ODBC Driver 17 已安裝
- 確認使用者有資料庫存取權限

### 無法抓取搜尋量
- 搜尋量欄位可能顯示 'N/A'（正常，部分關鍵字可能無搜尋量資料）
- 查看截圖檔案以診斷問題

## 版本資訊

- **版本**: 2.0.0
- **更新日期**: 2026-02-16
- **主要變更**: 
  - 移除 Microsoft Rewards 功能
  - 新增搜尋量抓取
  - 增加每地區關鍵字數量至 20 個
  - 新增 Region 和 TrendRank 欄位

## 從 1.x 版本升級

如果您正在使用舊版本：

1. 備份現有腳本和資料庫
2. 執行 `database_update.sql` 更新資料庫結構
3. 使用新的 `google_trends_automation.py`
4. 測試執行：`python google_trends_automation.py --dry-run`

**注意**: 舊的 DailyPointsLog 資料不會被刪除，但新腳本不再使用該表。
