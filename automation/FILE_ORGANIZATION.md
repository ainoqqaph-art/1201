# 檔案組織總覽

## 📁 完整目錄結構

```
automation/
│
├── 📄 README_INDEX.md                    # 主索引（從這裡開始！）
├── 📘 VERSION_GUIDE.md                   # 版本選擇指南（必讀）
│
├── 📦 共用檔案
│   ├── requirements.txt                  # Python 套件需求
│   ├── config.template.py                # 設定範本（舊版）
│   └── run_automation.bat                # 執行批次檔（舊版）
│
├── 🗄️ 資料庫腳本（新建資料庫用）
│   ├── database_setup_v1_new.sql         # v1 完整資料庫建立腳本 ⭐
│   ├── database_setup_v2_new.sql         # v2 完整資料庫建立腳本 ⭐
│   └── database_update.sql               # v1 → v2 升級腳本
│
├── 📂 v1_microsoft_rewards/              # v1 版本目錄（舊版）
│   │
│   ├── 📄 V1_NOTE.md                     # ⚠️ 重要：v1 使用說明與限制
│   ├── 📘 README.md                      # v1 使用文件
│   │
│   ├── 🗄️ setup_database.sql             # v1 資料庫結構參考
│   ├── 📊 query_examples.sql             # SQL 查詢範例
│   └── 📦 requirements.txt               # Python 套件需求
│
└── 📂 v2_google_trends/                  # v2 版本目錄（新版）✨
    │
    ├── 🐍 google_trends_automation.py    # v2 主程式 ⭐
    │
    ├── 📘 README_v2.md                   # v2 使用說明
    ├── 📄 CHANGES_SUMMARY.md             # 詳細變更說明
    ├── 📄 MULTI_REGION_UPDATE.md         # 多地區更新說明
    │
    ├── ⚙️ config.template.py              # 設定範本
    ├── 🪟 run_automation_v2.bat           # Windows 批次檔
    └── 📦 requirements.txt                # Python 套件需求
```

## 🎯 檔案用途說明

### 入口文件

| 檔案 | 用途 | 優先級 |
|------|------|--------|
| `README_INDEX.md` | 主索引，快速導航 | ⭐⭐⭐ |
| `VERSION_GUIDE.md` | 版本選擇與對比 | ⭐⭐⭐ |

### 資料庫腳本（⭐ 新增）

| 檔案 | 用途 | 使用時機 |
|------|------|----------|
| `database_setup_v1_new.sql` | 建立 v1 完整資料庫 | 新建 v1 資料庫 |
| `database_setup_v2_new.sql` | 建立 v2 完整資料庫 | 新建 v2 資料庫 |
| `database_update.sql` | v1 升級到 v2 | 已有 v1 資料庫 |

### v1 版本檔案

| 檔案 | 說明 |
|------|------|
| `V1_NOTE.md` | ⚠️ 重要：說明 v1 主程式無法使用的原因與解決方案 |
| `README.md` | v1 原始使用文件 |
| `setup_database.sql` | v1 資料庫結構參考（註解格式） |
| `query_examples.sql` | SQL 查詢範例 |

### v2 版本檔案

| 檔案 | 說明 |
|------|------|
| `google_trends_automation.py` | ⭐ v2 主程式（可直接執行） |
| `README_v2.md` | v2 完整使用說明 |
| `CHANGES_SUMMARY.md` | v1→v2 變更詳情與範例 |
| `MULTI_REGION_UPDATE.md` | 多地區支援更新說明 |
| `config.template.py` | 設定檔範本 |
| `run_automation_v2.bat` | Windows 批次執行檔 |

## 🚀 使用流程

### 新用戶（推薦 v2）

```
1. 📘 閱讀 VERSION_GUIDE.md
   └─> 確認選擇 v2 版本

2. 🗄️ 執行 database_setup_v2_new.sql
   └─> 建立完整的 v2 資料庫

3. 📂 進入 v2_google_trends/
   └─> 閱讀 README_v2.md

4. 🐍 執行 google_trends_automation.py
   └─> 開始使用！
```

### v1 用戶

```
1. 📘 閱讀 VERSION_GUIDE.md
   └─> 了解 v1 限制

2. ⚠️ 閱讀 v1_microsoft_rewards/V1_NOTE.md
   └─> 了解主程式無法使用的問題

3. 💡 考慮升級到 v2
   └─> 執行 database_update.sql
   └─> 使用 v2_google_trends/google_trends_automation.py
```

### 從 v1 升級到 v2

```
1. 🗄️ 執行 database_update.sql
   └─> 升級資料庫結構

2. 📂 進入 v2_google_trends/
   └─> 使用新程式

3. ✅ 歷史數據保留
   └─> DailyPointsLog 不會被刪除
```

## 📊 重要檔案標記

### ⭐ 必須閱讀
- `README_INDEX.md` - 從這裡開始
- `VERSION_GUIDE.md` - 選擇版本

### ⭐ 新建資料庫必須
- `database_setup_v1_new.sql` - v1 用戶
- `database_setup_v2_new.sql` - v2 用戶

### ⭐ 可執行程式
- `v2_google_trends/google_trends_automation.py` - v2 主程式

### ⚠️ 重要警告
- `v1_microsoft_rewards/V1_NOTE.md` - v1 限制說明

## 🎨 檔案分類

### 文件類
```
📘 使用指南
📄 說明文件
⚠️ 警告/注意事項
```

### 程式類
```
🐍 Python 腳本
🗄️ SQL 腳本
⚙️ 設定檔
🪟 批次檔
```

### 資源類
```
📦 套件需求
📊 查詢範例
```

## 💡 快速參考

**我想開始使用** → `README_INDEX.md`

**我要選擇版本** → `VERSION_GUIDE.md`

**我要建立新資料庫（v1）** → `database_setup_v1_new.sql`

**我要建立新資料庫（v2）** → `database_setup_v2_new.sql`

**我要升級 v1→v2** → `database_update.sql`

**我要使用 v2** → `v2_google_trends/google_trends_automation.py`

**我對 v1 有疑問** → `v1_microsoft_rewards/V1_NOTE.md`

---

**建議：新用戶直接使用 v2 版本獲得最佳體驗！** ✨
