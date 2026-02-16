-- ==================== Google Trends + Rewards 自動化資料庫 v3 ====================
-- 此腳本用於新建 v3 版本資料庫（包含完整功能）
-- 
-- 功能：
-- 1. Google Trends 關鍵字儲存
-- 2. Bing 搜尋記錄
-- 3. Microsoft Rewards 點數記錄
-- 
-- 執行方式：
-- 在 SQL Server Management Studio (SSMS) 中選擇 MicrosoftRDB 資料庫後執行此腳本
-- ==================================================================================

USE MicrosoftRDB;
GO

-- ==================== 第一步：建立表結構 ====================

-- 1. KeywordsMaster：儲存所有爬到的關鍵字
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KeywordsMaster]') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsMaster (
        KeywordID INT PRIMARY KEY,  -- Python 管理，無 IDENTITY
        Keyword NVARCHAR(200) NOT NULL UNIQUE,
        Category NVARCHAR(50),
        SearchIntent NVARCHAR(50),
        CreatedAt DATETIME DEFAULT GETDATE()
    );
    PRINT '✓ KeywordsMaster 表已建立';
END
ELSE
BEGIN
    PRINT '⚠ KeywordsMaster 表已存在';
END
GO

-- 2. KeywordsLog：儲存每次對關鍵字的搜尋記錄
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KeywordsLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsLog (
        LogID INT PRIMARY KEY,  -- Python 管理，無 IDENTITY
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
    PRINT '✓ KeywordsLog 表已建立';
END
ELSE
BEGIN
    PRINT '⚠ KeywordsLog 表已存在';
END
GO

-- 3. DailyPointsLog：儲存 Microsoft Rewards 每日點數
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DailyPointsLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE DailyPointsLog (
        LogID INT PRIMARY KEY,  -- Python 管理，無 IDENTITY
        LogDate DATE NOT NULL,
        AvailablePoints INT NULL,  -- 可用點數
        TodayPoints INT NULL,  -- 今日點數
        PointsGained INT NULL,  -- 今日獲得點數
        Status NVARCHAR(50),  -- 'Success', 'Fail'
        ErrorMessage NVARCHAR(1000),
        CreatedAt DATETIME DEFAULT GETDATE()
    );
    PRINT '✓ DailyPointsLog 表已建立';
END
ELSE
BEGIN
    PRINT '⚠ DailyPointsLog 表已存在';
END
GO

-- ==================== 第二步：建立觸發器（自動管理 ID） ====================

-- 觸發器 1：KeywordsMaster
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsMaster_Insert')
BEGIN
    DROP TRIGGER trg_KeywordsMaster_Insert;
    PRINT '⚠ 已刪除舊的 KeywordsMaster 觸發器';
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
    INSERT INTO KeywordsMaster (KeywordID, Keyword, Category, SearchIntent, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.Keyword,
        inserted.Category,
        inserted.SearchIntent,
        inserted.CreatedAt
    FROM inserted;
END;
GO
PRINT '✓ KeywordsMaster 觸發器已建立';
GO

-- 觸發器 2：KeywordsLog
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_KeywordsLog_Insert')
BEGIN
    DROP TRIGGER trg_KeywordsLog_Insert;
    PRINT '⚠ 已刪除舊的 KeywordsLog 觸發器';
END
GO

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
PRINT '✓ KeywordsLog 觸發器已建立';
GO

-- 觸發器 3：DailyPointsLog
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_DailyPointsLog_Insert')
BEGIN
    DROP TRIGGER trg_DailyPointsLog_Insert;
    PRINT '⚠ 已刪除舊的 DailyPointsLog 觸發器';
END
GO

CREATE TRIGGER trg_DailyPointsLog_Insert
ON DailyPointsLog
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    -- 先鎖定表並取得目前最大值
    SELECT @MaxID = ISNULL(MAX(LogID), 0) FROM DailyPointsLog WITH (TABLOCKX);
    
    -- 插入新資料，ID 逐筆遞增
    INSERT INTO DailyPointsLog (LogID, LogDate, AvailablePoints, TodayPoints, PointsGained, Status, ErrorMessage, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.LogDate,
        inserted.AvailablePoints,
        inserted.TodayPoints,
        inserted.PointsGained,
        inserted.Status,
        inserted.ErrorMessage,
        inserted.CreatedAt
    FROM inserted;
END;
GO
PRINT '✓ DailyPointsLog 觸發器已建立';
GO

-- ==================== 第三步：建立索引（提升查詢效能） ====================

-- KeywordsMaster 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsMaster_Keyword')
BEGIN
    CREATE INDEX IX_KeywordsMaster_Keyword ON KeywordsMaster(Keyword);
    PRINT '✓ KeywordsMaster.Keyword 索引已建立';
END
GO

-- KeywordsLog 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_LogDate')
BEGIN
    CREATE INDEX IX_KeywordsLog_LogDate ON KeywordsLog(LogDate);
    PRINT '✓ KeywordsLog.LogDate 索引已建立';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_KeywordsLog_Status')
BEGIN
    CREATE INDEX IX_KeywordsLog_Status ON KeywordsLog(Status);
    PRINT '✓ KeywordsLog.Status 索引已建立';
END
GO

-- DailyPointsLog 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DailyPointsLog_LogDate')
BEGIN
    CREATE INDEX IX_DailyPointsLog_LogDate ON DailyPointsLog(LogDate);
    PRINT '✓ DailyPointsLog.LogDate 索引已建立';
END
GO

-- ==================== 完成 ====================
PRINT '';
PRINT '╔═══════════════════════════════════════════════════════════════╗';
PRINT '║  ✓ 資料庫建立完成！                                           ║';
PRINT '╠═══════════════════════════════════════════════════════════════╣';
PRINT '║  已建立的物件：                                               ║';
PRINT '║  - 3 個表 (KeywordsMaster, KeywordsLog, DailyPointsLog)       ║';
PRINT '║  - 3 個觸發器（自動管理 ID）                                  ║';
PRINT '║  - 4 個索引（提升查詢效能）                                   ║';
PRINT '║                                                               ║';
PRINT '║  下一步：                                                     ║';
PRINT '║  1. 執行 Python 腳本: python google_trends_rewards_v6.py      ║';
PRINT '║  2. 查詢資料: SELECT * FROM KeywordsMaster                    ║';
PRINT '╚═══════════════════════════════════════════════════════════════╝';
PRINT '';
GO
