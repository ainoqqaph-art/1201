# Google Trends 多地區支援 - 更新說明

## 變更概述

本次更新實現了從多個地區抓取 Google Trends 熱門關鍵字的功能，並修復了原本 WebDriver 崩潰的問題。

## 主要改進

### 1. 多地區支援 ✨

**舊版本**：
- 僅支援單一地區 (美國)
- 單一 URL 配置

**新版本**：
- 支援 **6 個地區**同時抓取：
  - 🇺🇸 美國 (US)
  - 🇹🇼 台灣 (TW)
  - 🇯🇵 日本 (JP)
  - 🇬🇧 英國 (GB)
  - 🇭🇰 香港 (HK)
  - 🇦🇺 澳洲 (AU)

### 2. 修復 WebDriver 崩潰問題 🔧

**問題**：
```
ERROR - 抓取 Google Trends 失敗: Message: 
Stacktrace: Symbols not available...
```

**解決方案**：
- ✅ 更新 Google Trends URL 為更穩定的端點
- ✅ 實現 4 層備用策略：
  1. Table 結構抓取 (tbody tr)
  2. Feed-item 選擇器
  3. 通用 trending 選擇器
  4. JSON API 解析
- ✅ 改進 WebDriver 配置（禁用 GPU、增加穩定性選項）
- ✅ 加入自動截圖功能用於調試

### 3. 新增配置選項

```python
# 多地區 URL 列表
TRENDS_URLS = [
    "https://trends.google.com.tw/trending?geo=US",   # 美國
    "https://trends.google.com.tw/trending?geo=TW",   # 台灣
    "https://trends.google.com.tw/trending?geo=JP",   # 日本
    "https://trends.google.com.tw/trending?geo=GB",   # 英國
    "https://trends.google.com.tw/trending?geo=HK",   # 香港
    "https://trends.google.com.tw/trending?geo=AU",   # 澳洲
]

# 每個地區抓取的關鍵字數量
KEYWORDS_PER_REGION = 5

# 從所有地區總共選取前 N 名進行搜尋
TOP_N = 5
```

## 執行流程

### 步驟 1: 抓取多地區關鍵字

```
開始執行
  ↓
遍歷 6 個地區
  ↓
每個地區：
  - 訪問 Google Trends URL
  - 使用多策略抓取關鍵字
  - 記錄地區來源
  - 儲存截圖（如有錯誤）
  ↓
匯總所有關鍵字 (最多 30 個)
```

### 步驟 2: Bing 搜尋

```
選取前 5 個關鍵字
  ↓
對每個關鍵字：
  - 顯示來源地區
  - 在 Bing 搜尋
  - 擷取摘要
  - 儲存到資料庫
  - 等待 30-90 秒
  ↓
完成後休息 2-5 分鐘
```

### 步驟 3: 記錄點數

```
抓取 Microsoft Rewards 點數
  ↓
儲存到 DailyPointsLog
  - AvailablePoints
  - TodayPoints
  - PointsGained
```

## 資料庫變更

### KeywordsMaster 表
- **Category 欄位**：現在包含地區資訊
  - 範例：`Google Trends (US)`, `Google Trends (TW)`

### KeywordsLog 表
- 記錄每次搜尋，包含來源地區資訊

## 日誌輸出範例

```
2026-02-16 12:00:00 - INFO - === 步驟 1: 抓取 Google Trends 熱門關鍵字 ===
2026-02-16 12:00:00 - INFO - 正在抓取 US 地區的 Google Trends...
2026-02-16 12:00:05 - INFO - 發現關鍵字 (US) #1: Example Keyword
2026-02-16 12:00:07 - INFO - 從 US 成功抓取 5 個關鍵字
2026-02-16 12:00:09 - INFO - 正在抓取 TW 地區的 Google Trends...
2026-02-16 12:00:14 - INFO - 發現關鍵字 (TW) #1: 範例關鍵字
...
2026-02-16 12:01:00 - INFO - 總共從 6 個地區抓取到 28 個關鍵字

2026-02-16 12:01:00 - INFO - === 步驟 2: 在 Bing 搜尋前 5 個關鍵字 ===
2026-02-16 12:01:00 - INFO - [1/5] 搜尋關鍵字: Example Keyword (來自 US)
2026-02-16 12:01:05 - INFO - 已完成搜尋: Example Keyword
...
```

## 錯誤處理改進

### 自動截圖
- **除錯截圖**：`debug_trends_{region}_{retry}.png`
- **錯誤截圖**：`error_trends_{region}_{retry}.png`

### 重試機制
- 每個地區獨立重試（最多 3 次）
- 指數退避策略（2秒 → 4秒 → 8秒）
- 單一地區失敗不影響其他地區

### 備用策略
如果某個地區的所有嘗試都失敗：
- 記錄錯誤日誌
- 儲存截圖
- 繼續處理下一個地區
- 不會中斷整個流程

## 性能影響

### 執行時間估算

**舊版本** (單一地區):
- Google Trends: ~10-20 秒
- Bing 搜尋: ~5-10 分鐘
- 總時間: ~6-12 分鐘

**新版本** (6 個地區):
- Google Trends: ~1-2 分鐘（6 個地區 × 10-20 秒）
- Bing 搜尋: ~5-10 分鐘（仍然只搜尋 5 個關鍵字）
- 總時間: ~7-14 分鐘

**增加時間**：約 1-2 分鐘（用於抓取額外地區）

## 自訂配置

### 調整地區列表

您可以新增或移除地區：

```python
TRENDS_URLS = [
    "https://trends.google.com.tw/trending?geo=US",   # 美國
    "https://trends.google.com.tw/trending?geo=TW",   # 台灣
    "https://trends.google.com.tw/trending?geo=FR",   # 法國 (新增)
    "https://trends.google.com.tw/trending?geo=DE",   # 德國 (新增)
]
```

### 調整每地區關鍵字數量

```python
KEYWORDS_PER_REGION = 10  # 每個地區抓取 10 個關鍵字
```

### 調整搜尋數量

```python
TOP_N = 10  # 從所有地區選取前 10 個進行搜尋
```

## 查詢範例

### 查看各地區關鍵字統計

```sql
SELECT 
    Category AS 地區,
    COUNT(*) AS 關鍵字數量
FROM KeywordsMaster
WHERE Category LIKE 'Google Trends%'
GROUP BY Category
ORDER BY 關鍵字數量 DESC;
```

### 查看今日各地區搜尋記錄

```sql
SELECT 
    km.Category AS 地區,
    km.Keyword AS 關鍵字,
    kl.Status AS 狀態,
    kl.CrawlTime AS 搜尋時間
FROM KeywordsLog kl
JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;
```

## 測試建議

### 首次執行
```bash
# 使用測試模式，不寫入資料庫
python microsoft_rewards_automation.py --dry-run
```

### 測試特定步驟
```bash
# 只測試 Google Trends 抓取
python microsoft_rewards_automation.py --dry-run --skip-search --skip-rewards

# 只測試 Bing 搜尋（跳過 Trends）
python microsoft_rewards_automation.py --skip-trends --skip-rewards
```

## 升級步驟

如果您已經在使用舊版本：

1. **備份現有腳本**
   ```bash
   copy microsoft_rewards_automation.py microsoft_rewards_automation.py.bak
   ```

2. **更新程式碼**（已完成）

3. **測試執行**
   ```bash
   python microsoft_rewards_automation.py --dry-run
   ```

4. **檢查日誌**
   ```bash
   type microsoft_rewards_automation.log
   ```

5. **正式執行**
   ```bash
   python microsoft_rewards_automation.py
   ```

## 常見問題

### Q: 為什麼要支援多個地區？
A: 不同地區有不同的熱門話題，這樣可以獲得更多樣化的關鍵字，提高 Rewards 點數獲取的效率。

### Q: 會不會影響現有資料？
A: 不會。新版本完全相容現有資料庫結構，只是在 Category 欄位加入地區資訊。

### Q: 可以只使用部分地區嗎？
A: 可以。編輯 TRENDS_URLS 列表，移除不需要的地區即可。

### Q: 執行時間會增加多少？
A: 約增加 1-2 分鐘用於抓取多個地區的關鍵字。

### Q: 如果某個地區抓取失敗會怎樣？
A: 該地區會被跳過，繼續處理其他地區，不會影響整體執行。

## 版本資訊

- **版本**: 1.1.0
- **更新日期**: 2026-02-16
- **主要變更**: 
  - 多地區 Google Trends 支援
  - 修復 WebDriver 崩潰問題
  - 改進錯誤處理和調試功能

---

**注意**: 所有改進都已完成並通過語法檢查，建議在實際 Windows 環境中測試後再部署到生產環境。
