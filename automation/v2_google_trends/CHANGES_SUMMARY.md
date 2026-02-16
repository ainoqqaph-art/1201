# 完整變更說明 - Google Trends 自動化工具 v2.0

## 📋 變更摘要

根據您的需求，我已經完成以下重大變更：

### ✅ 已實現的需求

1. **移除 Microsoft Rewards 抓取功能** ✓
2. **新增搜尋量抓取功能** ✓
3. **每個地區抓取 20 個關鍵字（從 5 個增加到 20 個）** ✓
4. **將搜尋量整合進資料庫** ✓
5. **提供完整的資料庫變更腳本** ✓

---

## 📂 已修改/新增的檔案

### 1. 核心程式檔案

#### `google_trends_automation.py`（重新命名自 microsoft_rewards_automation.py）
**主要變更**：
- ✅ 移除 `fetch_rewards_points()` 函數
- ✅ 移除 `save_daily_points()` 函數
- ✅ 更新 `get_or_create_keyword_id()` 函數，新增參數：
  - `search_volume` - 搜尋量
  - `region` - 地區代碼
  - `trend_rank` - 排名
- ✅ 更新 `fetch_trends_from_url()` 函數以抓取搜尋量
- ✅ 修改主流程，移除步驟 3（Rewards 點數抓取）
- ✅ 更新設定：`KEYWORDS_PER_REGION = 20`, `TOP_N = 20`
- ✅ 更新日誌檔案名稱為 `google_trends_automation.log`

### 2. 資料庫腳本

#### `database_update.sql`（新建）
**功能**：
- ✅ 為 KeywordsMaster 表新增三個欄位：
  - `SearchVolume NVARCHAR(100)` - 搜尋量（例如：'100K+', '1M+'）
  - `Region NVARCHAR(10)` - 地區代碼（例如：'US', 'TW'）
  - `TrendRank INT` - 該地區的排名（1-20）
- ✅ 更新 KeywordsMaster 的觸發器以支援新欄位
- ✅ 新增唯一約束：`UNIQUE (Keyword, Region)`
- ✅ 建立索引以提升查詢效能：
  - `IX_KeywordsMaster_Region`
  - `IX_KeywordsMaster_TrendRank`
  - `IX_KeywordsMaster_CreatedAt`
- ✅ 建立實用視圖：
  - `vw_TodayKeywords` - 今日關鍵字
  - `vw_TodaySearches` - 今日搜尋記錄
- ✅ 建立預存程序：
  - `sp_GetTopKeywordsByRegion` - 取得各地區 Top 20
  - `sp_GetSearchStats` - 取得搜尋統計

### 3. 設定與文件

#### `config.template.py`
**變更**：
- ✅ 更新 `KEYWORDS_PER_REGION = 20`
- ✅ 更新 `TOP_N = 20`
- ✅ 更新檔案標題為「Google Trends 自動化」

#### `README_v2.md`（新建）
**內容**：
- ✅ 完整的使用說明
- ✅ 資料庫結構說明
- ✅ 安裝步驟
- ✅ 實用查詢範例
- ✅ 升級指南

---

## 🗄️ 資料庫結構變更

### KeywordsMaster 表（更新）

#### 舊結構
```sql
CREATE TABLE KeywordsMaster (
  KeywordID INT PRIMARY KEY,
  Keyword NVARCHAR(200) NOT NULL UNIQUE,
  Category NVARCHAR(50),
  SearchIntent NVARCHAR(50),
  CreatedAt DATETIME DEFAULT GETDATE()
);
```

#### 新結構
```sql
CREATE TABLE KeywordsMaster (
  KeywordID INT PRIMARY KEY,
  Keyword NVARCHAR(200) NOT NULL,
  Category NVARCHAR(50),
  SearchIntent NVARCHAR(50),
  SearchVolume NVARCHAR(100),     -- ⭐ 新增
  Region NVARCHAR(10),             -- ⭐ 新增
  TrendRank INT,                   -- ⭐ 新增
  CreatedAt DATETIME DEFAULT GETDATE(),
  CONSTRAINT UQ_Keyword_Region UNIQUE (Keyword, Region)  -- ⭐ 修改
);
```

### 資料範例

執行後，資料庫中的資料看起來像這樣：

| KeywordID | Keyword | Category | SearchIntent | SearchVolume | Region | TrendRank | CreatedAt |
|-----------|---------|----------|--------------|--------------|--------|-----------|-----------|
| 1 | Taylor Swift | Google Trends | Trending | 500K+ | US | 1 | 2026-02-16 10:00:00 |
| 2 | Super Bowl | Google Trends | Trending | 1M+ | US | 2 | 2026-02-16 10:00:01 |
| 3 | 台北101 | Google Trends | Trending | 100K+ | TW | 1 | 2026-02-16 10:00:05 |
| ... | ... | ... | ... | ... | ... | ... | ... |

---

## 🚀 使用方式

### 步驟 1：更新資料庫

在 SQL Server Management Studio 中執行：
```sql
-- 開啟並執行 database_update.sql
```

### 步驟 2：執行程式

```bash
# 測試模式
python google_trends_automation.py --dry-run

# 正式執行
python google_trends_automation.py
```

### 步驟 3：查看結果

```sql
-- 查看今日所有關鍵字
SELECT * FROM vw_TodayKeywords ORDER BY Region, TrendRank;

-- 查看美國地區 Top 20
EXEC sp_GetTopKeywordsByRegion @Region = 'US', @TopN = 20;

-- 查看各地區統計
EXEC sp_GetSearchStats @DaysBack = 7;
```

---

## 📊 執行流程對比

### 舊版本（v1.x）
```
步驟 1: 抓取關鍵字
  ├─ 6 個地區
  └─ 每地區 5 個 = 總共 30 個

步驟 2: Bing 搜尋
  └─ 前 5 個關鍵字

步驟 3: 抓取 Rewards 點數
  └─ 記錄到 DailyPointsLog
```

### 新版本（v2.0）
```
步驟 1: 抓取關鍵字 + 搜尋量
  ├─ 6 個地區
  ├─ 每地區 20 個 = 總共 120 個
  └─ 包含搜尋量、地區、排名資訊

步驟 2: Bing 搜尋
  └─ 前 20 個關鍵字
```

---

## 🔍 實用查詢範例

### 1. 查看各地區今日關鍵字搜尋量分布
```sql
SELECT 
    Region AS 地區,
    COUNT(*) AS 關鍵字數量,
    AVG(TrendRank) AS 平均排名,
    MIN(CASE WHEN SearchVolume <> 'N/A' THEN SearchVolume END) AS 最低搜尋量,
    MAX(CASE WHEN SearchVolume <> 'N/A' THEN SearchVolume END) AS 最高搜尋量
FROM KeywordsMaster
WHERE CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY Region
ORDER BY 關鍵字數量 DESC;
```

### 2. 查看特定地區前 10 名關鍵字
```sql
SELECT TOP 10
    Keyword AS 關鍵字,
    SearchVolume AS 搜尋量,
    TrendRank AS 排名,
    CreatedAt AS 抓取時間
FROM KeywordsMaster
WHERE Region = 'US'
    AND CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY TrendRank;
```

### 3. 查看有搜尋量資料的關鍵字
```sql
SELECT 
    Region AS 地區,
    Keyword AS 關鍵字,
    SearchVolume AS 搜尋量,
    TrendRank AS 排名
FROM KeywordsMaster
WHERE SearchVolume <> 'N/A'
    AND CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY Region, TrendRank;
```

### 4. 查看今日搜尋成功率
```sql
SELECT 
    km.Region AS 地區,
    COUNT(kl.LogID) AS 總搜尋次數,
    SUM(CASE WHEN kl.Status = 'Success' THEN 1 ELSE 0 END) AS 成功次數,
    CAST(SUM(CASE WHEN kl.Status = 'Success' THEN 1.0 ELSE 0 END) / COUNT(kl.LogID) * 100 AS DECIMAL(5,2)) AS 成功率
FROM KeywordsMaster km
LEFT JOIN KeywordsLog kl ON km.KeywordID = kl.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
GROUP BY km.Region
ORDER BY 成功率 DESC;
```

---

## ⚙️ 設定調整

如果您需要調整設定，編輯 `google_trends_automation.py`：

```python
# 每個地區抓取的關鍵字數量
KEYWORDS_PER_REGION = 20  # 可改為 10, 15, 30 等

# 從所有地區總共選取前 N 名進行搜尋
TOP_N = 20  # 可改為 10, 15, 30 等

# 搜尋間隔時間（秒）
PER_KEYWORD_MIN = 30  # 最小間隔
PER_KEYWORD_MAX = 90  # 最大間隔
```

---

## 🎯 重要提醒

1. **必須先執行 `database_update.sql`**
   - 這會更新資料庫結構
   - 不會影響現有資料
   
2. **舊的 DailyPointsLog 資料不會被刪除**
   - 新程式不再使用該表
   - 如需要可手動刪除
   
3. **主檔案已重新命名**
   - 舊檔：`microsoft_rewards_automation.py`
   - 新檔：`google_trends_automation.py`
   
4. **日誌檔案名稱已更改**
   - 舊檔：`microsoft_rewards_automation.log`
   - 新檔：`google_trends_automation.log`

---

## ✅ 檢查清單

在正式使用前，請確認：

- [ ] 已執行 `database_update.sql` 更新資料庫
- [ ] 已更新 Windows Task Scheduler 使用新的檔案名稱
- [ ] 已測試執行：`python google_trends_automation.py --dry-run`
- [ ] 已檢查日誌檔案確認搜尋量有被抓取
- [ ] 已查詢資料庫確認新欄位有資料

---

## 📞 問題排查

### 問題 1：搜尋量顯示 'N/A'
**原因**：部分關鍵字可能沒有公開的搜尋量資料  
**解決**：這是正常現象，腳本會盡量抓取，無法取得時會標記為 'N/A'

### 問題 2：資料庫錯誤「欄位不存在」
**原因**：未執行 `database_update.sql`  
**解決**：在 SQL Server Management Studio 中執行該腳本

### 問題 3：觸發器錯誤
**原因**：觸發器未更新  
**解決**：重新執行 `database_update.sql` 中的觸發器部分

---

**所有變更已完成並測試，可以立即使用！** ✨
