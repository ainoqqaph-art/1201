# Microsoft Rewards 自動化工具 - 使用範例

## 快速開始

### 1. 基本執行（完整流程）
```bash
python microsoft_rewards_automation.py
```
這會執行所有三個步驟：
1. 抓取 Google Trends 關鍵字
2. 在 Bing 搜尋前 5 個關鍵字
3. 抓取並記錄 Microsoft Rewards 點數

---

### 2. 測試模式（不寫入資料庫）
```bash
python microsoft_rewards_automation.py --dry-run
```
適合用於：
- 首次測試腳本是否正常運作
- 驗證 WebDriver 設定是否正確
- 測試網頁抓取邏輯

---

### 3. 跳過特定步驟

#### 只執行 Bing 搜尋和點數記錄（跳過 Google Trends）
```bash
python microsoft_rewards_automation.py --skip-trends
```

#### 只執行 Google Trends 和點數記錄（跳過 Bing 搜尋）
```bash
python microsoft_rewards_automation.py --skip-search
```

#### 只執行 Google Trends 和 Bing 搜尋（跳過點數記錄）
```bash
python microsoft_rewards_automation.py --skip-rewards
```

---

### 4. 組合使用範例

#### 測試模式 + 只執行搜尋
```bash
python microsoft_rewards_automation.py --dry-run --skip-rewards
```

#### 只記錄點數（跳過關鍵字相關操作）
```bash
python microsoft_rewards_automation.py --skip-trends --skip-search
```

---

## 使用 Windows 批次檔

雙擊 `run_automation.bat` 執行完整流程，批次檔會：
1. 檢查 Python 是否已安裝
2. 檢查並自動安裝必要套件
3. 執行自動化腳本
4. 顯示執行結果

---

## 排程執行（Windows Task Scheduler）

### 設定步驟

1. **開啟工作排程器**
   - 按 `Win + R` 輸入 `taskschd.msc`

2. **建立基本工作**
   - 點選「建立基本工作」
   - 名稱：`Microsoft Rewards 每日自動化`
   - 描述：`自動執行 Google Trends 關鍵字搜尋並記錄 Rewards 點數`

3. **設定觸發程序**
   - 選擇「每日」
   - 開始時間：例如 09:00 AM
   - 重複執行：每 1 天

4. **設定動作**
   - 動作：啟動程式
   - 程式或指令碼：`C:\automation\run_automation.bat`
   - 或使用 Python 直接執行：
     - 程式：`C:\Python3\python.exe`
     - 引數：`"C:\automation\microsoft_rewards_automation.py"`
     - 開始位置：`C:\automation\`

5. **進階設定**
   - ✓ 以最高權限執行
   - ✓ 如果工作失敗，每 10 分鐘重試一次
   - ✓ 最多重試 3 次

---

## 檢查執行結果

### 查看日誌檔案
```bash
# Windows
type automation\microsoft_rewards_automation.log

# 或用記事本開啟
notepad automation\microsoft_rewards_automation.log
```

### 查詢資料庫記錄

#### 查看今日關鍵字搜尋記錄
```sql
SELECT 
    km.Keyword,
    kl.LogDate,
    kl.Status,
    LEFT(kl.SummaryText, 100) AS Summary,
    kl.ErrorMessage
FROM KeywordsLog kl
INNER JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;
```

#### 查看今日點數記錄
```sql
SELECT 
    LogDate,
    AvailablePoints,
    TodayPoints,
    PointsGained,
    Status,
    ErrorMessage
FROM DailyPointsLog
WHERE LogDate = CAST(GETDATE() AS DATE)
ORDER BY CreatedAt DESC;
```

#### 查看過去 7 天的點數趨勢
```sql
SELECT 
    LogDate,
    AVG(AvailablePoints) AS AvgAvailable,
    SUM(PointsGained) AS TotalGained,
    COUNT(*) AS RecordCount
FROM DailyPointsLog
WHERE LogDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
    AND Status = 'Success'
GROUP BY LogDate
ORDER BY LogDate DESC;
```

---

## 常見使用情境

### 情境 1：每日自動執行
**需求**：每天早上自動執行，無需手動介入  
**方案**：使用 Windows Task Scheduler 設定每日 09:00 執行

### 情境 2：手動測試
**需求**：測試腳本功能，不影響資料庫  
**方案**：
```bash
python microsoft_rewards_automation.py --dry-run
```

### 情境 3：只收集點數資訊
**需求**：不執行搜尋，只記錄當前點數  
**方案**：
```bash
python microsoft_rewards_automation.py --skip-trends --skip-search
```

### 情境 4：測試 Google Trends 抓取
**需求**：只測試關鍵字抓取功能  
**方案**：
```bash
python microsoft_rewards_automation.py --dry-run --skip-search --skip-rewards
```

### 情境 5：使用已登入的 Edge Profile
**需求**：使用已登入 Microsoft 帳號的 Edge 設定檔  
**方案**：
1. 編輯 `microsoft_rewards_automation.py`
2. 設定：
   ```python
   EDGE_USER_DATA_DIR = r"C:\Users\YourUsername\AppData\Local\Microsoft\Edge\User Data"
   EDGE_PROFILE = "Default"
   ```
3. 執行前確保所有 Edge 視窗已關閉

---

## 疑難排解範例

### 問題：無法連接資料庫
**解決方案**：
```bash
# 測試資料庫連接
python -c "import pyodbc; print(pyodbc.drivers())"
```
確認是否有 "ODBC Driver 17 for SQL Server"

### 問題：WebDriver 版本不符
**解決方案**：
1. 檢查 Edge 版本：`edge://settings/help`
2. 下載對應版本的 msedgedriver.exe
3. 替換 `C:\automation\msedgedriver.exe`

### 問題：無法抓取點數
**解決方案**：
1. 確認已使用登入的 Edge Profile
2. 手動登入 rewards.microsoft.com
3. 或調整 CSS Selector（網頁結構可能已變化）

---

## 效能優化建議

1. **避免過於頻繁執行**
   - 建議每天執行 1-2 次即可
   - 避免觸發反機器人機制

2. **調整搜尋間隔**
   - 可在設定區調整 `PER_KEYWORD_MIN` 和 `PER_KEYWORD_MAX`
   - 建議保持 30-90 秒的隨機間隔

3. **使用 Edge Profile**
   - 可減少登入步驟
   - 加快執行速度

4. **定期清理日誌**
   - 日誌檔案可能會變大
   - 建議定期備份或清理舊日誌

---

## 安全注意事項

1. **不要分享設定檔**
   - 設定檔可能包含敏感路徑
   
2. **定期更新密碼**
   - 使用 Edge Profile 時建議定期更新密碼

3. **監控異常活動**
   - 定期檢查 ErrorMessage 欄位
   - 注意異常的失敗記錄

4. **備份資料庫**
   - 定期備份 MicrosoftRDB 資料庫
   - 保護歷史點數記錄

---

## 進階使用

### 自訂關鍵字數量
編輯 `microsoft_rewards_automation.py`：
```python
TOP_N = 10  # 改為抓取前 10 個關鍵字
```

### 變更 Google Trends 地區
編輯 `microsoft_rewards_automation.py`：
```python
TRENDS_URL = "https://trends.google.com.tw/trending?geo=TW&status=active&sort=search-volume"
# geo=TW (台灣), geo=JP (日本), geo=GB (英國)
```

### 調整重試次數
編輯 `microsoft_rewards_automation.py`：
```python
MAX_RETRIES = 5  # 增加重試次數
INITIAL_BACKOFF = 3  # 增加初始退避時間
```
