-- ==========================================
-- Google Trends 自動化 - 資料庫結構更新
-- ==========================================
-- 此檔案包含新的資料庫結構，用於儲存 Google Trends 關鍵字及搜尋量

USE MicrosoftRDB;
GO

-- ==========================================
-- 步驟 1: 修改 KeywordsMaster 表（如果已存在）
-- ==========================================

-- 檢查表是否存在，如果存在則新增欄位
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND type in (N'U'))
BEGIN
    -- 新增 SearchVolume 欄位（如果不存在）
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND name = 'SearchVolume')
    BEGIN
        ALTER TABLE KeywordsMaster ADD SearchVolume NVARCHAR(100) NULL;
        PRINT '已新增 SearchVolume 欄位到 KeywordsMaster';
    END

    -- 新增 Region 欄位（如果不存在）
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND name = 'Region')
    BEGIN
        ALTER TABLE KeywordsMaster ADD Region NVARCHAR(10) NULL;
        PRINT '已新增 Region 欄位到 KeywordsMaster';
    END

    -- 新增 TrendRank 欄位（如果不存在）
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND name = 'TrendRank')
    BEGIN
        ALTER TABLE KeywordsMaster ADD TrendRank INT NULL;
        PRINT '已新增 TrendRank 欄位到 KeywordsMaster';
    END
END
ELSE
BEGIN
    -- 如果表不存在，建立完整的表
    CREATE TABLE KeywordsMaster (
        KeywordID INT PRIMARY KEY,  -- 由觸發器自動管理
        Keyword NVARCHAR(200) NOT NULL,
        Category NVARCHAR(50),
        SearchIntent NVARCHAR(50),
        SearchVolume NVARCHAR(100),  -- 搜尋量（例如：'100K+', '1M+'）
        Region NVARCHAR(10),          -- 地區代碼（例如：'US', 'TW'）
        TrendRank INT,                -- 該地區的排名（1-20）
        CreatedAt DATETIME DEFAULT GETDATE(),
        CONSTRAINT UQ_Keyword_Region UNIQUE (Keyword, Region)  -- 同一關鍵字在不同地區可以重複
    );
    PRINT 'KeywordsMaster 表已建立';
END
GO

-- ==========================================
-- 步驟 2: 更新或建立 KeywordsLog 表
-- ==========================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'KeywordsLog') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsLog (
        LogID INT PRIMARY KEY,  -- 由觸發器自動管理
        KeywordID INT NOT NULL,
        LogDate DATE NOT NULL,
        CrawlTime DATETIME NOT NULL,
        SummaryText NVARCHAR(MAX),
        Status NVARCHAR(50),  -- 'Success', 'Fail' 等
        ScreenshotPath NVARCHAR(500),
        ErrorMessage NVARCHAR(1000),
        CreatedAt DATETIME DEFAULT GETDATE(),
        CONSTRAINT FK_KeywordsLog_Master FOREIGN KEY (KeywordID) REFERENCES KeywordsMaster(KeywordID)
    );
    PRINT 'KeywordsLog 表已建立';
END
GO

-- ==========================================
-- 步驟 3: 更新 KeywordsMaster 觸發器
-- ==========================================

-- 先刪除舊的觸發器（如果存在）
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsMaster_Insert')
BEGIN
    DROP TRIGGER trg_KeywordsMaster_Insert;
    PRINT '舊的 trg_KeywordsMaster_Insert 觸發器已刪除';
END
GO

-- 建立新的觸發器，支援新欄位
CREATE TRIGGER trg_KeywordsMaster_Insert
ON KeywordsMaster
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    -- 先鎖定表並取得目前最大值
    SELECT @MaxID = ISNULL(MAX(KeywordID), 0) FROM KeywordsMaster WITH (TABLOCKX);
    
    -- 插入新資料，ID 逐筆遞增
    INSERT INTO KeywordsMaster (KeywordID, Keyword, Category, SearchIntent, SearchVolume, Region, TrendRank, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.Keyword,
        inserted.Category,
        inserted.SearchIntent,
        inserted.SearchVolume,
        inserted.Region,
        inserted.TrendRank,
        ISNULL(inserted.CreatedAt, GETDATE())
    FROM inserted;
END;
GO

PRINT '新的 trg_KeywordsMaster_Insert 觸發器已建立';
GO

-- ==========================================
-- 步驟 4: 更新 KeywordsLog 觸發器（如果不存在）
-- ==========================================

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsLog_Insert')
BEGIN
    CREATE TRIGGER trg_KeywordsLog_Insert
    ON KeywordsLog
    INSTEAD OF INSERT
    AS
    BEGIN
        DECLARE @MaxID INT = 0;
        
        SELECT @MaxID = ISNULL(MAX(LogID), 0) FROM KeywordsLog WITH (TABLOCKX);
        
        INSERT INTO KeywordsLog (LogID, KeywordID, LogDate, CrawlTime, SummaryText, Status, ScreenshotPath, ErrorMessage, CreatedAt)
        SELECT 
            @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            inserted.KeywordID,
            inserted.LogDate,
            inserted.CrawlTime,
            inserted.SummaryText,
            inserted.Status,
            inserted.ScreenshotPath,
            inserted.ErrorMessage,
            ISNULL(inserted.CreatedAt, GETDATE())
        FROM inserted;
    END;
    PRINT 'trg_KeywordsLog_Insert 觸發器已建立';
END
GO

-- ==========================================
-- 步驟 5: 建立索引以提升查詢效能
-- ==========================================

-- KeywordsMaster 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_Region' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_Region ON KeywordsMaster(Region);
    PRINT '索引 IX_KeywordsMaster_Region 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_TrendRank' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_TrendRank ON KeywordsMaster(TrendRank);
    PRINT '索引 IX_KeywordsMaster_TrendRank 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_CreatedAt' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_CreatedAt ON KeywordsMaster(CreatedAt DESC);
    PRINT '索引 IX_KeywordsMaster_CreatedAt 已建立';
END

-- KeywordsLog 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_LogDate' AND object_id = OBJECT_ID('KeywordsLog'))
BEGIN
    CREATE INDEX IX_KeywordsLog_LogDate ON KeywordsLog(LogDate DESC);
    PRINT '索引 IX_KeywordsLog_LogDate 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_KeywordID' AND object_id = OBJECT_ID('KeywordsLog'))
BEGIN
    CREATE INDEX IX_KeywordsLog_KeywordID ON KeywordsLog(KeywordID);
    PRINT '索引 IX_KeywordsLog_KeywordID 已建立';
END
GO

-- ==========================================
-- 步驟 6: 建立實用的查詢視圖
-- ==========================================

-- 今日關鍵字視圖
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodayKeywords')
BEGIN
    DROP VIEW vw_TodayKeywords;
END
GO

CREATE VIEW vw_TodayKeywords AS
SELECT 
    km.KeywordID,
    km.Keyword,
    km.Category,
    km.SearchVolume,
    km.Region,
    km.TrendRank,
    km.CreatedAt
FROM KeywordsMaster km
WHERE CAST(km.CreatedAt AS DATE) = CAST(GETDATE() AS DATE);
GO

PRINT 'VIEW vw_TodayKeywords 已建立';
GO

-- 今日搜尋記錄視圖
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodaySearches')
BEGIN
    DROP VIEW vw_TodaySearches;
END
GO

CREATE VIEW vw_TodaySearches AS
SELECT 
    kl.LogID,
    km.Keyword,
    km.Region,
    km.SearchVolume,
    kl.Status,
    kl.CrawlTime,
    LEFT(kl.SummaryText, 200) AS SummaryPreview,
    kl.ErrorMessage
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE);
GO

PRINT 'VIEW vw_TodaySearches 已建立';
GO

-- ==========================================
-- 步驟 7: 建立實用的查詢預存程序
-- ==========================================

-- 取得各地區 Top 20 關鍵字
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'sp_GetTopKeywordsByRegion') AND type in (N'P'))
BEGIN
    DROP PROCEDURE sp_GetTopKeywordsByRegion;
END
GO

CREATE PROCEDURE sp_GetTopKeywordsByRegion
    @Region NVARCHAR(10) = NULL,  -- 不指定則顯示所有地區
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        KeywordID,
        Keyword,
        Region,
        TrendRank,
        SearchVolume,
        Category,
        CreatedAt
    FROM KeywordsMaster
    WHERE (@Region IS NULL OR Region = @Region)
    ORDER BY 
        Region,
        TrendRank;
END
GO

PRINT 'sp_GetTopKeywordsByRegion 預存程序已建立';
GO

-- 取得搜尋統計
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'sp_GetSearchStats') AND type in (N'P'))
BEGIN
    DROP PROCEDURE sp_GetSearchStats;
END
GO

CREATE PROCEDURE sp_GetSearchStats
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        Region AS 地區,
        COUNT(DISTINCT km.KeywordID) AS 關鍵字總數,
        COUNT(kl.LogID) AS 搜尋次數,
        SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS 成功次數,
        SUM(CASE WHEN kl.Status = 'Fail' THEN 1 ELSE 0 END) AS 失敗次數,
        MAX(kl.CrawlTime) AS 最後搜尋時間
    FROM KeywordsMaster km
    LEFT JOIN KeywordsLog kl ON km.KeywordID = kl.KeywordID
        AND kl.LogDate >= DATEADD(DAY, -@DaysBack, CAST(GETDATE() AS DATE))
    WHERE km.CreatedAt >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY Region
    ORDER BY 關鍵字總數 DESC;
END
GO

PRINT 'sp_GetSearchStats 預存程序已建立';
GO

-- ==========================================
-- 完成訊息
-- ==========================================

PRINT '';
PRINT '==========================================';
PRINT '資料庫更新完成！';
PRINT '==========================================';
PRINT '';
PRINT '已完成的變更：';
PRINT '1. KeywordsMaster 表已更新，新增欄位：';
PRINT '   - SearchVolume (搜尋量)';
PRINT '   - Region (地區代碼)';
PRINT '   - TrendRank (排名)';
PRINT '2. 觸發器已更新以支援新欄位';
PRINT '3. 索引已建立以提升查詢效能';
PRINT '4. 視圖和預存程序已建立';
PRINT '';
PRINT '實用查詢範例：';
PRINT '  - SELECT * FROM vw_TodayKeywords ORDER BY Region, TrendRank;';
PRINT '  - EXEC sp_GetTopKeywordsByRegion @Region = ''US'', @TopN = 20;';
PRINT '  - EXEC sp_GetSearchStats @DaysBack = 7;';
PRINT '';
GO
