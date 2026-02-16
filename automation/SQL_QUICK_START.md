# SQL 快速入門指南

## 📋 資料庫建立步驟

### 步驟 1: 開啟 SQL Server Management Studio (SSMS)

1. 啟動 SSMS
2. 連接到您的 SQL Server 實例（通常是 `localhost`）

### 步驟 2: 執行資料庫建立腳本

#### 選項 A：新用戶（全新安裝）

執行完整建立腳本：

```sql
-- 1. 確保使用正確的資料庫
USE MicrosoftRDB;
GO

-- 2. 執行完整腳本
-- 方法 1：在 SSMS 中開啟檔案並執行
-- 檔案 → 開啟 → 檔案 → 選擇 database_setup_complete_v2.sql
-- 按 F5 執行

-- 方法 2：使用 SQLCMD（命令列）
-- sqlcmd -S localhost -d MicrosoftRDB -E -i database_setup_complete_v2.sql
```

**檔案位置**：`automation/database_setup_complete_v2.sql`

**包含內容**：
- ✅ 2 個表（KeywordsMaster, KeywordsLog）
- ✅ 2 個觸發器（自動管理 ID）
- ✅ 5 個索引（提升效能）
- ✅ 2 個視圖（方便查詢）
- ✅ 2 個預存程序（常用功能）

#### 選項 B：從 v1 升級的用戶

執行升級腳本：

```sql
USE MicrosoftRDB;
GO

-- 執行升級腳本（新增 SearchVolume, Region, TrendRank 欄位）
-- 檔案位置：automation/database_update.sql
```

---

## 📊 資料表結構

### KeywordsMaster（關鍵字主表）

```sql
CREATE TABLE KeywordsMaster (
    KeywordID INT PRIMARY KEY,              -- 關鍵字 ID（Python 管理）
    Keyword NVARCHAR(200) NOT NULL,         -- 關鍵字文字
    SearchVolume NVARCHAR(100),             -- 搜尋量（如：100K+, 1M+）
    Region NVARCHAR(10),                    -- 地區代碼（US, TW, JP, etc.）
    TrendRank INT,                          -- 該地區的排名（1-20）
    Category NVARCHAR(50),                  -- 分類
    SearchIntent NVARCHAR(50),              -- 搜尋意圖
    CreatedAt DATETIME DEFAULT GETDATE(),   -- 建立時間
    
    CONSTRAINT UQ_Keyword_Region UNIQUE (Keyword, Region)
);
```

### KeywordsLog（搜尋記錄表）

```sql
CREATE TABLE KeywordsLog (
    LogID INT PRIMARY KEY,                  -- 日誌 ID（Python 管理）
    KeywordID INT NOT NULL,                 -- 外鍵到 KeywordsMaster
    LogDate DATE NOT NULL,                  -- 記錄日期
    CrawlTime DATETIME NOT NULL,            -- 爬取時間
    SummaryText NVARCHAR(MAX),              -- 搜尋結果摘要
    Status NVARCHAR(50),                    -- 狀態（Success, Fail）
    ErrorMessage NVARCHAR(1000),            -- 錯誤訊息
    CreatedAt DATETIME DEFAULT GETDATE(),   -- 建立時間
    
    CONSTRAINT FK_KeywordsLog_Master 
        FOREIGN KEY (KeywordID) REFERENCES KeywordsMaster(KeywordID)
);
```

---

## 🔍 常用 SQL 查詢

### 1. 查看今日抓取的所有關鍵字

```sql
-- 使用視圖
SELECT * FROM vw_TodayKeywords 
ORDER BY Region, TrendRank;

-- 或直接查詢
SELECT 
    KeywordID,
    Keyword,
    SearchVolume,
    Region,
    TrendRank,
    CreatedAt
FROM KeywordsMaster
WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY Region, TrendRank;
```

### 2. 查看特定地區的前 20 個關鍵字

```sql
-- 使用預存程序（推薦）
EXEC sp_GetTopKeywordsByRegion @Region = 'US', @TopN = 20;

-- 美國
EXEC sp_GetTopKeywordsByRegion @Region = 'US', @TopN = 20;

-- 台灣
EXEC sp_GetTopKeywordsByRegion @Region = 'TW', @TopN = 20;

-- 日本
EXEC sp_GetTopKeywordsByRegion @Region = 'JP', @TopN = 20;
```

### 3. 查看今日搜尋記錄

```sql
-- 使用視圖
SELECT * FROM vw_TodaySearches
ORDER BY CrawlTime DESC;

-- 或直接查詢
SELECT 
    kl.LogID,
    km.Keyword,
    km.Region,
    kl.Status,
    kl.CrawlTime,
    LEFT(kl.SummaryText, 200) AS SummaryPreview
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;
```

### 4. 統計各地區的關鍵字數量

```sql
SELECT 
    Region AS 地區,
    COUNT(*) AS 關鍵字數量,
    COUNT(DISTINCT CASE WHEN SearchVolume IS NOT NULL THEN Keyword END) AS 有搜尋量的數量
FROM KeywordsMaster
WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY Region
ORDER BY 關鍵字數量 DESC;
```

### 5. 查看搜尋統計

```sql
-- 今日統計
EXEC sp_GetSearchStats;

-- 指定日期範圍
EXEC sp_GetSearchStats 
    @StartDate = '2026-02-01', 
    @EndDate = '2026-02-16';
```

### 6. 查詢最熱門的關鍵字（跨地區）

```sql
SELECT 
    Keyword,
    COUNT(DISTINCT Region) AS 出現地區數,
    STRING_AGG(Region, ', ') AS 出現地區,
    MIN(TrendRank) AS 最高排名
FROM KeywordsMaster
WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY Keyword
HAVING COUNT(DISTINCT Region) > 1  -- 出現在多個地區
ORDER BY 出現地區數 DESC, 最高排名 ASC;
```

### 7. 查詢搜尋失敗的關鍵字

```sql
SELECT 
    km.Keyword,
    km.Region,
    kl.ErrorMessage,
    kl.CrawlTime
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.Status = 'Fail'
    AND kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;
```

### 8. 查詢特定關鍵字的詳細資訊

```sql
DECLARE @SearchKeyword NVARCHAR(200) = 'Taylor Swift';

-- 關鍵字基本資訊
SELECT * FROM KeywordsMaster
WHERE Keyword LIKE '%' + @SearchKeyword + '%';

-- 該關鍵字的搜尋記錄
SELECT 
    kl.*,
    km.Keyword,
    km.Region
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE km.Keyword LIKE '%' + @SearchKeyword + '%'
ORDER BY kl.CrawlTime DESC;
```

---

## 🛠️ 資料維護

### 刪除舊資料（保留最近 30 天）

```sql
-- 刪除 30 天前的搜尋記錄
DELETE FROM KeywordsLog
WHERE LogDate < DATEADD(DAY, -30, GETDATE());

-- 刪除沒有搜尋記錄的舊關鍵字
DELETE km
FROM KeywordsMaster km
LEFT JOIN KeywordsLog kl ON km.KeywordID = kl.KeywordID
WHERE kl.LogID IS NULL
    AND km.CreatedAt < DATEADD(DAY, -30, GETDATE());
```

### 查看資料庫使用統計

```sql
-- 查看表的記錄數
SELECT 
    'KeywordsMaster' AS TableName,
    COUNT(*) AS RecordCount
FROM KeywordsMaster
UNION ALL
SELECT 
    'KeywordsLog',
    COUNT(*)
FROM KeywordsLog;

-- 查看最新和最舊的記錄
SELECT 
    'KeywordsMaster - 最新' AS Info,
    MAX(CreatedAt) AS DateTime
FROM KeywordsMaster
UNION ALL
SELECT 
    'KeywordsMaster - 最舊',
    MIN(CreatedAt)
FROM KeywordsMaster
UNION ALL
SELECT 
    'KeywordsLog - 最新',
    MAX(CrawlTime)
FROM KeywordsLog
UNION ALL
SELECT 
    'KeywordsLog - 最舊',
    MIN(CrawlTime)
FROM KeywordsLog;
```

---

## 🔐 權限設定

如果需要給其他用戶授權：

```sql
-- 授予讀取權限
GRANT SELECT ON KeywordsMaster TO [YourUsername];
GRANT SELECT ON KeywordsLog TO [YourUsername];
GRANT SELECT ON vw_TodayKeywords TO [YourUsername];
GRANT SELECT ON vw_TodaySearches TO [YourUsername];

-- 授予執行預存程序權限
GRANT EXECUTE ON sp_GetTopKeywordsByRegion TO [YourUsername];
GRANT EXECUTE ON sp_GetSearchStats TO [YourUsername];

-- 授予完整權限（包括寫入）
GRANT SELECT, INSERT, UPDATE, DELETE ON KeywordsMaster TO [YourUsername];
GRANT SELECT, INSERT, UPDATE, DELETE ON KeywordsLog TO [YourUsername];
```

---

## 📝 驗證安裝

執行以下查詢確認一切正常：

```sql
-- 檢查表是否存在
SELECT 
    name AS TableName,
    create_date AS CreateDate
FROM sys.tables
WHERE name IN ('KeywordsMaster', 'KeywordsLog')
ORDER BY name;

-- 檢查觸發器
SELECT 
    t.name AS TriggerName,
    OBJECT_NAME(t.parent_id) AS TableName
FROM sys.triggers t
WHERE t.name IN ('trg_KeywordsMaster_Insert', 'trg_KeywordsLog_Insert');

-- 檢查視圖
SELECT name AS ViewName
FROM sys.views
WHERE name IN ('vw_TodayKeywords', 'vw_TodaySearches');

-- 檢查預存程序
SELECT name AS ProcedureName
FROM sys.procedures
WHERE name IN ('sp_GetTopKeywordsByRegion', 'sp_GetSearchStats');

-- 測試插入一筆資料（會自動分配 ID）
BEGIN TRANSACTION;

    INSERT INTO KeywordsMaster (KeywordID, Keyword, Region, TrendRank)
    VALUES (0, 'Test Keyword', 'US', 1);  -- ID 會由觸發器自動設定
    
    SELECT TOP 1 * FROM KeywordsMaster ORDER BY KeywordID DESC;

ROLLBACK TRANSACTION;  -- 回復測試資料
```

---

## ❓ 常見問題

### Q1: 執行腳本時出現「資料庫不存在」錯誤？

**解決方法**：先建立資料庫

```sql
CREATE DATABASE MicrosoftRDB;
GO

USE MicrosoftRDB;
GO

-- 然後執行 database_setup_complete_v2.sql
```

### Q2: 如何重新建立所有物件？

**解決方法**：再次執行 `database_setup_complete_v2.sql`，腳本會自動：
1. 刪除所有既有物件
2. 重新建立所有物件

**注意**：這會刪除所有資料！如需保留資料，請先備份。

### Q3: Python 腳本無法連接資料庫？

**檢查清單**：
1. SQL Server 服務是否運行？
2. 資料庫名稱是否正確（MicrosoftRDB）？
3. 是否安裝 ODBC Driver 17 或 18？
4. Windows Authentication 是否有權限？

---

**建立日期**: 2026-02-16  
**適用版本**: V2 Google Trends Automation
