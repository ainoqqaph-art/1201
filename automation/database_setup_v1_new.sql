-- ==========================================
-- Microsoft Rewards 自動化 v1.x - 完整資料庫建立腳本
-- ==========================================
-- 此腳本用於「新建」資料庫時使用（v1 版本）
-- 包含所有必要的表和觸發器（含 DailyPointsLog）
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
PRINT '步驟 1: 建立資料表（v1.x 版本）';
PRINT '===========================================';
PRINT '';

-- ==================== KeywordsMaster ====================
PRINT '建立 KeywordsMaster 表...';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'KeywordsMaster') AND type in (N'U'))
BEGIN
    CREATE TABLE KeywordsMaster (
        KeywordID INT PRIMARY KEY,          -- 由觸發器自動管理
        Keyword NVARCHAR(200) NOT NULL UNIQUE, -- 關鍵字文字（唯一）
        Category NVARCHAR(50),              -- 分類
        SearchIntent NVARCHAR(50),          -- 搜尋意圖
        CreatedAt DATETIME DEFAULT GETDATE() -- 建立時間
    );
    
    PRINT '  ✓ KeywordsMaster 表已建立';
END
ELSE
BEGIN
    PRINT '  ! KeywordsMaster 表已存在，跳過建立';
END
GO

-- ==================== KeywordsLog ====================
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

-- ==================== DailyPointsLog ====================
PRINT '建立 DailyPointsLog 表...';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'DailyPointsLog') AND type in (N'U'))
BEGIN
    CREATE TABLE DailyPointsLog (
        LogID INT PRIMARY KEY,              -- 由觸發器自動管理
        LogDate DATE NOT NULL,              -- 記錄日期
        AvailablePoints INT NULL,           -- 可用點數（登入成功時填充）
        TodayPoints INT NULL,               -- 今日點數（登入成功時填充）
        PointsGained INT NULL,              -- 今日獲得點數（通常等於 TodayPoints）
        Status NVARCHAR(50),                -- 'Success', 'Fail'
        ErrorMessage NVARCHAR(1000),        -- 若失敗記錄錯誤訊息
        CreatedAt DATETIME DEFAULT GETDATE() -- 建立時間
    );
    
    PRINT '  ✓ DailyPointsLog 表已建立';
END
ELSE
BEGIN
    PRINT '  ! DailyPointsLog 表已存在，跳過建立';
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
    INSERT INTO KeywordsMaster (KeywordID, Keyword, Category, SearchIntent, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.Keyword,
        inserted.Category,
        inserted.SearchIntent,
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

-- DailyPointsLog 觸發器
PRINT '建立 DailyPointsLog 觸發器...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_DailyPointsLog_Insert')
BEGIN
    DROP TRIGGER trg_DailyPointsLog_Insert;
    PRINT '  ! 舊的觸發器已刪除';
END
GO

CREATE TRIGGER trg_DailyPointsLog_Insert
ON DailyPointsLog
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    SELECT @MaxID = ISNULL(MAX(LogID), 0) FROM DailyPointsLog WITH (TABLOCKX);
    
    INSERT INTO DailyPointsLog (LogID, LogDate, AvailablePoints, TodayPoints, PointsGained, Status, ErrorMessage, CreatedAt)
    SELECT 
        @MaxID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
        inserted.LogDate,
        inserted.AvailablePoints,
        inserted.TodayPoints,
        inserted.PointsGained,
        inserted.Status,
        inserted.ErrorMessage,
        ISNULL(inserted.CreatedAt, GETDATE())
    FROM inserted;
END;
GO

PRINT '  ✓ trg_DailyPointsLog_Insert 觸發器已建立';
PRINT '';

-- ==========================================
-- 完成訊息
-- ==========================================

PRINT '';
PRINT '===========================================';
PRINT '資料庫建立完成！（v1.x 版本）';
PRINT '===========================================';
PRINT '';
PRINT '已建立的物件：';
PRINT '  ✓ 3 個資料表：KeywordsMaster, KeywordsLog, DailyPointsLog';
PRINT '  ✓ 3 個觸發器：自動管理主鍵 ID';
PRINT '';
PRINT '注意：此為 v1.x 版本的資料庫結構';
PRINT '      包含 Microsoft Rewards 點數追蹤功能（DailyPointsLog）';
PRINT '';
PRINT '資料庫已準備就緒，可以開始使用 microsoft_rewards_automation.py！';
PRINT '';
GO
