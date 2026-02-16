-- ==========================================
-- Google Trends 自動化 v2.0 - 完整資料庫建立腳本
-- ==========================================
-- 此腳本用於「新建」資料庫時使用
-- 包含所有必要的表、觸發器、索引、視圖和預存程序
--
-- 執行環境：SQL Server
-- 資料庫：MicrosoftRDB（或您指定的資料庫名稱）
-- ==========================================

USE MicrosoftRDB;
GO

-- ==========================================
-- 步驟 1: 建立資料表
-- ==========================================

PRINT '===========================================';
PRINT '步驟 1: 建立資料表';
PRINT '===========================================';
PRINT '';

-- ==================== KeywordsMaster ====================
-- 儲存所有爬到的關鍵字
PRINT '建立 KeywordsMaster 表...';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsMaster (
        KeywordID INT PRIMARY KEY,          -- 由觸發器自動管理
        Keyword NVARCHAR(200) NOT NULL,      -- 關鍵字文字
        Category NVARCHAR(50),               -- 分類（例如：'Google Trends'）
        SearchIntent NVARCHAR(50),           -- 搜尋意圖（例如：'Trending'）
        SearchVolume NVARCHAR(100),          -- 搜尋量（例如：'100K+', '1M+', 'N/A'）
        Region NVARCHAR(10),                 -- 地區代碼（例如：'US', 'TW', 'JP'）
        TrendRank INT,                       -- 該地區的排名（1-20）
        CreatedAt DATETIME DEFAULT GETDATE(), -- 建立時間
        CONSTRAINT UQ_Keyword_Region UNIQUE (Keyword, Region)  -- 同一關鍵字在不同地區可以重複
    );
    
    PRINT '  ✓ KeywordsMaster 表已建立';
END
ELSE
BEGIN
    PRINT '  ! KeywordsMaster 表已存在，跳過建立';
END
GO

-- ==================== KeywordsLog ====================
-- 儲存每次對關鍵字的搜尋記錄
PRINT '建立 KeywordsLog 表...';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'KeywordsLog') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsLog (
        LogID INT PRIMARY KEY,              -- 由觸發器自動管理
        KeywordID INT NOT NULL,             -- 關鍵字 ID（外鍵）
        LogDate DATE NOT NULL,              -- 記錄日期
        CrawlTime DATETIME NOT NULL,        -- 爬取時間
        SummaryText NVARCHAR(MAX),          -- 搜尋結果摘要
        Status NVARCHAR(50),                -- 狀態（'Success', 'Fail'）
        ScreenshotPath NVARCHAR(500),       -- 截圖路徑（選用）
        ErrorMessage NVARCHAR(1000),        -- 錯誤訊息
        CreatedAt DATETIME DEFAULT GETDATE(), -- 建立時間
        CONSTRAINT FK_KeywordsLog_Master FOREIGN KEY (KeywordID) REFERENCES KeywordsMaster(KeywordID)
    );
    
    PRINT '  ✓ KeywordsLog 表已建立';
END
ELSE
BEGIN
    PRINT '  ! KeywordsLog 表已存在，跳過建立';
END
GO

PRINT '';

-- ==========================================
-- 步驟 2: 建立觸發器
-- ==========================================

PRINT '===========================================';
PRINT '步驟 2: 建立觸發器';
PRINT '===========================================';
PRINT '';

-- KeywordsMaster 觸發器
PRINT '建立 KeywordsMaster 觸發器...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsMaster_Insert')
BEGIN
    DROP TRIGGER trg_KeywordsMaster_Insert;
    PRINT '  ! 舊的觸發器已刪除';
END
GO

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

PRINT '  ✓ trg_KeywordsMaster_Insert 觸發器已建立';

-- KeywordsLog 觸發器
PRINT '建立 KeywordsLog 觸發器...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsLog_Insert')
BEGIN
    DROP TRIGGER trg_KeywordsLog_Insert;
    PRINT '  ! 舊的觸發器已刪除';
END
GO

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
GO

PRINT '  ✓ trg_KeywordsLog_Insert 觸發器已建立';
PRINT '';

-- ==========================================
-- 步驟 3: 建立索引
-- ==========================================

PRINT '===========================================';
PRINT '步驟 3: 建立索引（提升查詢效能）';
PRINT '===========================================';
PRINT '';

-- KeywordsMaster 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_Region' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_Region ON KeywordsMaster(Region);
    PRINT '  ✓ 索引 IX_KeywordsMaster_Region 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_TrendRank' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_TrendRank ON KeywordsMaster(TrendRank);
    PRINT '  ✓ 索引 IX_KeywordsMaster_TrendRank 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_CreatedAt' AND object_id = OBJECT_ID('KeywordsMaster'))
BEGIN
    CREATE INDEX IX_KeywordsMaster_CreatedAt ON KeywordsMaster(CreatedAt DESC);
    PRINT '  ✓ 索引 IX_KeywordsMaster_CreatedAt 已建立';
END

-- KeywordsLog 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_LogDate' AND object_id = OBJECT_ID('KeywordsLog'))
BEGIN
    CREATE INDEX IX_KeywordsLog_LogDate ON KeywordsLog(LogDate DESC);
    PRINT '  ✓ 索引 IX_KeywordsLog_LogDate 已建立';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_KeywordID' AND object_id = OBJECT_ID('KeywordsLog'))
BEGIN
    CREATE INDEX IX_KeywordsLog_KeywordID ON KeywordsLog(KeywordID);
    PRINT '  ✓ 索引 IX_KeywordsLog_KeywordID 已建立';
END

PRINT '';

-- ==========================================
-- 步驟 4: 建立視圖
-- ==========================================

PRINT '===========================================';
PRINT '步驟 4: 建立視圖';
PRINT '===========================================';
PRINT '';

-- 今日關鍵字視圖
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodayKeywords')
BEGIN
    DROP VIEW vw_TodayKeywords;
    PRINT '  ! 舊的 vw_TodayKeywords 視圖已刪除';
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

PRINT '  ✓ vw_TodayKeywords 視圖已建立';

-- 今日搜尋記錄視圖
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodaySearches')
BEGIN
    DROP VIEW vw_TodaySearches;
    PRINT '  ! 舊的 vw_TodaySearches 視圖已刪除';
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

PRINT '  ✓ vw_TodaySearches 視圖已建立';
PRINT '';

-- ==========================================
-- 步驟 5: 建立預存程序
-- ==========================================

PRINT '===========================================';
PRINT '步驟 5: 建立預存程序';
PRINT '===========================================';
PRINT '';

-- 取得各地區 Top 20 關鍵字
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'sp_GetTopKeywordsByRegion') AND type in (N'P'))
BEGIN
    DROP PROCEDURE sp_GetTopKeywordsByRegion;
    PRINT '  ! 舊的 sp_GetTopKeywordsByRegion 程序已刪除';
END
GO

CREATE PROCEDURE sp_GetTopKeywordsByRegion
    @Region NVARCHAR(10) = NULL,  -- 不指定則顯示所有地區
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Region IS NULL
    BEGIN
        -- 顯示所有地區，每個地區取 TopN
        SELECT 
            KeywordID,
            Keyword,
            Region,
            TrendRank,
            SearchVolume,
            Category,
            CreatedAt
        FROM (
            SELECT 
                KeywordID,
                Keyword,
                Region,
                TrendRank,
                SearchVolume,
                Category,
                CreatedAt,
                ROW_NUMBER() OVER (PARTITION BY Region ORDER BY TrendRank) AS RowNum
            FROM KeywordsMaster
            WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
        ) AS RankedKeywords
        WHERE RowNum <= @TopN
        ORDER BY Region, TrendRank;
    END
    ELSE
    BEGIN
        -- 只顯示指定地區的 TopN
        SELECT TOP (@TopN)
            KeywordID,
            Keyword,
            Region,
            TrendRank,
            SearchVolume,
            Category,
            CreatedAt
        FROM KeywordsMaster
        WHERE Region = @Region
            AND CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
        ORDER BY TrendRank;
    END
END
GO

PRINT '  ✓ sp_GetTopKeywordsByRegion 預存程序已建立';

-- 取得搜尋統計
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'sp_GetSearchStats') AND type in (N'P'))
BEGIN
    DROP PROCEDURE sp_GetSearchStats;
    PRINT '  ! 舊的 sp_GetSearchStats 程序已刪除';
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

PRINT '  ✓ sp_GetSearchStats 預存程序已建立';
PRINT '';

-- ==========================================
-- 完成訊息
-- ==========================================

PRINT '';
PRINT '===========================================';
PRINT '資料庫建立完成！';
PRINT '===========================================';
PRINT '';
PRINT '已建立的物件：';
PRINT '  ✓ 2 個資料表：KeywordsMaster, KeywordsLog';
PRINT '  ✓ 2 個觸發器：自動管理主鍵 ID';
PRINT '  ✓ 5 個索引：提升查詢效能';
PRINT '  ✓ 2 個視圖：vw_TodayKeywords, vw_TodaySearches';
PRINT '  ✓ 2 個預存程序：sp_GetTopKeywordsByRegion, sp_GetSearchStats';
PRINT '';
PRINT '實用查詢範例：';
PRINT '  -- 查看今日所有關鍵字';
PRINT '  SELECT * FROM vw_TodayKeywords ORDER BY Region, TrendRank;';
PRINT '';
PRINT '  -- 查看美國地區 Top 20';
PRINT '  EXEC sp_GetTopKeywordsByRegion @Region = ''US'', @TopN = 20;';
PRINT '';
PRINT '  -- 查看所有地區，每個地區 Top 10';
PRINT '  EXEC sp_GetTopKeywordsByRegion @Region = NULL, @TopN = 10;';
PRINT '';
PRINT '  -- 查看過去 7 天的搜尋統計';
PRINT '  EXEC sp_GetSearchStats @DaysBack = 7;';
PRINT '';
PRINT '資料庫已準備就緒，可以開始使用 google_trends_automation.py！';
PRINT '';
GO
