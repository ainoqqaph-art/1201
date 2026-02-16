# V3 設定說明

## 重要提示

此目錄用於存放**您提供的可運行 v6 腳本**。

## 設定步驟

### 1. 複製您的腳本

將您提供的可運行腳本複製到此目錄：
```
C:\自動化\google_trends_rewards_v6.py
```

複製到：
```
automation/v3_full_automation/google_trends_rewards_v6.py
```

### 2. 建立資料庫

執行資料庫建立腳本：
```sql
-- 位於 automation/database_setup_v3_new.sql
```

此腳本會建立：
- KeywordsMaster（含觸發器）
- KeywordsLog（含觸發器）
- DailyPointsLog（含觸發器）

### 3. 安裝相依套件

```bash
pip install -r requirements.txt
```

### 4. 確認 Edge WebDriver

腳本會自動檢測：
- Edge 瀏覽器版本
- msedgedriver.exe 版本
- 兼容性

如果版本不符，下載對應版本：
https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/

### 5. 執行

```bash
cd C:\自動化
python google_trends_rewards_v6.py
```

或使用批次檔：
```batch
run_automation_v3.bat
```

## 腳本特點

您提供的腳本包含以下優化：

1. **詳細的調試資訊**
   - 每一步都有詳細的輸出
   - 包含 [DEBUG]、[INFO]、[ERROR] 級別

2. **Edge WebDriver 診斷**（已整合）
   - 自動檢測版本
   - 兼容性警告
   - 詳細的錯誤提示

3. **重複次數邏輯**
   - 統計關鍵字在各地區的重複次數
   - 選擇重複最多的前 5 個（含並列）

4. **完整的錯誤處理**
   - 自動重試
   - 錯誤日誌記錄
   - Rollback 機制

## 診斷功能說明

腳本啟動時會自動執行以下檢查：

```
============================================================
系統環境檢查
============================================================
✓ Edge 瀏覽器路徑: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
✓ Edge 瀏覽器版本: 131.0.2903.51
✓ msedgedriver 路徑: C:\自動化\msedgedriver.exe
✓ msedgedriver 版本: 131.0.2903.51
✓ 版本兼容 (主版本皆為 131)
============================================================
```

如果發現問題，會顯示詳細的解決步驟。

## 資料流程

```
1. 抓取 Trends (9 regions × 25 keywords = 225)
   ↓
2. 去重 (通常剩 150-200)
   ↓
3. 統計重複次數
   ↓
4. 寫入 KeywordsMaster
   ↓
5. 選擇重複最多的前 5 個（含並列）
   ↓
6. Bing 搜尋這些關鍵字
   ↓
7. 寫入 KeywordsLog
   ↓
8. 抓取 Rewards 點數
   ↓
9. 寫入 DailyPointsLog
```

## 常見問題

### Q: 為什麼選擇「重複次數最多」的關鍵字？
A: 在多個地區都出現的關鍵字通常代表全球性熱門議題，更有價值。

### Q: 為什麼有些關鍵字重複次數相同也會被選中？
A: 這是設計特性。例如第5名有3個並列，全部都會被搜尋。

### Q: 如何調整搜尋數量？
A: 修改 `TOP_DUPLICATES = 5` 為其他數字。

### Q: 可以修改地區嗎？
A: 可以。編輯 `TRENDS_URLS` 列表，新增或移除地區。

## 進階設定

在腳本中可調整的參數：

```python
SQL_SERVER = 'localhost'          # 資料庫伺服器
SQL_DATABASE = 'MicrosoftRDB'     # 資料庫名稱
DRIVER_PATH = r"C:\自動化\msedgedriver.exe"  # WebDriver 路徑
EDGE_BINARY_PATH = None           # Edge 路徑（None=自動偵測）

KEYWORDS_PER_REGION = 25          # 每地區抓取數量
TOP_DUPLICATES = 5                # 搜尋前 N 個重複最多的

PER_KEYWORD_MIN = 10              # 關鍵字間隔（最小秒數）
PER_KEYWORD_MAX = 15              # 關鍵字間隔（最大秒數）
AFTER_KEYWORD_MIN = 10            # 關鍵字後休息（最小）
AFTER_KEYWORD_MAX = 20            # 關鍵字後休息（最大）
```

## 相關文件

- `/automation/database_setup_v3_new.sql` - 資料庫建立腳本
- `/automation/README_INDEX.md` - 版本總覽
- `/automation/VERSION_GUIDE.md` - 版本選擇指南
