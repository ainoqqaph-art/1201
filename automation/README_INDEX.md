# Google Trends / Microsoft Rewards 自動化工具

這個專案提供兩個版本的自動化工具，用於抓取 Google Trends 關鍵字並進行 Bing 搜尋。

## 🎯 快速選擇

### 我需要追蹤 Microsoft Rewards 點數
→ 使用 **v1 版本**（位於 `v1_microsoft_rewards/`）
- ⚠️ 注意：v1 主程式因 Git 歷史限制無法使用，請參考 `v1_microsoft_rewards/V1_NOTE.md`

### 我需要更多關鍵字和搜尋量數據
→ 使用 **v2 版本**（位於 `v2_google_trends/`）✨ **推薦**
- ✅ 每地區 20 個關鍵字（vs v1 的 5 個）
- ✅ 搜尋量追蹤
- ✅ 完整程式碼可用

## 📁 目錄結構

```
automation/
│
├── 📘 VERSION_GUIDE.md              ← 從這裡開始！詳細版本對比
│
├── 🗄️ 資料庫腳本
│   ├── database_setup_v1_new.sql   # v1 新建資料庫（含 DailyPointsLog）
│   ├── database_setup_v2_new.sql   # v2 新建資料庫（含索引、視圖、預存程序）
│   └── database_update.sql         # v1 → v2 升級腳本
│
├── 📦 v1_microsoft_rewards/         # v1 版本（舊版）
│   ├── V1_NOTE.md                  # ⚠️ 重要：v1 使用說明
│   ├── README.md                   # v1 文件
│   └── ...
│
└── 📦 v2_google_trends/             # v2 版本（新版）✨
    ├── google_trends_automation.py # 主程式
    ├── README_v2.md                # 使用說明
    ├── CHANGES_SUMMARY.md          # 變更摘要
    └── ...
```

## 🚀 快速開始

### 步驟 1：選擇版本

請先閱讀 **`VERSION_GUIDE.md`** 了解兩個版本的差異並選擇適合您的版本。

### 步驟 2：設定資料庫

#### 使用 v2（推薦）
```sql
-- 在 SQL Server Management Studio 中執行
database_setup_v2_new.sql
```

#### 使用 v1
```sql
-- 在 SQL Server Management Studio 中執行
database_setup_v1_new.sql
```

### 步驟 3：執行程式

#### v2 版本
```bash
cd v2_google_trends
pip install -r requirements.txt
python google_trends_automation.py
```

#### v1 版本
```bash
cd v1_microsoft_rewards
# ⚠️ 請先閱讀 V1_NOTE.md
```

## 📊 版本對比

| 功能 | v1.x | v2.0 |
|------|------|------|
| 關鍵字數量 | 每地區 5 個 | 每地區 20 個 ✨ |
| 搜尋量追蹤 | ❌ | ✅ |
| Rewards 點數 | ✅ | ❌ |
| 地區追蹤 | 基本 | 完整（Region, TrendRank） |
| 資料庫索引 | 無 | 5 個索引 |
| 視圖/預存程序 | 無 | 2 視圖 + 2 預存程序 |
| 主程式可用性 | ⚠️ 不可用 | ✅ 完整可用 |

## 📚 詳細文件

- **VERSION_GUIDE.md** - 完整的版本選擇指南（必讀）
- **v1_microsoft_rewards/README.md** - v1 使用說明
- **v1_microsoft_rewards/V1_NOTE.md** - v1 重要注意事項
- **v2_google_trends/README_v2.md** - v2 使用說明
- **v2_google_trends/CHANGES_SUMMARY.md** - v2 變更詳情

## 🔄 升級路徑

### 從 v1 升級到 v2

如果您已經在使用 v1 並想升級：

```sql
-- 執行升級腳本
database_update.sql
```

然後使用 v2 程式：
```bash
cd v2_google_trends
python google_trends_automation.py
```

**注意**：升級後您的歷史數據會保留，但 v2 不再使用 DailyPointsLog 表。

## 💡 建議

### 新用戶
→ 直接使用 **v2 版本**
- 功能更強大
- 資料更豐富
- 完整程式碼可用

### 需要 Rewards 功能的用戶
→ 可以考慮：
1. 使用 v2 並手動加回 Rewards 功能
2. 參考 v1 文件自行實作

## ❓ 需要幫助？

1. **選擇版本** → 閱讀 `VERSION_GUIDE.md`
2. **資料庫設定** → 查看對應的 `database_setup_*.sql`
3. **使用說明** → 查看對應版本目錄中的 README
4. **v1 不可用問題** → 閱讀 `v1_microsoft_rewards/V1_NOTE.md`

## 📞 技術支援

如有問題，請查閱：
- `VERSION_GUIDE.md` - 版本對比與選擇
- `v2_google_trends/README_v2.md` - v2 詳細文件
- `v2_google_trends/CHANGES_SUMMARY.md` - 變更說明與範例

---

**推薦使用 v2 版本獲得最佳體驗！** ✨
