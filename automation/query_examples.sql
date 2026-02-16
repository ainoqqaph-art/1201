-- ==========================================
-- Microsoft Rewards Automation - 實用查詢範例
-- ==========================================
-- 這些查詢可幫助您分析自動化執行的結果

USE MicrosoftRDB;
GO

-- ==========================================
-- 1. 今日執行狀況總覽
-- ==========================================
PRINT '=== 今日執行狀況總覽 ===';

-- 今日關鍵字搜尋記錄
SELECT 
    '關鍵字搜尋' AS 類型,
    COUNT(*) AS 總數,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS 成功,
    SUM(CASE WHEN Status = 'Fail' THEN 1 ELSE 0 END) AS 失敗
FROM KeywordsLog
WHERE LogDate = CAST(GETDATE() AS DATE)

UNION ALL

-- 今日點數記錄
SELECT 
    '點數記錄' AS 類型,
    COUNT(*) AS 總數,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS 成功,
    SUM(CASE WHEN Status = 'Fail' THEN 1 ELSE 0 END) AS 失敗
FROM DailyPointsLog
WHERE LogDate = CAST(GETDATE() AS DATE);

-- ==========================================
-- 2. 今日搜尋的關鍵字詳情
-- ==========================================
PRINT '';
PRINT '=== 今日搜尋的關鍵字詳情 ===';

SELECT 
    km.Keyword AS 關鍵字,
    km.Category AS 分類,
    kl.CrawlTime AS 搜尋時間,
    kl.Status AS 狀態,
    CASE 
        WHEN LEN(kl.SummaryText) > 100 THEN LEFT(kl.SummaryText, 100) + '...'
        ELSE kl.SummaryText 
    END AS 摘要,
    kl.ErrorMessage AS 錯誤訊息
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;

-- ==========================================
-- 3. 今日點數資訊
-- ==========================================
PRINT '';
PRINT '=== 今日點數資訊 ===';

SELECT 
    LogDate AS 日期,
    AvailablePoints AS 可用點數,
    TodayPoints AS 今日點數,
    PointsGained AS 獲得點數,
    Status AS 狀態,
    ErrorMessage AS 錯誤訊息,
    CreatedAt AS 記錄時間
FROM DailyPointsLog
WHERE LogDate = CAST(GETDATE() AS DATE)
ORDER BY CreatedAt DESC;

-- ==========================================
-- 4. 過去 7 天點數趨勢
-- ==========================================
PRINT '';
PRINT '=== 過去 7 天點數趨勢 ===';

SELECT 
    LogDate AS 日期,
    MAX(AvailablePoints) AS 最高可用點數,
    AVG(TodayPoints) AS 平均今日點數,
    SUM(PointsGained) AS 總獲得點數,
    COUNT(*) AS 記錄次數,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS 成功次數,
    SUM(CASE WHEN Status = 'Fail' THEN 1 ELSE 0 END) AS 失敗次數
FROM DailyPointsLog
WHERE LogDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
GROUP BY LogDate
ORDER BY LogDate DESC;

-- ==========================================
-- 5. 最常搜尋的關鍵字 (Top 10)
-- ==========================================
PRINT '';
PRINT '=== 最常搜尋的關鍵字 (Top 10) ===';

SELECT TOP 10
    km.Keyword AS 關鍵字,
    km.Category AS 分類,
    COUNT(*) AS 搜尋次數,
    SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS 成功次數,
    SUM(CASE WHEN kl.Status = 'Fail' THEN 1 ELSE 0 END) AS 失敗次數,
    MAX(kl.LogDate) AS 最後搜尋日期
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
GROUP BY km.Keyword, km.Category
ORDER BY 搜尋次數 DESC;

-- ==========================================
-- 6. 搜尋失敗記錄（最近 30 天）
-- ==========================================
PRINT '';
PRINT '=== 搜尋失敗記錄（最近 30 天） ===';

SELECT 
    km.Keyword AS 關鍵字,
    kl.LogDate AS 日期,
    kl.CrawlTime AS 時間,
    kl.ErrorMessage AS 錯誤訊息
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.Status = 'Fail'
    AND kl.LogDate >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY kl.CrawlTime DESC;

-- ==========================================
-- 7. 點數獲取失敗記錄（最近 30 天）
-- ==========================================
PRINT '';
PRINT '=== 點數獲取失敗記錄（最近 30 天） ===';

SELECT 
    LogDate AS 日期,
    ErrorMessage AS 錯誤訊息,
    CreatedAt AS 記錄時間
FROM DailyPointsLog
WHERE Status = 'Fail'
    AND LogDate >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY LogDate DESC;

-- ==========================================
-- 8. 每週點數統計（最近 4 週）
-- ==========================================
PRINT '';
PRINT '=== 每週點數統計（最近 4 週） ===';

SELECT 
    DATEPART(YEAR, LogDate) AS 年,
    DATEPART(WEEK, LogDate) AS 週,
    MIN(LogDate) AS 週開始日期,
    MAX(LogDate) AS 週結束日期,
    AVG(AvailablePoints) AS 平均可用點數,
    SUM(PointsGained) AS 週總獲得點數,
    COUNT(*) AS 記錄次數
FROM DailyPointsLog
WHERE LogDate >= DATEADD(WEEK, -4, CAST(GETDATE() AS DATE))
    AND Status = 'Success'
GROUP BY DATEPART(YEAR, LogDate), DATEPART(WEEK, LogDate)
ORDER BY 年 DESC, 週 DESC;

-- ==========================================
-- 9. 關鍵字分類統計
-- ==========================================
PRINT '';
PRINT '=== 關鍵字分類統計 ===';

SELECT 
    ISNULL(km.Category, '未分類') AS 分類,
    COUNT(DISTINCT km.KeywordID) AS 關鍵字數量,
    COUNT(*) AS 總搜尋次數,
    SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS 成功次數,
    CAST(SUM(CASE WHEN kl.Status = 'Success' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,2)) AS 成功率
FROM KeywordsMaster km
LEFT JOIN KeywordsLog kl ON km.KeywordID = kl.KeywordID
GROUP BY km.Category
ORDER BY 總搜尋次數 DESC;

-- ==========================================
-- 10. 執行效率分析（每日搜尋時間分布）
-- ==========================================
PRINT '';
PRINT '=== 執行效率分析（過去 7 天） ===';

SELECT 
    LogDate AS 日期,
    COUNT(*) AS 搜尋次數,
    MIN(CrawlTime) AS 第一次搜尋,
    MAX(CrawlTime) AS 最後一次搜尋,
    DATEDIFF(MINUTE, MIN(CrawlTime), MAX(CrawlTime)) AS 總執行時間_分鐘
FROM KeywordsLog
WHERE LogDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
GROUP BY LogDate
ORDER BY LogDate DESC;

PRINT '';
PRINT '==========================================';
PRINT '查詢完成！';
PRINT '==========================================';
