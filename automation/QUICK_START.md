# 快速開始指南

此指南將幫助您在 5 分鐘內開始使用 Microsoft Rewards 自動化工具。

## 前置需求檢查清單

在開始之前，請確認您已具備：

- [ ] Python 3.7 或更高版本已安裝
- [ ] Microsoft Edge 瀏覽器已安裝
- [ ] SQL Server 已安裝並運行
- [ ] 您的資料庫中已建立所需的表格（KeywordsMaster, KeywordsLog, DailyPointsLog）
- [ ] Windows 作業系統

## 步驟 1: 安裝 Python 套件

```bash
cd automation
pip install -r requirements.txt
```

應該會安裝：
- selenium
- pyodbc

## 步驟 2: 下載 Edge WebDriver

1. 開啟 Edge 並檢查版本：
   - 網址列輸入：`edge://settings/help`
   - 記下版本號（例如：120.0.2210.144）

2. 下載對應版本：
   - 前往：https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/
   - 下載與您 Edge 版本相符的 WebDriver
   - 解壓縮 `msedgedriver.exe`

3. 建立目錄並放置檔案：
   ```cmd
   mkdir C:\自動化
   ```
   將 `msedgedriver.exe` 複製到 `C:\自動化\`

## 步驟 3: 驗證資料庫設定

在 SQL Server 中執行以下查詢確認表格存在：

```sql
USE MicrosoftRDB;

-- 檢查表格是否存在
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('KeywordsMaster', 'KeywordsLog', 'DailyPointsLog');

-- 應該返回 3 筆記錄
```

## 步驟 4: 測試執行

### 測試模式（不寫入資料庫）

```bash
python microsoft_rewards_automation.py --dry-run
```

如果看到以下輸出，表示設定正確：
```
2026-02-16 10:00:00 - INFO - Edge WebDriver 已啟動
2026-02-16 10:00:05 - INFO - === 步驟 1: 抓取 Google Trends 熱門關鍵字 ===
...
```

### 常見錯誤處理

#### 錯誤：找不到 msedgedriver.exe
```
解決方案：確認檔案位於 C:\自動化\msedgedriver.exe
```

#### 錯誤：無法連接資料庫
```
解決方案：
1. 確認 SQL Server 正在運行
2. 確認資料庫名稱為 MicrosoftRDB
3. 確認您的 Windows 帳號有存取權限
```

#### 錯誤：找不到 selenium 模組
```
解決方案：重新安裝套件
pip install --upgrade selenium pyodbc
```

## 步驟 5: 正式執行

確認測試成功後，執行完整流程：

```bash
python microsoft_rewards_automation.py
```

或使用批次檔（雙擊）：
```
run_automation.bat
```

## 步驟 6: 查看執行結果

### 檢查日誌檔案

```cmd
type microsoft_rewards_automation.log
```

### 查詢資料庫

```sql
-- 查看今日關鍵字
SELECT km.Keyword, kl.Status, kl.CrawlTime
FROM KeywordsLog kl
JOIN KeywordsMaster km ON kl.KeywordID = km.KeywordID
WHERE kl.LogDate = CAST(GETDATE() AS DATE)
ORDER BY kl.CrawlTime DESC;

-- 查看今日點數
SELECT * FROM DailyPointsLog
WHERE LogDate = CAST(GETDATE() AS DATE);
```

## 步驟 7: 設定自動排程（選用）

### 使用 Windows Task Scheduler

1. 按 `Win + R`，輸入 `taskschd.msc`

2. 建立基本工作：
   - 名稱：Microsoft Rewards 自動化
   - 觸發：每日 09:00
   - 動作：啟動程式
     - 程式：`C:\自動化\run_automation.bat`

3. 進階選項：
   - ✓ 以最高權限執行
   - ✓ 失敗時重試

## 執行流程說明

腳本會依序執行：

```
1. 連接資料庫 ✓
   ↓
2. 啟動 Edge WebDriver ✓
   ↓
3. 抓取 Google Trends 關鍵字（前 5 名）✓
   ↓
4. 在 Bing 搜尋每個關鍵字 ✓
   - 等待 30-90 秒
   - 擷取搜尋結果摘要
   - 記錄到 KeywordsLog
   ↓
5. 完成所有搜尋後休息 2-5 分鐘 ✓
   ↓
6. 前往 Microsoft Rewards 頁面 ✓
   ↓
7. 抓取點數資訊 ✓
   - AvailablePoints
   - TodayPoints
   - PointsGained
   ↓
8. 記錄到 DailyPointsLog ✓
   ↓
9. 關閉瀏覽器並清理資源 ✓
```

## 預期執行時間

- **Google Trends 抓取**: ~10-20 秒
- **Bing 搜尋（5 個關鍵字）**: ~5-10 分鐘
  - 每個關鍵字: 30-90 秒
  - 最後休息: 2-5 分鐘
- **點數抓取**: ~10-20 秒

**總時間**: 約 6-12 分鐘

## 檢查執行是否成功

執行成功的標誌：

✅ 日誌檔案最後顯示 "=== 所有步驟完成 ==="
✅ KeywordsLog 表中有 5 筆今日記錄
✅ DailyPointsLog 表中有 1 筆今日記錄
✅ 所有記錄的 Status 為 'Success'

## 下一步

- 📖 閱讀 `USAGE_EXAMPLES.md` 了解進階用法
- 📊 執行 `query_examples.sql` 查看統計資料
- ⚙️ 參考 `config.template.py` 自訂設定
- 🔧 查看 `README.md` 了解詳細文件

## 需要幫助？

1. 查看 `microsoft_rewards_automation.log` 日誌檔案
2. 參考 `README.md` 的疑難排解章節
3. 檢查 `USAGE_EXAMPLES.md` 的常見問題

## 安全提醒

⚠️ **重要**：
- 不要過於頻繁執行（建議每天 1-2 次）
- 保護好您的資料庫連線資訊
- 定期備份資料庫
- 遵守 Microsoft 服務條款

---

**恭喜！您已準備好使用 Microsoft Rewards 自動化工具！** 🎉
