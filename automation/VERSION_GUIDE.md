# 版本使用指南 - Google Trends / Microsoft Rewards 自動化工具

## 📋 版本概覽

本專案提供兩個版本的自動化工具，請根據您的需求選擇：

| 項目 | v1.x (舊版本) | v2.0 (新版本) |
|------|---------------|---------------|
| **主要功能** | Google Trends + Microsoft Rewards | Google Trends 專注版 |
| **關鍵字數量** | 每地區 5 個 | 每地區 20 個 |
| **搜尋量追蹤** | ❌ 無 | ✅ 有 |
| **Rewards 點數** | ✅ 有 | ❌ 無 |
| **地區支援** | 6 個地區 | 6 個地區 |
| **資料庫表** | 3 個（含 DailyPointsLog） | 2 個 |
| **適用場景** | 需要追蹤 Microsoft Rewards 點數 | 專注於關鍵字數據分析 |

---

## 🗂️ 檔案組織

### 主目錄
```
automation/
├── requirements.txt              # Python 套件（兩版本共用）
├── VERSION_GUIDE.md             # 本檔案：版本選擇指南
│
├── database_setup_v1_new.sql    # v1 版本：新建資料庫腳本
├── database_setup_v2_new.sql    # v2 版本：新建資料庫腳本
├── database_update.sql          # 從 v1 升級到 v2 的腳本
│
├── v1_microsoft_rewards/        # v1 版本（舊版）
│   ├── README.md                # v1 使用說明
│   ├── microsoft_rewards_automation.py  # v1 主程式
│   ├── config.template.py       # v1 設定範本
│   └── ...                      # 其他 v1 相關檔案
│
└── v2_google_trends/            # v2 版本（新版）
    ├── README_v2.md             # v2 使用說明
    ├── google_trends_automation.py     # v2 主程式
    ├── config.template.py       # v2 設定範本
    └── ...                      # 其他 v2 相關檔案
```

---

## 🎯 版本選擇建議

### 選擇 v1.x（舊版本），如果您：
- ✅ 需要追蹤 Microsoft Rewards 每日點數
- ✅ 想要同時進行 Bing 搜尋和點數累積
- ✅ 每個地區 5 個關鍵字已足夠
- ✅ 不需要關鍵字搜尋量數據

**位置**: `v1_microsoft_rewards/`  
**主程式**: `microsoft_rewards_automation.py`  
**資料庫**: 使用 `database_setup_v1_new.sql` 建立

### 選擇 v2.0（新版本），如果您：
- ✅ 專注於關鍵字趨勢分析
- ✅ 需要更多關鍵字（每地區 20 個）
- ✅ 需要追蹤關鍵字搜尋量
- ✅ 需要按地區和排名組織關鍵字
- ✅ 不需要 Microsoft Rewards 功能

**位置**: `v2_google_trends/`  
**主程式**: `google_trends_automation.py`  
**資料庫**: 使用 `database_setup_v2_new.sql` 建立

---

## 📦 新建資料庫腳本

### v1 新建資料庫
```sql
-- 在 SQL Server Management Studio 中執行
database_setup_v1_new.sql
```

**建立的表**：
- `KeywordsMaster` - 關鍵字主檔（UNIQUE(Keyword)）
- `KeywordsLog` - 搜尋記錄
- `DailyPointsLog` - 每日點數記錄

### v2 新建資料庫
```sql
-- 在 SQL Server Management Studio 中執行
database_setup_v2_new.sql
```

**建立的表**：
- `KeywordsMaster` - 關鍵字主檔（含 SearchVolume, Region, TrendRank，UNIQUE(Keyword, Region)）
- `KeywordsLog` - 搜尋記錄

**額外建立**：
- 5 個索引（提升查詢效能）
- 2 個視圖（vw_TodayKeywords, vw_TodaySearches）
- 2 個預存程序（sp_GetTopKeywordsByRegion, sp_GetSearchStats）

---

## 🔄 版本升級

### 從 v1 升級到 v2

如果您已經使用 v1，想要升級到 v2：

```sql
-- 在 SQL Server Management Studio 中執行
database_update.sql
```

此腳本會：
1. 為 KeywordsMaster 新增欄位（SearchVolume, Region, TrendRank）
2. 修改唯一約束從 UNIQUE(Keyword) 到 UNIQUE(Keyword, Region)
3. 更新觸發器
4. 建立索引、視圖和預存程序

**注意**：
- 不會刪除 DailyPointsLog 表（您的歷史數據保留）
- v2 程式不再使用 DailyPointsLog
- 舊的關鍵字數據會保留

---

## 🚀 快速開始

### v1 版本
```bash
cd v1_microsoft_rewards

# 1. 安裝 Python 套件
pip install -r ../requirements.txt

# 2. 建立資料庫（執行 SQL 腳本）
# 在 SSMS 中執行：database_setup_v1_new.sql

# 3. 設定 WebDriver 路徑
# 編輯 microsoft_rewards_automation.py 或 config.template.py

# 4. 執行程式
python microsoft_rewards_automation.py
```

### v2 版本
```bash
cd v2_google_trends

# 1. 安裝 Python 套件
pip install -r ../requirements.txt

# 2. 建立資料庫（執行 SQL 腳本）
# 在 SSMS 中執行：database_setup_v2_new.sql

# 3. 設定 WebDriver 路徑
# 編輯 google_trends_automation.py

# 4. 執行程式
python google_trends_automation.py
```

---

## 📊 功能對比詳細

### 資料庫欄位對比

#### KeywordsMaster 表

| 欄位 | v1.x | v2.0 |
|------|------|------|
| KeywordID | ✅ | ✅ |
| Keyword | ✅ | ✅ |
| Category | ✅ | ✅ |
| SearchIntent | ✅ | ✅ |
| SearchVolume | ❌ | ✅ 新增 |
| Region | ❌ | ✅ 新增 |
| TrendRank | ❌ | ✅ 新增 |
| CreatedAt | ✅ | ✅ |
| 唯一約束 | UNIQUE(Keyword) | UNIQUE(Keyword, Region) |

### 執行流程對比

#### v1.x 流程
```
1. 抓取 Google Trends 關鍵字
   └─ 6 個地區，每地區 5 個 = 共 30 個

2. Bing 搜尋（前 5 個關鍵字）
   └─ 間隔 30-90 秒

3. 抓取 Microsoft Rewards 點數
   └─ 記錄到 DailyPointsLog
```

#### v2.0 流程
```
1. 抓取 Google Trends 關鍵字 + 搜尋量
   └─ 6 個地區，每地區 20 個 = 共 120 個

2. Bing 搜尋（前 20 個關鍵字）
   └─ 間隔 30-90 秒
```

---

## ❓ 常見問題

### Q: 我應該選擇哪個版本？
**A**: 
- 如果需要 Microsoft Rewards 點數追蹤 → 選 v1
- 如果需要更多關鍵字和搜尋量數據 → 選 v2

### Q: 可以同時使用兩個版本嗎？
**A**: 技術上可以，但需要：
- 使用不同的資料庫，或
- 確保資料表結構相容

建議選擇一個版本使用。

### Q: 我已經在用 v1，如何升級到 v2？
**A**: 
1. 執行 `database_update.sql` 更新資料庫
2. 使用 `v2_google_trends/google_trends_automation.py`
3. 您的歷史數據會保留

### Q: v2 可以再加回 Rewards 功能嗎？
**A**: 可以，但需要：
1. 手動建立 DailyPointsLog 表
2. 將 v1 的 Rewards 相關函數加回 v2 程式
3. 或直接使用 v1 版本

### Q: 新建資料庫腳本和升級腳本有什麼區別？
**A**:
- `database_setup_v1_new.sql` / `database_setup_v2_new.sql`: 用於全新資料庫
- `database_update.sql`: 用於從現有 v1 資料庫升級到 v2

---

## 📞 技術支援

如有問題，請查閱：
- v1 說明文件：`v1_microsoft_rewards/README.md`
- v2 說明文件：`v2_google_trends/README_v2.md`
- v2 變更說明：`CHANGES_SUMMARY.md`

---

**建議**: 新用戶建議直接使用 v2.0 版本，功能更強大且維護更簡單。
