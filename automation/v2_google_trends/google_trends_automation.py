# -*- coding: utf-8 -*-
#!/usr/bin/env python
"""
Google Trends 關鍵字自動化抓取與搜尋（單次執行版）：
1) 從多個地區抓取 Google Trends 熱門關鍵字（每個地區前 20 名）
2) 針對抓取到的關鍵字在 Bing 做搜尋並擷取摘要（每關鍵字間隔 30-90 秒）
3) 儲存關鍵字、搜尋量、排名等資訊到 SQL Server 資料庫
4) 使用 Windows Authentication 連接 SQL Server
說明：此檔為「單次執行」版本，適合由 Windows Task Scheduler 或其他排程工具呼叫。
"""

import argparse
import time
import random
import pyodbc
import json
import os
import subprocess
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.edge.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from datetime import datetime
import logging

# ==================== 設定區 ====================
SQL_SERVER = 'localhost'
SQL_DATABASE = 'MicrosoftRDB'
DRIVER_PATH = r"C:\自動化\msedgedriver.exe"

# Edge 瀏覽器路徑（可選，通常可自動偵測）
# 如果自動偵測失敗，請手動設定，例如：
# EDGE_BINARY_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_BINARY_PATH = None  # None 表示自動偵測

# Google Trends URL（多個地區）
TRENDS_URLS = [
    "https://trends.google.com.tw/trending?geo=US",   # 美國
    "https://trends.google.com.tw/trending?geo=TW",   # 台灣
    "https://trends.google.com.tw/trending?geo=JP",   # 日本
    "https://trends.google.com.tw/trending?geo=GB",   # 英國
    "https://trends.google.com.tw/trending?geo=HK",   # 香港
    "https://trends.google.com.tw/trending?geo=AU",   # 澳洲
]

# 每個地區抓取的關鍵字數量
KEYWORDS_PER_REGION = 20

# 前 N 名關鍵字要做額外搜尋（從所有地區總共選取）
TOP_N = 20

# 前 20 名關鍵字搜尋間隔（秒）
PER_KEYWORD_MIN = 30
PER_KEYWORD_MAX = 90

# 每完成所有關鍵字後的額外休息（秒）
AFTER_ALL_KEYWORDS_MIN = 120  # 2 minutes
AFTER_ALL_KEYWORDS_MAX = 300  # 5 minutes

# 每完成一個關鍵字後的額外休息（秒）
AFTER_KEYWORD_MIN = 10
AFTER_KEYWORD_MAX = 20

# 重試與退避設定
MAX_RETRIES = 3
INITIAL_BACKOFF = 2  # 秒

# Edge profile 設定（選用）
# 如需使用已登入的 Edge 設定檔，可取消註解並設定路徑
EDGE_USER_DATA_DIR = None  # r"C:\Users\YourUsername\AppData\Local\Microsoft\Edge\User Data"
EDGE_PROFILE = None  # "Default" 或 "Profile 1" 等

# ==================== 日誌設定 ====================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('google_trends_automation.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


# ==================== 資料庫操作 ====================
def get_db_connection():
    """
    建立 SQL Server 連線（使用 Windows Authentication）
    """
    try:
        conn_str = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={SQL_SERVER};"
            f"DATABASE={SQL_DATABASE};"
            f"Trusted_Connection=yes;"
        )
        conn = pyodbc.connect(conn_str)
        logger.info("成功連接到 SQL Server")
        return conn
    except Exception as e:
        logger.error(f"資料庫連接失敗: {e}")
        raise


def get_or_create_keyword_id(conn, keyword, category=None, search_intent=None, search_volume=None, region=None, trend_rank=None):
    """
    取得或建立關鍵字 ID
    如果關鍵字已存在於 KeywordsMaster（同一關鍵字同一地區），返回其 ID
    如果不存在，插入新記錄並返回新 ID
    """
    try:
        cursor = conn.cursor()
        
        # 先查詢是否已存在（同一關鍵字同一地區）
        cursor.execute("SELECT KeywordID FROM KeywordsMaster WHERE Keyword = ? AND Region = ?", (keyword, region))
        row = cursor.fetchone()
        
        if row:
            keyword_id = row[0]
            logger.debug(f"關鍵字已存在: {keyword} ({region}) (ID: {keyword_id})")
            return keyword_id
        
        # 不存在則插入（觸發器會自動處理 KeywordID）
        cursor.execute("""
            INSERT INTO KeywordsMaster (KeywordID, Keyword, Category, SearchIntent, SearchVolume, Region, TrendRank, CreatedAt)
            VALUES (0, ?, ?, ?, ?, ?, ?, GETDATE())
        """, (keyword, category, search_intent, search_volume, region, trend_rank))
        conn.commit()
        
        # 重新查詢以取得觸發器生成的 ID
        cursor.execute("SELECT KeywordID FROM KeywordsMaster WHERE Keyword = ? AND Region = ?", (keyword, region))
        row = cursor.fetchone()
        keyword_id = row[0]
        
        logger.info(f"新增關鍵字: {keyword} ({region}) 排名#{trend_rank} 搜尋量:{search_volume} (ID: {keyword_id})")
        return keyword_id
        
    except Exception as e:
        logger.error(f"處理關鍵字失敗: {e}")
        conn.rollback()
        raise


def save_keyword_log(conn, keyword_id, log_date, summary_text=None, status='Success', 
                     screenshot_path=None, error_message=None):
    """
    將關鍵字搜尋記錄寫入 KeywordsLog
    """
    try:
        cursor = conn.cursor()
        
        # 插入記錄（觸發器會自動處理 LogID）
        cursor.execute("""
            INSERT INTO KeywordsLog 
            (LogID, KeywordID, LogDate, CrawlTime, SummaryText, Status, ScreenshotPath, ErrorMessage, CreatedAt)
            VALUES (0, ?, ?, GETDATE(), ?, ?, ?, ?, GETDATE())
        """, (keyword_id, log_date, summary_text, status, screenshot_path, error_message))
        
        conn.commit()
        logger.info(f"已記錄關鍵字搜尋: KeywordID={keyword_id}, Status={status}")
        
    except Exception as e:
        logger.error(f"儲存關鍵字記錄失敗: {e}")
        conn.rollback()
        raise




# ==================== Selenium 操作 ====================
def get_edge_version():
    """取得 Edge 瀏覽器版本"""
    try:
        # 常見的 Edge 安裝路徑
        edge_paths = [
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        ]
        
        for edge_path in edge_paths:
            if os.path.exists(edge_path):
                result = subprocess.run(
                    [edge_path, '--version'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    version = result.stdout.strip().split()[-1]
                    return version, edge_path
        return None, None
    except Exception as e:
        logger.warning(f"無法取得 Edge 版本: {e}")
        return None, None


def get_driver_version():
    """取得 msedgedriver 版本"""
    try:
        if not os.path.exists(DRIVER_PATH):
            return None
        
        result = subprocess.run(
            [DRIVER_PATH, '--version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            version = result.stdout.strip().split()[1]
            return version
        return None
    except Exception as e:
        logger.warning(f"無法取得 msedgedriver 版本: {e}")
        return None


def check_driver_compatibility():
    """檢查 Edge 和 msedgedriver 的版本兼容性"""
    edge_version, edge_path = get_edge_version()
    driver_version = get_driver_version()
    
    logger.info("=" * 60)
    logger.info("系統環境檢查")
    logger.info("=" * 60)
    
    if edge_path:
        logger.info(f"✓ Edge 瀏覽器路徑: {edge_path}")
    else:
        logger.error("✗ 找不到 Edge 瀏覽器")
        
    if edge_version:
        logger.info(f"✓ Edge 瀏覽器版本: {edge_version}")
    else:
        logger.error("✗ 無法取得 Edge 版本")
    
    if os.path.exists(DRIVER_PATH):
        logger.info(f"✓ msedgedriver 路徑: {DRIVER_PATH}")
    else:
        logger.error(f"✗ msedgedriver 不存在: {DRIVER_PATH}")
        
    if driver_version:
        logger.info(f"✓ msedgedriver 版本: {driver_version}")
    else:
        logger.error("✗ 無法取得 msedgedriver 版本")
    
    # 檢查版本兼容性
    if edge_version and driver_version:
        edge_major = edge_version.split('.')[0]
        driver_major = driver_version.split('.')[0]
        
        if edge_major == driver_major:
            logger.info(f"✓ 版本兼容 (主版本皆為 {edge_major})")
        else:
            logger.warning(f"⚠ 版本可能不兼容！")
            logger.warning(f"  Edge 主版本: {edge_major}")
            logger.warning(f"  Driver 主版本: {driver_major}")
            logger.warning(f"  建議：下載與 Edge {edge_version} 相符的 msedgedriver")
            logger.warning(f"  下載網址：https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/")
    
    logger.info("=" * 60)
    
    return edge_version, driver_version, edge_path


def create_edge_driver():
    """
    建立 Edge WebDriver（增強版，包含自動路徑偵測和詳細錯誤診斷）
    """
    import os
    import subprocess
    
    # 首先進行版本兼容性檢查
    edge_version, driver_version, edge_path = check_driver_compatibility()
    
    options = webdriver.EdgeOptions()
    
    # ★ 關鍵修復：自動設定 Edge 瀏覽器路徑
    if EDGE_BINARY_PATH:
        # 使用用戶指定的路徑
        if os.path.exists(EDGE_BINARY_PATH):
            options.binary_location = EDGE_BINARY_PATH
            logger.info(f"使用指定的 Edge 路徑: {EDGE_BINARY_PATH}")
        else:
            logger.error(f"指定的 Edge 路徑不存在: {EDGE_BINARY_PATH}")
            raise FileNotFoundError(f"Edge 瀏覽器不存在於: {EDGE_BINARY_PATH}")
    elif edge_path:
        # 使用自動偵測的路徑
        options.binary_location = edge_path
        logger.info(f"使用自動偵測的 Edge 路徑: {edge_path}")
    else:
        # 讓 Selenium 自動尋找（可能失敗）
        logger.warning("未設定 Edge 路徑，Selenium 將嘗試自動尋找...")
        logger.warning("如果啟動失敗，請在設定檔中設定 EDGE_BINARY_PATH")
    
    # 若需使用特定 profile
    if EDGE_USER_DATA_DIR and EDGE_PROFILE:
        options.add_argument(f"--user-data-dir={EDGE_USER_DATA_DIR}")
        options.add_argument(f"--profile-directory={EDGE_PROFILE}")
    
    # 其他常用選項 - 增加穩定性
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    
    # 增加額外的選項以提高穩定性
    options.add_argument("--disable-gpu")  # 禁用 GPU 加速
    options.add_argument("--no-sandbox")  # 在某些環境下需要
    options.add_argument("--disable-dev-shm-usage")  # 解決資源限制問題
    options.add_argument("--disable-extensions")  # 禁用擴充功能
    options.add_argument("--window-size=1920,1080")  # 設定視窗大小
    options.add_argument("--disable-web-security")  # 有時可以解決某些問題
    options.add_argument("--allow-running-insecure-content")  # 允許不安全內容
    
    # 設定頁面載入策略
    options.page_load_strategy = 'normal'  # 等待完整頁面載入
    
    try:
        logger.info("正在啟動 Edge WebDriver...")
        service = Service(DRIVER_PATH)
        
        # 增加服務日誌以便診斷
        service.log_path = "msedgedriver.log"
        
        driver = webdriver.Edge(service=service, options=options)
        
        # 設定隱式等待
        driver.implicitly_wait(10)
        
        # 設定頁面載入超時
        driver.set_page_load_timeout(60)
        
        logger.info("✓ Edge WebDriver 已成功啟動")
        return driver
        
    except Exception as e:
        logger.error("=" * 80)
        logger.error("✗ 啟動 Edge WebDriver 失敗！")
        logger.error("=" * 80)
        logger.error(f"錯誤訊息: {e}")
        logger.error("")
        logger.error("可能的原因和解決方法：")
        logger.error("")
        
        if "Chrome instance exited" in str(e) or "session not created" in str(e):
            logger.error("1. msedgedriver 版本與 Edge 瀏覽器版本不匹配")
            logger.error("   解決方法：")
            logger.error("   - 檢查 Edge 版本與 msedgedriver 版本（上面已顯示）")
            logger.error("   - 下載相符版本的 msedgedriver：")
            logger.error("     https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/")
            logger.error("")
            logger.error("2. Edge 瀏覽器路徑設定問題")
            logger.error("   解決方法：")
            logger.error("   - 在設定檔中手動設定 EDGE_BINARY_PATH")
            logger.error("   - 例如：EDGE_BINARY_PATH = r'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'")
            logger.error("")
        
        logger.error("3. msedgedriver.exe 不存在或路徑錯誤")
        logger.error(f"   當前設定路徑: {DRIVER_PATH}")
        logger.error(f"   檔案是否存在: {os.path.exists(DRIVER_PATH) if os.path.exists(os.path.dirname(DRIVER_PATH)) else '目錄不存在'}")
        logger.error("")
        
        logger.error("4. 權限問題")
        logger.error("   解決方法：以系統管理員身分執行")
        logger.error("")
        
        logger.error("詳細錯誤日誌已儲存至: msedgedriver.log")
        logger.error("=" * 80)
        
        raise


def fetch_google_trends(driver):
    """
    抓取 Google Trends 熱門關鍵字（從多個地區）
    返回: list of dict [{'keyword': str, 'rank': int, 'region': str}, ...]
    """
    all_keywords = []
    
    for region_url in TRENDS_URLS:
        # 從 URL 提取地區代碼
        region_code = region_url.split('geo=')[-1].split('&')[0] if 'geo=' in region_url else 'Unknown'
        logger.info(f"正在抓取 {region_code} 地區的 Google Trends...")
        
        keywords = fetch_trends_from_url(driver, region_url, region_code)
        all_keywords.extend(keywords)
        
        # 每個地區之間稍作休息
        if region_url != TRENDS_URLS[-1]:  # 不是最後一個
            time.sleep(2)
    
    logger.info(f"總共從 {len(TRENDS_URLS)} 個地區抓取到 {len(all_keywords)} 個關鍵字")
    
    # 如果需要限制總數，取前 TOP_N 個（如果設定了全局限制）
    # 否則返回所有關鍵字
    return all_keywords


def fetch_trends_from_url(driver, url, region_code):
    """
    從特定 URL 抓取 Google Trends 關鍵字
    返回: list of dict [{'keyword': str, 'rank': int, 'region': str}, ...]
    """
    keywords = []
    retries = 0
    
    while retries < MAX_RETRIES:
        try:
            logger.info(f"正在抓取 {region_code}... (嘗試 {retries + 1}/{MAX_RETRIES})")
            driver.get(url)
            
            # 增加等待時間以確保頁面完全載入
            time.sleep(5)
            
            # 嘗試多種可能的選擇器策略
            trend_items = []
            
            # 策略 1: 嘗試使用 table 結構
            try:
                wait = WebDriverWait(driver, 15)
                # Google Trends Daily 使用 table 結構
                wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "tbody tr, div.feed-item")))
                
                # 先嘗試 table
                trend_items = driver.find_elements(By.CSS_SELECTOR, "tbody tr")
                if trend_items:
                    logger.info(f"策略 1 (table): 找到 {len(trend_items)} 個項目")
                else:
                    # 嘗試 feed-item
                    trend_items = driver.find_elements(By.CSS_SELECTOR, "div.feed-item")
                    logger.info(f"策略 2 (feed-item): 找到 {len(trend_items)} 個項目")
                    
            except Exception as e1:
                logger.warning(f"策略 1-2 失敗: {e1}")
                
                # 策略 3: 嘗試使用更通用的選擇器
                try:
                    trend_items = driver.find_elements(By.CSS_SELECTOR, "[class*='trending'], [class*='trend-item'], .trending-item")
                    logger.info(f"策略 3 (通用): 找到 {len(trend_items)} 個項目")
                except Exception as e2:
                    logger.warning(f"策略 3 失敗: {e2}")
                    
                    # 策略 4: 儲存截圖並嘗試 JSON
                    try:
                        screenshot_path = f"debug_trends_{region_code}_{retries + 1}.png"
                        driver.save_screenshot(screenshot_path)
                        logger.info(f"已儲存截圖: {screenshot_path}")
                        
                        page_source = driver.page_source
                        logger.debug(f"頁面長度: {len(page_source)} 字元")
                        
                        # 如果是 JSON API endpoint
                        if "application/json" in page_source or page_source.strip().startswith('{'):
                            try:
                                pre_element = driver.find_element(By.TAG_NAME, "pre")
                                json_data = json.loads(pre_element.text)
                                logger.info("成功解析 JSON 資料")
                                
                                if isinstance(json_data, dict) and 'default' in json_data:
                                    trending_searches = json_data.get('default', {}).get('trendingSearchesDays', [])
                                    if trending_searches:
                                         for search in trending_searches[0].get('trendingSearches', [])[:KEYWORDS_PER_REGION]:
                                            keyword = search.get('title', {}).get('query', '')
                                            # 嘗試抓取搜尋量
                                            search_volume = search.get('formattedTraffic', '') or search.get('traffic', '')
                                            if not search_volume:
                                                # 嘗試從其他可能的欄位取得
                                                search_volume = search.get('shareUrl', '').split('/')[-1] if search.get('shareUrl') else ''
                                            
                                            if keyword:
                                                keywords.append({
                                                    'keyword': keyword, 
                                                    'rank': len(keywords) + 1,
                                                    'region': region_code,
                                                    'search_volume': search_volume if search_volume else 'N/A'
                                                })
                                                logger.info(f"發現關鍵字 ({region_code}) #{len(keywords)}: {keyword} (搜尋量: {search_volume})")
                            except (json.JSONDecodeError, Exception) as json_err:
                                logger.error(f"JSON 處理失敗: {json_err}")
                    except Exception as e3:
                        logger.error(f"策略 4 失敗: {e3}")
            
            # 如果已經從 JSON 獲取到關鍵字，直接返回
            if keywords:
                logger.info(f"從 {region_code} 成功抓取 {len(keywords)} 個關鍵字")
                return keywords
            
            # 否則從 HTML 元素抓取
            if not trend_items:
                raise Exception(f"所有選擇器策略都失敗，無法找到 {region_code} 的趨勢項目")
            
            # 從找到的元素中提取關鍵字和搜尋量
            for idx, item in enumerate(trend_items[:KEYWORDS_PER_REGION], 1):
                try:
                    keyword_element = None
                    keyword = None
                    search_volume = 'N/A'
                    
                    # 針對不同結構的選擇器
                    selectors = [
                        "td a",  # table cell with link
                        "a",     # any link
                        "div.title a",
                        "div.mdc-layout-grid__cell span",
                        "a.title",
                        "span.title",
                        "td",    # plain table cell
                        ".description-text",
                        ".title-text",
                    ]
                    
                    for selector in selectors:
                        try:
                            keyword_element = item.find_element(By.CSS_SELECTOR, selector)
                            keyword = keyword_element.text.strip()
                            if keyword:
                                break
                        except:
                            continue
                    
                    # 如果還是沒找到，嘗試直接取元素文字
                    if not keyword:
                        keyword = item.text.strip()
                        # 取第一行作為關鍵字
                        if '\n' in keyword:
                            lines = keyword.split('\n')
                            keyword = lines[0].strip()
                            # 嘗試從其他行取得搜尋量
                            for line in lines[1:]:
                                line = line.strip()
                                if line and ('+' in line or 'K' in line.upper() or 'M' in line.upper() or line[0].isdigit()):
                                    search_volume = line
                                    break
                    
                    # 嘗試從同一個 item 元素中尋找搜尋量
                    if search_volume == 'N/A':
                        volume_selectors = [
                            ".search-count",
                            ".traffic-count", 
                            "span.count",
                            "div[class*='traffic']",
                            "div[class*='search']",
                            "span[class*='count']"
                        ]
                        for vol_selector in volume_selectors:
                            try:
                                vol_element = item.find_element(By.CSS_SELECTOR, vol_selector)
                                vol_text = vol_element.text.strip()
                                if vol_text and ('+' in vol_text or 'K' in vol_text.upper() or 'M' in vol_text.upper() or vol_text[0].isdigit()):
                                    search_volume = vol_text
                                    break
                            except:
                                continue
                    
                    if keyword and len(keyword) > 0:
                        keywords.append({
                            'keyword': keyword, 
                            'rank': idx,
                            'region': region_code,
                            'search_volume': search_volume
                        })
                        logger.info(f"發現關鍵字 ({region_code}) #{idx}: {keyword} (搜尋量: {search_volume})")
                except Exception as e:
                    logger.warning(f"抓取第 {idx} 個關鍵字失敗: {e}")
                    continue
            
            if keywords:
                logger.info(f"從 {region_code} 成功抓取 {len(keywords)} 個關鍵字")
                return keywords
            else:
                raise Exception(f"未能從 {region_code} 抓取到任何關鍵字")
                
        except Exception as e:
            retries += 1
            logger.error(f"抓取 {region_code} Google Trends 失敗: {e}")
            
            # 儲存錯誤時的截圖
            try:
                screenshot_path = f"error_trends_{region_code}_{retries}.png"
                driver.save_screenshot(screenshot_path)
                logger.info(f"錯誤截圖已儲存: {screenshot_path}")
            except:
                pass
            
            if retries < MAX_RETRIES:
                backoff = INITIAL_BACKOFF * (2 ** (retries - 1))
                logger.info(f"等待 {backoff} 秒後重試...")
                time.sleep(backoff)
            else:
                logger.error(f"已達到最大重試次數，{region_code} 抓取失敗")
                # 為這個地區返回空列表，繼續其他地區
                return []
    
    return keywords


def search_bing_keyword(driver, keyword):
    """
    在 Bing 搜尋特定關鍵字並擷取摘要
    """
    try:
        logger.info(f"正在 Bing 搜尋: {keyword}")
        
        # 前往 Bing
        driver.get("https://www.bing.com")
        time.sleep(2)
        
        # 尋找搜尋框
        search_box = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.NAME, "q"))
        )
        
        # 清空並輸入關鍵字
        search_box.clear()
        search_box.send_keys(keyword)
        search_box.send_keys(Keys.RETURN)
        
        # 等待搜尋結果載入
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "b_results"))
        )
        
        logger.info(f"已完成搜尋: {keyword}")
        
        # 擷取搜尋結果摘要
        summary_text = None
        try:
            results = driver.find_elements(By.CSS_SELECTOR, "li.b_algo")
            if results:
                # 收集前 3 個結果的摘要
                summaries = []
                for i, result in enumerate(results[:3], 1):
                    try:
                        title = result.find_element(By.CSS_SELECTOR, "h2").text
                        desc = result.find_element(By.CSS_SELECTOR, "p, .b_caption p").text
                        summaries.append(f"[{i}] {title}: {desc[:100]}...")
                    except:
                        continue
                
                if summaries:
                    summary_text = "\n".join(summaries)
                    logger.info(f"擷取到 {len(summaries)} 個搜尋結果")
        except Exception as e:
            logger.warning(f"擷取摘要失敗: {e}")
        
        return summary_text
        
    except Exception as e:
        logger.error(f"Bing 搜尋失敗 ({keyword}): {e}")
        raise



# ==================== 主流程 ====================
def main():
    """
    主執行流程
    """
    parser = argparse.ArgumentParser(description='Google Trends 關鍵字自動化抓取工具（單次執行版）')
    parser.add_argument('--dry-run', action='store_true', help='測試模式，不寫入資料庫')
    parser.add_argument('--skip-trends', action='store_true', help='跳過 Google Trends 抓取')
    parser.add_argument('--skip-search', action='store_true', help='跳過 Bing 搜尋')
    args = parser.parse_args()
    
    driver = None
    conn = None
    log_date = datetime.now().date()
    
    try:
        # 建立資料庫連線
        if not args.dry_run:
            conn = get_db_connection()
        
        # 建立 WebDriver
        driver = create_edge_driver()
        
        # Step 1: 抓取 Google Trends 關鍵字
        keywords = []
        if not args.skip_trends:
            logger.info("=== 步驟 1: 抓取 Google Trends 熱門關鍵字 ===")
            keywords = fetch_google_trends(driver)
            
            # 儲存關鍵字到資料庫 (KeywordsMaster)
            if not args.dry_run and conn:
                for kw in keywords:
                    try:
                        # 建立或取得 KeywordID，包含地區、搜尋量、排名資訊
                        region = kw.get('region', 'Unknown')
                        search_volume = kw.get('search_volume', 'N/A')
                        rank = kw.get('rank', 0)
                        
                        keyword_id = get_or_create_keyword_id(
                            conn, 
                            kw['keyword'], 
                            category=f'Google Trends',
                            search_intent='Trending',
                            search_volume=search_volume,
                            region=region,
                            trend_rank=rank
                        )
                    except Exception as e:
                        logger.error(f"處理關鍵字 '{kw['keyword']}' 時發生錯誤: {e}")
        else:
            logger.info("跳過 Google Trends 抓取")
        
        # Step 2: 在 Bing 搜尋前 TOP_N 個關鍵字
        if not args.skip_search and keywords:
            # 選擇前 TOP_N 個關鍵字進行搜尋
            keywords_to_search = keywords[:TOP_N]
            logger.info(f"\n=== 步驟 2: 在 Bing 搜尋前 {len(keywords_to_search)} 個關鍵字 ===")
            
            for idx, kw_data in enumerate(keywords_to_search, 1):
                keyword = kw_data['keyword']
                region = kw_data.get('region', 'Unknown')
                search_volume = kw_data.get('search_volume', 'N/A')
                rank = kw_data.get('rank', 0)
                summary_text = None
                status = 'Success'
                error_message = None
                
                logger.info(f"[{idx}/{len(keywords_to_search)}] 搜尋關鍵字: {keyword} (地區:{region}, 排名:#{rank}, 搜尋量:{search_volume})")
                
                try:
                    # 搜尋關鍵字並取得摘要
                    summary_text = search_bing_keyword(driver, keyword)
                    
                    # 儲存搜尋記錄到 KeywordsLog
                    if not args.dry_run and conn:
                        keyword_id = get_or_create_keyword_id(
                            conn, 
                            keyword, 
                            category=f'Google Trends',
                            search_intent='Trending',
                            search_volume=search_volume,
                            region=region,
                            trend_rank=rank
                        )
                        save_keyword_log(
                            conn,
                            keyword_id=keyword_id,
                            log_date=log_date,
                            summary_text=summary_text,
                            status=status,
                            error_message=None
                        )
                    
                except Exception as e:
                    status = 'Fail'
                    error_message = str(e)
                    logger.error(f"搜尋關鍵字 '{keyword}' 失敗: {e}")
                    
                    # 即使失敗也記錄到資料庫
                    if not args.dry_run and conn:
                        try:
                            keyword_id = get_or_create_keyword_id(
                                conn, 
                                keyword, 
                                category=f'Google Trends',
                                search_intent='Trending',
                                search_volume=search_volume,
                                region=region,
                                trend_rank=rank
                            )
                            save_keyword_log(
                                conn,
                                keyword_id=keyword_id,
                                log_date=log_date,
                                summary_text=None,
                                status=status,
                                error_message=error_message
                            )
                        except Exception as db_error:
                            logger.error(f"記錄失敗狀態時發生錯誤: {db_error}")
                
                # 每個關鍵字後的休息時間
                if idx < len(keywords_to_search):
                    delay = random.randint(PER_KEYWORD_MIN, PER_KEYWORD_MAX)
                    logger.info(f"等待 {delay} 秒後搜尋下一個關鍵字...")
                    time.sleep(delay)
            
            # 完成所有搜尋後的休息時間
            final_delay = random.randint(AFTER_ALL_KEYWORDS_MIN, AFTER_ALL_KEYWORDS_MAX)
            logger.info(f"已完成所有關鍵字搜尋，休息 {final_delay} 秒...")
            time.sleep(final_delay)
        else:
            if args.skip_search:
                logger.info("跳過 Bing 搜尋")
            else:
                logger.warning("無關鍵字可搜尋")
        
        logger.info("\n=== 所有步驟完成 ===")
        
    except Exception as e:
        logger.error(f"執行過程發生錯誤: {e}", exc_info=True)
        
    finally:
        # 清理資源
        if driver:
            try:
                driver.quit()
                logger.info("WebDriver 已關閉")
            except Exception as e:
                logger.error(f"關閉 WebDriver 失敗: {e}")
        
        if conn:
            try:
                conn.close()
                logger.info("資料庫連線已關閉")
            except Exception as e:
                logger.error(f"關閉資料庫連線失敗: {e}")


if __name__ == "__main__":
    main()
