-- ============================================================================
-- Google Trends 自動化系統 - 完整資料庫建立腳本 (V2)
-- ============================================================================
-- 此腳本用於「新建」V2 版本的資料庫（包含搜尋量追蹤功能）
-- 建立日期: 2026-02-16
-- 
-- 功能：
-- 1. KeywordsMaster - 關鍵字主表（含搜尋量、地區、排名）
-- 2. KeywordsLog - 搜尋記錄表
-- 3. 自動觸發器（Python 端管理 ID，無 IDENTITY）
-- 4. 索引（提升查詢效能）
-- 5. 視圖（方便查詢）
-- 6. 預存程序（常用查詢）
-- ============================================================================

USE MicrosoftRDB;
GO

PRINT '============================================================================';
PRINT '開始建立 Google Trends 自動化系統資料庫物件 (V2)';
PRINT '============================================================================';
PRINT '';

-- ============================================================================
-- 1. 刪除既有物件（如果存在）
-- ============================================================================
PRINT '步驟 1: 清理既有物件...';

-- 刪除預存程序
IF OBJECT_ID('sp_GetTopKeywordsByRegion', 'P') IS NOT NULL
    DROP PROCEDURE sp_GetTopKeywordsByRegion;
IF OBJECT_ID('sp_GetSearchStats', 'P') IS NOT NULL
    DROP PROCEDURE sp_GetSearchStats;

-- 刪除視圖
IF OBJECT_ID('vw_TodayKeywords', 'V') IS NOT NULL
    DROP VIEW vw_TodayKeywords;
IF OBJECT_ID('vw_TodaySearches', 'V') IS NOT NULL
    DROP VIEW vw_TodaySearches;

-- 刪除索引（會在刪除表時自動刪除，這裡列出以供參考）
-- IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_Region')
--     DROP INDEX IX_KeywordsMaster_Region ON KeywordsMaster;

-- 刪除觸發器
IF OBJECT_ID('trg_KeywordsMaster_Insert', 'TR') IS NOT NULL
    DROP TRIGGER trg_KeywordsMaster_Insert;
IF OBJECT_ID('trg_KeywordsLog_Insert', 'TR') IS NOT NULL
    DROP TRIGGER trg_KeywordsLog_Insert;

-- 刪除表（注意順序：先刪除有外鍵的表）
IF OBJECT_ID('KeywordsLog', 'U') IS NOT NULL
    DROP TABLE KeywordsLog;
IF OBJECT_ID('KeywordsMaster', 'U') IS NOT NULL
    DROP TABLE KeywordsMaster;

PRINT '✓ 既有物件已清理';
PRINT '';

-- ============================================================================
-- 2. 建立 KeywordsMaster 表
-- ============================================================================
PRINT '步驟 2: 建立 KeywordsMaster 表...';

CREATE TABLE KeywordsMaster (
    KeywordID INT PRIMARY KEY,                  -- Python 管理，無 IDENTITY
    Keyword NVARCHAR(200) NOT NULL,             -- 關鍵字
    SearchVolume NVARCHAR(100) NULL,            -- 搜尋量（例如：100K+, 1M+）
    Region NVARCHAR(10) NULL,                   -- 地區代碼（US, TW, JP, etc.）
    TrendRank INT NULL,                         -- 該關鍵字在該地區的排名（1-20）
    Category NVARCHAR(50) NULL,                 -- 分類
    SearchIntent NVARCHAR(50) NULL,             -- 搜尋意圖
    CreatedAt DATETIME DEFAULT GETDATE(),       -- 建立時間
    
    -- 唯一約束：同一關鍵字在同一地區視為同一筆記錄
    CONSTRAINT UQ_Keyword_Region UNIQUE (Keyword, Region)
);

PRINT '✓ KeywordsMaster 表已建立';
PRINT '';

-- ============================================================================
-- 3. 建立 KeywordsLog 表
-- ============================================================================
PRINT '步驟 3: 建立 KeywordsLog 表...';

CREATE TABLE KeywordsLog (
    LogID INT PRIMARY KEY,                      -- Python 管理，無 IDENTITY
    KeywordID INT NOT NULL,                     -- 外鍵到 KeywordsMaster
    LogDate DATE NOT NULL,                      -- 記錄日期
    CrawlTime DATETIME NOT NULL,                -- 爬取時間
    SummaryText NVARCHAR(MAX) NULL,             -- 搜尋結果摘要
    Status NVARCHAR(50) NULL,                   -- 狀態（Success, Fail）
    ErrorMessage NVARCHAR(1000) NULL,           -- 錯誤訊息
    CreatedAt DATETIME DEFAULT GETDATE(),       -- 建立時間
    
    CONSTRAINT FK_KeywordsLog_Master 
        FOREIGN KEY (KeywordID) REFERENCES KeywordsMaster(KeywordID)
);

PRINT '✓ KeywordsLog 表已建立';
PRINT '';

-- ============================================================================
-- 4. 建立觸發器（Python 端管理 ID）
-- ============================================================================
PRINT '步驟 4: 建立觸發器...';

-- KeywordsMaster 觸發器
CREATE TRIGGER trg_KeywordsMaster_Insert
ON KeywordsMaster
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    -- 先鎖定表並取得目前最大值
    SELECT @MaxID = ISNULL(MAX(KeywordID), 0) FROM KeywordsMaster WITH (TABLOCKX);
    
    -- 插入新資料，ID 逐筆遞增
    INSERT INTO KeywordsMaster (KeywordID, Keyword, SearchVolume, Region, TrendRank, Category, SearchIntent, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.Keyword,
        inserted.SearchVolume,
        inserted.Region,
        inserted.TrendRank,
        inserted.Category,
        inserted.SearchIntent,
        inserted.CreatedAt
    FROM inserted;
END;
GO

PRINT '✓ trg_KeywordsMaster_Insert 觸發器已建立';

-- KeywordsLog 觸發器
CREATE TRIGGER trg_KeywordsLog_Insert
ON KeywordsLog
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    -- 先鎖定表並取得目前最大值
    SELECT @MaxID = ISNULL(MAX(LogID), 0) FROM KeywordsLog WITH (TABLOCKX);
    
    -- 插入新資料，ID 逐筆遞增
    INSERT INTO KeywordsLog (LogID, KeywordID, LogDate, CrawlTime, SummaryText, Status, ErrorMessage, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.KeywordID,
        inserted.LogDate,
        inserted.CrawlTime,
        inserted.SummaryText,
        inserted.Status,
        inserted.ErrorMessage,
        inserted.CreatedAt
    FROM inserted;
END;
GO

PRINT '✓ trg_KeywordsLog_Insert 觸發器已建立';
PRINT '';

-- ============================================================================
-- 5. 建立索引（提升查詢效能）
-- ============================================================================
PRINT '步驟 5: 建立索引...';

-- KeywordsMaster 索引
CREATE INDEX IX_KeywordsMaster_Region 
    ON KeywordsMaster(Region);
    
CREATE INDEX IX_KeywordsMaster_TrendRank 
    ON KeywordsMaster(TrendRank);
    
CREATE INDEX IX_KeywordsMaster_CreatedAt 
    ON KeywordsMaster(CreatedAt);

-- KeywordsLog 索引
CREATE INDEX IX_KeywordsLog_LogDate 
    ON KeywordsLog(LogDate);
    
CREATE INDEX IX_KeywordsLog_KeywordID 
    ON KeywordsLog(KeywordID);

PRINT '✓ 所有索引已建立';
PRINT '';

-- ============================================================================
-- 6. 建立視圖（方便查詢）
-- ============================================================================
PRINT '步驟 6: 建立視圖...';

-- 視圖 1: 今日抓取的關鍵字
CREATE VIEW vw_TodayKeywords AS
SELECT 
    km.KeywordID,
    km.Keyword,
    km.SearchVolume,
    km.Region,
    km.TrendRank,
    km.Category,
    km.CreatedAt
FROM KeywordsMaster km
WHERE CAST(km.CreatedAt AS DATE) = CAST(GETDATE() AS DATE);
GO

PRINT '✓ vw_TodayKeywords 視圖已建立';

-- 視圖 2: 今日的搜尋記錄
CREATE VIEW vw_TodaySearches AS
SELECT 
    kl.LogID,
    km.Keyword,
    km.Region,
    kl.LogDate,
    kl.CrawlTime,
    kl.Status,
    LEFT(kl.SummaryText, 200) AS SummaryPreview,
    kl.ErrorMessage
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE);
GO

PRINT '✓ vw_TodaySearches 視圖已建立';
PRINT '';

-- ============================================================================
-- 7. 建立預存程序
-- ============================================================================
PRINT '步驟 7: 建立預存程序...';

-- 預存程序 1: 取得指定地區的前 N 個關鍵字
CREATE PROCEDURE sp_GetTopKeywordsByRegion
    @Region NVARCHAR(10),
    @TopN INT = 20
AS
BEGIN
    SELECT TOP (@TopN)
        KeywordID,
        Keyword,
        SearchVolume,
        Region,
        TrendRank,
        Category,
        CreatedAt
    FROM KeywordsMaster
    WHERE Region = @Region
    ORDER BY TrendRank ASC, CreatedAt DESC;
END;
GO

PRINT '✓ sp_GetTopKeywordsByRegion 預存程序已建立';

-- 預存程序 2: 取得搜尋統計
CREATE PROCEDURE sp_GetSearchStats
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    -- 預設為今天
    IF @StartDate IS NULL
        SET @StartDate = CAST(GETDATE() AS DATE);
    IF @EndDate IS NULL
        SET @EndDate = CAST(GETDATE() AS DATE);
    
    SELECT 
        km.Region,
        COUNT(DISTINCT km.KeywordID) AS TotalKeywords,
        COUNT(kl.LogID) AS TotalSearches,
        SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS SuccessfulSearches,
        SUM(CASE WHEN kl.Status = 'Fail' THEN 1 ELSE 0 END) AS FailedSearches
    FROM KeywordsMaster km
    LEFT JOIN KeywordsLog kl ON km.KeywordID = kl.KeywordID 
        AND kl.LogDate BETWEEN @StartDate AND @EndDate
    WHERE CAST(km.CreatedAt AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY km.Region
    ORDER BY TotalKeywords DESC;
END;
GO

PRINT '✓ sp_GetSearchStats 預存程序已建立';
PRINT '';

-- ============================================================================
-- 8. 驗證建立結果
-- ============================================================================
PRINT '步驟 8: 驗證建立結果...';
PRINT '';

-- 檢查表
PRINT '已建立的表:';
SELECT 
    name AS TableName,
    create_date AS CreateDate
FROM sys.tables
WHERE name IN ('KeywordsMaster', 'KeywordsLog')
ORDER BY name;

-- 檢查觸發器
PRINT '';
PRINT '已建立的觸發器:';
SELECT 
    t.name AS TriggerName,
    OBJECT_NAME(t.parent_id) AS TableName
FROM sys.triggers t
WHERE t.name IN ('trg_KeywordsMaster_Insert', 'trg_KeywordsLog_Insert')
ORDER BY t.name;

-- 檢查索引
PRINT '';
PRINT '已建立的索引:';
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
WHERE OBJECT_NAME(i.object_id) IN ('KeywordsMaster', 'KeywordsLog')
    AND i.name IS NOT NULL
ORDER BY TableName, IndexName;

-- 檢查視圖
PRINT '';
PRINT '已建立的視圖:';
SELECT 
    name AS ViewName,
    create_date AS CreateDate
FROM sys.views
WHERE name IN ('vw_TodayKeywords', 'vw_TodaySearches')
ORDER BY name;

-- 檢查預存程序
PRINT '';
PRINT '已建立的預存程序:';
SELECT 
    name AS ProcedureName,
    create_date AS CreateDate
FROM sys.procedures
WHERE name IN ('sp_GetTopKeywordsByRegion', 'sp_GetSearchStats')
ORDER BY name;

PRINT '';
PRINT '============================================================================';
PRINT '✓ Google Trends 自動化系統資料庫物件建立完成！';
PRINT '============================================================================';
PRINT '';
PRINT '已建立的物件：';
PRINT '  • 2 個表 (KeywordsMaster, KeywordsLog)';
PRINT '  • 2 個觸發器 (自動管理 ID)';
PRINT '  • 5 個索引 (提升查詢效能)';
PRINT '  • 2 個視圖 (vw_TodayKeywords, vw_TodaySearches)';
PRINT '  • 2 個預存程序 (sp_GetTopKeywordsByRegion, sp_GetSearchStats)';
PRINT '';
PRINT '使用範例：';
PRINT '  -- 查詢今日抓取的關鍵字';
PRINT '  SELECT * FROM vw_TodayKeywords ORDER BY Region, TrendRank;';
PRINT '';
PRINT '  -- 查詢美國地區前 20 個關鍵字';
PRINT '  EXEC sp_GetTopKeywordsByRegion @Region = ''US'', @TopN = 20;';
PRINT '';
PRINT '  -- 查詢今日搜尋統計';
PRINT '  EXEC sp_GetSearchStats;';
PRINT '';
PRINT '============================================================================';
GO
