-- ==========================================
-- Microsoft Rewards Automation - Database Schema Reference
-- ==========================================
-- 此檔案記錄所需的資料庫結構（供參考）
-- 使用者應該已經在資料庫中建立這些表和觸發器

-- ==========================================
-- 資料表說明
-- ==========================================

-- ==================== KeywordsMaster ====================
-- 儲存所有爬到的關鍵字（一次性）
-- 說明：此表儲存唯一的關鍵字主檔，KeywordID 由觸發器自動管理
/*
CREATE TABLE KeywordsMaster (
  KeywordID INT PRIMARY KEY,  -- Python 管理，無 IDENTITY
  Keyword NVARCHAR(200) NOT NULL UNIQUE,
  Category NVARCHAR(50),
  SearchIntent NVARCHAR(50),
  CreatedAt DATETIME DEFAULT GETDATE()
);
*/

-- ==================== KeywordsLog ====================
-- 儲存每次對關鍵字的搜尋記錄
-- 說明：記錄每次搜尋的詳細資訊，包含摘要、狀態、錯誤訊息等
/*
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
*/

-- ==================== DailyPointsLog ====================
-- 儲存每日的 Microsoft Rewards 點數記錄
-- 說明：記錄可用點數、今日點數、獲得點數等資訊
/*
CREATE TABLE DailyPointsLog (
  LogID INT PRIMARY KEY,  -- Python 管理，無 IDENTITY
  LogDate DATE NOT NULL,
  AvailablePoints INT NULL,  -- 可用點數（登入成功時填充）
  TodayPoints INT NULL,  -- 今日點數（登入成功時填充）
  PointsGained INT NULL,  -- 今日獲得點數（通常等於 TodayPoints）
  Status NVARCHAR(50),  -- 'Success', 'Fail'
  ErrorMessage NVARCHAR(1000),  -- 若失敗記錄錯誤訊息
  CreatedAt DATETIME DEFAULT GETDATE()
);
*/

-- ==========================================
-- 觸發器說明
-- ==========================================
-- 這些觸發器會自動管理主鍵 ID，Python 插入時可使用 0 作為佔位值

-- KeywordsMaster 觸發器
/*
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
*/

-- KeywordsLog 觸發器
/*
CREATE TRIGGER trg_KeywordsLog_Insert
ON KeywordsLog
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MaxID INT = 0;
    
    -- 先鎖定表並取得目前最大值
    SELECT @MaxID = ISNULL(MAX(LogID), 0) FROM KeywordsLog WITH (TABLOCKX);
    
    -- 插入新資料，ID 逐筆遞增
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
        inserted.CreatedAt
    FROM inserted;
END;
*/

-- DailyPointsLog 觸發器
/*
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
*/

-- ==========================================
-- 實用查詢範例
-- ==========================================

-- 查詢今日所有關鍵字搜尋記錄
/*
SELECT 
    km.Keyword,
    kl.LogDate,
    kl.CrawlTime,
    kl.Status,
    LEFT(kl.SummaryText, 100) AS Summary,
    kl.ErrorMessage
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;
*/

-- 查詢今日點數記錄
/*
SELECT 
    LogDate,
    AvailablePoints,
    TodayPoints,
    PointsGained,
    Status,
    ErrorMessage,
    CreatedAt
FROM DailyPointsLog
WHERE LogDate = CAST(GETDATE() AS DATE)
ORDER BY CreatedAt DESC;
*/

-- 查詢過去 7 天的點數趨勢
/*
SELECT 
    LogDate,
    SUM(PointsGained) AS TotalGained,
    MAX(AvailablePoints) AS MaxAvailable,
    COUNT(CASE WHEN Status = 'Success' THEN 1 END) AS SuccessCount,
    COUNT(CASE WHEN Status = 'Fail' THEN 1 END) AS FailCount
FROM DailyPointsLog
WHERE LogDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
GROUP BY LogDate
ORDER BY LogDate DESC;
*/

-- 查詢最常出現的關鍵字
/*
SELECT TOP 10
    km.Keyword,
    COUNT(*) AS SearchCount,
    SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
    MAX(kl.LogDate) AS LastSearchDate
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
GROUP BY km.Keyword
ORDER BY SearchCount DESC;
*/

PRINT '資料庫結構參考檔案';
PRINT '請確認您的資料庫已包含上述表格和觸發器';

