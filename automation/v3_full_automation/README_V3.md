# Google Trends + Rewards 完整自動化 v3

## 版本說明

這是基於用戶提供的**可運行版本 v6**，整合了診斷功能的完整版本。

## 主要功能

1. **從 9 個地區抓取 Google Trends**
   - 每個地區抓取 25 個關鍵字
   - 總共最多 225 個關鍵字（去重後通常較少）

2. **統計重複次數**
   - 找出在多個地區都出現的關鍵字
   - 選擇重複最多的前 5 個（含並列）

3. **Bing 搜尋**
   - 對選中的關鍵字進行 Bing 搜尋
   - 擷取搜尋結果摘要

4. **Microsoft Rewards 點數追蹤**
   - 抓取當日可用點數
   - 記錄今日獲得點數

5. **Edge WebDriver 診斷**
   - 自動檢測 Edge 版本
   - 檢測 msedgedriver 版本
   - 版本兼容性檢查
   - 詳細的錯誤提示

## 資料庫結構

需要以下三個表：
- **KeywordsMaster**: 儲存所有關鍵字
- **KeywordsLog**: 儲存搜尋記錄
- **DailyPointsLog**: 儲存 Rewards 點數

請執行 `database_setup_v3_new.sql` 建立資料庫。

## 使用方式

```bash
# 完整執行（抓取 + 搜尋 + Rewards）
python google_trends_rewards_v6.py

# 跳過 Rewards
python google_trends_rewards_v6.py --no-rewards

# 只抓取關鍵字，不搜尋
python google_trends_rewards_v6.py --no-search

# 只抓取關鍵字
python google_trends_rewards_v6.py --no-search --no-rewards
```

## 重要檔案

- `google_trends_rewards_v6.py` - 主程式（用戶提供的可運行版本 + 診斷功能）
- `database_setup_v3_new.sql` - 資料庫建立腳本
- `config.py` - 設定檔（複製自 config.template.py）
- `requirements.txt` - Python 套件需求

## 相依套件

```
selenium>=4.0.0
pyodbc>=4.0.30
```

## 疑難排解

### Edge WebDriver 啟動失敗

程式會自動診斷並顯示詳細錯誤訊息：

1. **版本不符**
   - 檢查 Edge 版本：Edge → 設定 → 關於
   - 下載對應版本的 msedgedriver
   - 網址：https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/

2. **找不到 msedgedriver.exe**
   - 確認檔案位置：`C:\自動化\msedgedriver.exe`
   - 確認檔案有執行權限

3. **找不到 Edge 瀏覽器**
   - 程式會自動偵測常見路徑
   - 如失敗，請在程式中設定 `EDGE_BINARY_PATH`

## 與其他版本的比較

| 功能 | v1 | v2 | v3 (本版本) |
|------|----|----|-------------|
| 地區數 | 6 | 6 | 9 |
| 每地區關鍵字數 | 5 | 20 | 25 |
| 搜尋策略 | 前N個 | 前N個 | 重複次數最多的前N個 |
| Rewards | ✅ | ❌ | ✅ |
| 診斷功能 | ❌ | ✅ | ✅ |
| 調試資訊 | 基本 | 詳細 | 非常詳細 |

## 注意事項

1. 此版本基於用戶確認**可以運行**的腳本
2. 整合了 Edge WebDriver 診斷功能
3. 提供詳細的調試輸出
4. 所有 ID 由 Python 管理（無 IDENTITY）

## 執行時間

- 抓取關鍵字：約 5-10 分鐘（9 個地區）
- Bing 搜尋：約 2-5 分鐘（依關鍵字數量）
- Rewards：約 10-20 秒
- **總計：約 8-16 分鐘**
