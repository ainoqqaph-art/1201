-- ==========================================
-- Microsoft Rewards Automation - Database Setup Script
-- ==========================================
-- 此腳本用於建立所需的資料庫與資料表

-- 建立資料庫（如果不存在）
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MicrosoftRDB')
BEGIN
    CREATE DATABASE MicrosoftRDB;
    PRINT 'Database MicrosoftRDB created successfully.';
END
ELSE
BEGIN
    PRINT 'Database MicrosoftRDB already exists.';
END
GO

USE MicrosoftRDB;
GO

-- ==========================================
-- 建立 TrendingKeywords 資料表
-- 用於儲存從 Google Trends 抓取的熱門關鍵字
-- ==========================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TrendingKeywords]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[TrendingKeywords] (
        [ID] INT IDENTITY(1,1) PRIMARY KEY,
        [Keyword] NVARCHAR(500) NOT NULL,
        [Rank] INT NOT NULL,
        [SearchVolume] NVARCHAR(100) NULL,
        [FetchedAt] DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT [CHK_TrendingKeywords_Rank] CHECK ([Rank] > 0)
    );
    
    PRINT 'Table TrendingKeywords created successfully.';
END
ELSE
BEGIN
    PRINT 'Table TrendingKeywords already exists.';
END
GO

-- ==========================================
-- 建立 DailyPointsLog 資料表
-- 用於記錄每日的 Microsoft Rewards 點數
-- ==========================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DailyPointsLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[DailyPointsLog] (
        [ID] INT IDENTITY(1,1) PRIMARY KEY,
        [Points] INT NOT NULL,
        [ActivityType] NVARCHAR(100) NOT NULL DEFAULT '搜尋',
        [LoggedAt] DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT [CHK_DailyPointsLog_Points] CHECK ([Points] >= 0)
    );
    
    PRINT 'Table DailyPointsLog created successfully.';
END
ELSE
BEGIN
    PRINT 'Table DailyPointsLog already exists.';
END
GO

-- ==========================================
-- 建立索引以提升查詢效能
-- ==========================================

-- TrendingKeywords 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_TrendingKeywords_FetchedAt' AND object_id = OBJECT_ID('TrendingKeywords'))
BEGIN
    CREATE INDEX IX_TrendingKeywords_FetchedAt ON [dbo].[TrendingKeywords]([FetchedAt] DESC);
    PRINT 'Index IX_TrendingKeywords_FetchedAt created successfully.';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_TrendingKeywords_Keyword' AND object_id = OBJECT_ID('TrendingKeywords'))
BEGIN
    CREATE INDEX IX_TrendingKeywords_Keyword ON [dbo].[TrendingKeywords]([Keyword]);
    PRINT 'Index IX_TrendingKeywords_Keyword created successfully.';
END

-- DailyPointsLog 索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DailyPointsLog_LoggedAt' AND object_id = OBJECT_ID('DailyPointsLog'))
BEGIN
    CREATE INDEX IX_DailyPointsLog_LoggedAt ON [dbo].[DailyPointsLog]([LoggedAt] DESC);
    PRINT 'Index IX_DailyPointsLog_LoggedAt created successfully.';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DailyPointsLog_ActivityType' AND object_id = OBJECT_ID('DailyPointsLog'))
BEGIN
    CREATE INDEX IX_DailyPointsLog_ActivityType ON [dbo].[DailyPointsLog]([ActivityType]);
    PRINT 'Index IX_DailyPointsLog_ActivityType created successfully.';
END
GO

-- ==========================================
-- 建立實用的查詢視圖（選用）
-- ==========================================

-- 今日關鍵字視圖
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodayKeywords')
BEGIN
    EXEC('
    CREATE VIEW vw_TodayKeywords AS
    SELECT 
        ID,
        Keyword,
        Rank,
        SearchVolume,
        FetchedAt
    FROM TrendingKeywords
    WHERE CAST(FetchedAt AS DATE) = CAST(GETDATE() AS DATE)
    ');
    PRINT 'View vw_TodayKeywords created successfully.';
END
GO

-- 今日點數視圖
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_TodayPoints')
BEGIN
    EXEC('
    CREATE VIEW vw_TodayPoints AS
    SELECT 
        ID,
        Points,
        ActivityType,
        LoggedAt
    FROM DailyPointsLog
    WHERE CAST(LoggedAt AS DATE) = CAST(GETDATE() AS DATE)
    ');
    PRINT 'View vw_TodayPoints created successfully.';
END
GO

-- ==========================================
-- 建立統計資料的預存程序（選用）
-- ==========================================

-- 取得過去 N 天的點數統計
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetPointsStats]') AND type in (N'P', N'PC'))
BEGIN
    DROP PROCEDURE [dbo].[sp_GetPointsStats];
END
GO

CREATE PROCEDURE [dbo].[sp_GetPointsStats]
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CAST(LoggedAt AS DATE) AS Date,
        SUM(Points) AS TotalPoints,
        COUNT(*) AS ActivityCount,
        STRING_AGG(ActivityType, ', ') AS ActivityTypes
    FROM DailyPointsLog
    WHERE LoggedAt >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY CAST(LoggedAt AS DATE)
    ORDER BY Date DESC;
END
GO

PRINT 'Stored procedure sp_GetPointsStats created successfully.';
GO

-- 取得熱門關鍵字統計
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTrendingStats]') AND type in (N'P', N'PC'))
BEGIN
    DROP PROCEDURE [dbo].[sp_GetTrendingStats];
END
GO

CREATE PROCEDURE [dbo].[sp_GetTrendingStats]
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        Keyword,
        COUNT(*) AS Appearances,
        AVG(CAST(Rank AS FLOAT)) AS AvgRank,
        MIN(Rank) AS BestRank,
        MAX(FetchedAt) AS LastSeen
    FROM TrendingKeywords
    WHERE FetchedAt >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY Keyword
    HAVING COUNT(*) > 1  -- 至少出現過 2 次
    ORDER BY Appearances DESC, AvgRank ASC;
END
GO

PRINT 'Stored procedure sp_GetTrendingStats created successfully.';
GO

PRINT '';
PRINT '==========================================';
PRINT 'Database setup completed successfully!';
PRINT '==========================================';
PRINT '';
PRINT 'You can now run the following queries to verify:';
PRINT '  - SELECT * FROM TrendingKeywords;';
PRINT '  - SELECT * FROM DailyPointsLog;';
PRINT '  - EXEC sp_GetPointsStats @DaysBack = 7;';
PRINT '  - EXEC sp_GetTrendingStats @DaysBack = 7;';
PRINT '';
GO
