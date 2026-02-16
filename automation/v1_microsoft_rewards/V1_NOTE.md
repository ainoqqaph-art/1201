# Microsoft Rewards 自動化工具 v1.x

## ⚠️ 注意事項

此目錄包含 v1.x 版本的檔案和文件。

### 主程式狀態

由於 Git 歷史限制，舊版本的主程式 `microsoft_rewards_automation.py` 無法從版本控制中恢復。

### 如何獲得 v1 主程式

#### 選項 1：從 v2 反推（推薦）

如果您需要 v1 功能，可以從 v2 版本修改：

1. 複製 `../v2_google_trends/google_trends_automation.py`
2. 參考 `../CHANGES_SUMMARY.md` 中的變更說明
3. 加回以下功能：
   - `fetch_rewards_points()` 函數
   - `save_daily_points()` 函數
   - `--skip-rewards` 命令列參數
   - 步驟 3（Rewards 點數抓取）
4. 調整設定：
   - `KEYWORDS_PER_REGION = 5`
   - `TOP_N = 5`
   - 移除 `search_volume`, `region`, `trend_rank` 參數

#### 選項 2：使用 v2 版本（建議）

v2 版本功能更強大，建議直接使用 v2：
- 位置：`../v2_google_trends/`
- 主程式：`google_trends_automation.py`

如果您只是需要 Rewards 功能，可以手動將 Rewards 部分加回 v2 程式。

### 本目錄包含的檔案

- ✅ `README.md` - v1 使用說明（原始文件）
- ✅ `setup_database.sql` - v1 資料庫結構參考
- ✅ `query_examples.sql` - 查詢範例
- ✅ `requirements.txt` - Python 套件需求
- ✅ `V1_NOTE.md` - 本檔案
- ❌ `microsoft_rewards_automation.py` - **主程式不可用**

### 資料庫設定

使用主目錄的 `database_setup_v1_new.sql` 建立 v1 資料庫：

```bash
# 在 SQL Server Management Studio 中執行
cd ..
# 執行 database_setup_v1_new.sql
```

這會建立：
- KeywordsMaster 表（無 SearchVolume, Region, TrendRank 欄位）
- KeywordsLog 表
- DailyPointsLog 表（v1 特有）

### 建議

對於新用戶，我們強烈建議使用 v2 版本：
- 更多關鍵字（20 vs 5 每地區）
- 搜尋量追蹤
- 更好的資料組織（按地區和排名）
- 完整的程式碼可用

位置：`../v2_google_trends/`

---

如有任何問題，請參考 `../VERSION_GUIDE.md`
