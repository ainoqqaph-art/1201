# -*- coding: utf-8 -*-
#!/usr/bin/env python
"""
整合流程（單次執行版）：
1) 抓取 Google Trends 熱門關鍵字（一次）
2) 針對當次抓到的前五個關鍵字，在 Bing 做搜尋並擷取摘要（每關鍵字間隔 30-90 秒，完成後休息 2-5 分鐘）
3) 完成後抓 Microsoft Rewards 當日點數並寫入 DailyPointsLog（一次）
4) 使用 Windows Authentication 連接 SQL Server（請確認 ODBC Driver 與 msedgedriver 相容）
說明：此檔為「單次執行」版本，適合由 Windows Task Scheduler 或其他排程工具呼叫。
"""

import argparse
import time
import random
import pyodbc
import json
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

# Google Trends URL（可改地區或排序）
# 使用 Daily Search Trends API endpoint，較穩定
TRENDS_URL = "https://trends.google.com/trends/trendingsearches/daily?geo=US"

# 前 N 名關鍵字要做額外搜尋
TOP_N = 5

# 前五關鍵字搜尋間隔（秒）
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

# 若 Rewards 需要已登入 session，可啟用 Edge profile（選用）
# 範例路徑：r"C:\Users\{USERNAME}\AppData\Local\Microsoft\Edge\User Data"
# 其中 {USERNAME} 是您的 Windows 使用者名稱
EDGE_USER_DATA_DIR = None  # r"C:\Users\YourUsername\AppData\Local\Microsoft\Edge\User Data"
EDGE_PROFILE = None  # "Default" 或 "Profile 1" 等

# Microsoft Rewards URL
REWARDS_URL = "https://rewards.microsoft.com/"

# ==================== 日誌設定 ====================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('microsoft_rewards_automation.log', encoding='utf-8'),
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


def get_or_create_keyword_id(conn, keyword, category=None, search_intent=None):
    """
    取得或建立關鍵字 ID
    如果關鍵字已存在於 KeywordsMaster，返回其 ID
    如果不存在，插入新記錄並返回新 ID
    """
    try:
        cursor = conn.cursor()
        
        # 先查詢是否已存在
        cursor.execute("SELECT KeywordID FROM KeywordsMaster WHERE Keyword = ?", (keyword,))
        row = cursor.fetchone()
        
        if row:
            keyword_id = row[0]
            logger.debug(f"關鍵字已存在: {keyword} (ID: {keyword_id})")
            return keyword_id
        
        # 不存在則插入（觸發器會自動處理 KeywordID）
        cursor.execute("""
            INSERT INTO KeywordsMaster (KeywordID, Keyword, Category, SearchIntent, CreatedAt)
            VALUES (0, ?, ?, ?, GETDATE())
        """, (keyword, category, search_intent))
        conn.commit()
        
        # 重新查詢以取得觸發器生成的 ID
        cursor.execute("SELECT KeywordID FROM KeywordsMaster WHERE Keyword = ?", (keyword,))
        row = cursor.fetchone()
        keyword_id = row[0]
        
        logger.info(f"新增關鍵字: {keyword} (ID: {keyword_id})")
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


def save_daily_points(conn, log_date, available_points=None, today_points=None, 
                     points_gained=None, status='Success', error_message=None):
    """
    將當日點數寫入 DailyPointsLog
    """
    try:
        cursor = conn.cursor()
        
        # 插入記錄（觸發器會自動處理 LogID）
        cursor.execute("""
            INSERT INTO DailyPointsLog 
            (LogID, LogDate, AvailablePoints, TodayPoints, PointsGained, Status, ErrorMessage, CreatedAt)
            VALUES (0, ?, ?, ?, ?, ?, ?, GETDATE())
        """, (log_date, available_points, today_points, points_gained, status, error_message))
        
        conn.commit()
        logger.info(f"已記錄點數: LogDate={log_date}, Available={available_points}, Today={today_points}, Gained={points_gained}")
        
    except Exception as e:
        logger.error(f"儲存點數記錄失敗: {e}")
        conn.rollback()
        raise


# ==================== Selenium 操作 ====================
def create_edge_driver():
    """
    建立 Edge WebDriver
    """
    options = webdriver.EdgeOptions()
    
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
    
    # 設定頁面載入策略
    options.page_load_strategy = 'normal'  # 等待完整頁面載入
    
    try:
        service = Service(DRIVER_PATH)
        driver = webdriver.Edge(service=service, options=options)
        
        # 設定隱式等待
        driver.implicitly_wait(10)
        
        # 設定頁面載入超時
        driver.set_page_load_timeout(60)
        
        logger.info("Edge WebDriver 已啟動")
        return driver
    except Exception as e:
        logger.error(f"啟動 Edge WebDriver 失敗: {e}")
        raise


def fetch_google_trends(driver):
    """
    抓取 Google Trends 熱門關鍵字
    返回: list of dict [{'keyword': str, 'rank': int}, ...]
    """
    keywords = []
    retries = 0
    
    while retries < MAX_RETRIES:
        try:
            logger.info(f"正在抓取 Google Trends... (嘗試 {retries + 1}/{MAX_RETRIES})")
            driver.get(TRENDS_URL)
            
            # 增加等待時間以確保頁面完全載入
            time.sleep(5)
            
            # 嘗試多種可能的選擇器策略
            trend_items = []
            
            # 策略 1: 嘗試使用 table 結構
            try:
                wait = WebDriverWait(driver, 15)
                # Google Trends Daily 使用 table 結構
                wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "tbody tr")))
                trend_items = driver.find_elements(By.CSS_SELECTOR, "tbody tr")
                logger.info(f"策略 1 (table): 找到 {len(trend_items)} 個項目")
            except Exception as e1:
                logger.warning(f"策略 1 (table) 失敗: {e1}")
                
                # 策略 2: 嘗試使用 feed-item
                try:
                    trend_items = driver.find_elements(By.CSS_SELECTOR, "div.feed-item")
                    logger.info(f"策略 2 (feed-item): 找到 {len(trend_items)} 個項目")
                except Exception as e2:
                    logger.warning(f"策略 2 (feed-item) 失敗: {e2}")
                    
                    # 策略 3: 嘗試使用更通用的選擇器
                    try:
                        trend_items = driver.find_elements(By.CSS_SELECTOR, "[class*='trending'], [class*='trend-item']")
                        logger.info(f"策略 3 (通用): 找到 {len(trend_items)} 個項目")
                    except Exception as e3:
                        logger.warning(f"策略 3 (通用) 失敗: {e3}")
                        
                        # 策略 4: 使用 XPath 查找任何包含關鍵字的元素
                        try:
                            # 儲存截圖以供調試
                            screenshot_path = f"debug_trends_{retries + 1}.png"
                            driver.save_screenshot(screenshot_path)
                            logger.info(f"已儲存截圖: {screenshot_path}")
                            
                            # 嘗試從頁面原始碼提取
                            page_source = driver.page_source
                            logger.debug(f"頁面長度: {len(page_source)} 字元")
                            
                            # 如果是 JSON API endpoint
                            if "application/json" in driver.page_source or page_source.strip().startswith('{'):
                                import json
                                # 嘗試解析 JSON
                                try:
                                    # 找到 pre 標籤內的 JSON
                                    pre_element = driver.find_element(By.TAG_NAME, "pre")
                                    json_data = json.loads(pre_element.text)
                                    logger.info("成功解析 JSON 資料")
                                    
                                    # 從 JSON 提取關鍵字
                                    if isinstance(json_data, dict) and 'default' in json_data:
                                        trending_searches = json_data.get('default', {}).get('trendingSearchesDays', [])
                                        if trending_searches:
                                            for search in trending_searches[0].get('trendingSearches', [])[:TOP_N]:
                                                keyword = search.get('title', {}).get('query', '')
                                                if keyword:
                                                    keywords.append({'keyword': keyword, 'rank': len(keywords) + 1})
                                                    logger.info(f"發現關鍵字 #{len(keywords)}: {keyword}")
                                except json.JSONDecodeError as je:
                                    logger.error(f"JSON 解析失敗: {je}")
                                except Exception as json_err:
                                    logger.error(f"JSON 處理失敗: {json_err}")
                            
                        except Exception as e4:
                            logger.error(f"策略 4 (XPath/JSON) 失敗: {e4}")
            
            # 如果已經從 JSON 獲取到關鍵字，直接返回
            if keywords:
                logger.info(f"從 JSON 成功抓取 {len(keywords)} 個關鍵字")
                return keywords
            
            # 否則從 HTML 元素抓取
            if not trend_items:
                raise Exception("所有選擇器策略都失敗，無法找到趨勢項目")
            
            # 從找到的元素中提取關鍵字
            for idx, item in enumerate(trend_items[:TOP_N], 1):
                try:
                    # 嘗試多種可能的 selector
                    keyword_element = None
                    keyword = None
                    
                    # 針對 table 結構的選擇器
                    selectors = [
                        "td a",  # table cell with link
                        "a",     # any link
                        "div.title a",
                        "div.mdc-layout-grid__cell span",
                        "a.title",
                        "span.title",
                        "td",    # plain table cell
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
                        # 取第一行作為關鍵字（通常是標題）
                        if '\n' in keyword:
                            keyword = keyword.split('\n')[0].strip()
                    
                    if keyword:
                        keywords.append({'keyword': keyword, 'rank': idx})
                        logger.info(f"發現關鍵字 #{idx}: {keyword}")
                except Exception as e:
                    logger.warning(f"抓取第 {idx} 個關鍵字失敗: {e}")
                    continue
            
            if keywords:
                logger.info(f"成功抓取 {len(keywords)} 個關鍵字")
                return keywords
            else:
                raise Exception("未能抓取到任何關鍵字")
                
        except Exception as e:
            retries += 1
            logger.error(f"抓取 Google Trends 失敗: {e}")
            
            # 儲存錯誤時的截圖
            try:
                screenshot_path = f"error_trends_{retries}.png"
                driver.save_screenshot(screenshot_path)
                logger.info(f"錯誤截圖已儲存: {screenshot_path}")
            except:
                pass
            
            if retries < MAX_RETRIES:
                backoff = INITIAL_BACKOFF * (2 ** (retries - 1))
                logger.info(f"等待 {backoff} 秒後重試...")
                time.sleep(backoff)
            else:
                logger.error("已達到最大重試次數，放棄抓取")
                # 最後嘗試：返回一些預設關鍵字以便程式繼續運行
                logger.warning("使用備用關鍵字列表")
                return [
                    {'keyword': 'Microsoft Rewards', 'rank': 1},
                    {'keyword': 'Bing Search', 'rank': 2},
                    {'keyword': 'Technology News', 'rank': 3},
                    {'keyword': 'Weather', 'rank': 4},
                    {'keyword': 'Sports', 'rank': 5}
                ]
    
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


def fetch_rewards_points(driver):
    """
    抓取 Microsoft Rewards 點數
    返回: dict {'available_points': int, 'today_points': int, 'points_gained': int}
    """
    try:
        logger.info("正在抓取 Microsoft Rewards 點數...")
        driver.get(REWARDS_URL)
        
        # 等待頁面載入
        wait = WebDriverWait(driver, 20)
        time.sleep(3)  # 額外等待確保頁面完全載入
        
        result = {
            'available_points': None,
            'today_points': None,
            'points_gained': None
        }
        
        # 嘗試抓取可用點數 (Available Points)
        available_selectors = [
            "span.mee-rewards-counter-balance",
            "div.dashboard-balance span",
            "[data-bi-id='rewardsBalance']",
            "span.points-value",
            "mee-rewards-user-status-balance span"
        ]
        
        for selector in available_selectors:
            try:
                element = driver.find_element(By.CSS_SELECTOR, selector)
                text = element.text.strip()
                points = int(''.join(filter(str.isdigit, text)))
                result['available_points'] = points
                logger.info(f"可用點數: {points}")
                break
            except:
                continue
        
        # 嘗試抓取今日點數 (Today's Points)
        # 這部分的 selector 可能需要根據實際頁面調整
        today_selectors = [
            "span.daily-points",
            "div.today-points span",
            "[data-bi-id='todayPoints']",
            "mee-rewards-daily-set-item-content"
        ]
        
        for selector in today_selectors:
            try:
                element = driver.find_element(By.CSS_SELECTOR, selector)
                text = element.text.strip()
                points = int(''.join(filter(str.isdigit, text)))
                result['today_points'] = points
                result['points_gained'] = points  # 通常今日點數等於獲得點數
                logger.info(f"今日點數: {points}")
                break
            except:
                continue
        
        if result['available_points'] is None:
            logger.warning("無法取得點數，可能需要登入或調整 selector")
        
        return result
            
    except Exception as e:
        logger.error(f"抓取 Rewards 點數失敗: {e}")
        return {
            'available_points': None,
            'today_points': None,
            'points_gained': None
        }


# ==================== 主流程 ====================
def main():
    """
    主執行流程
    """
    parser = argparse.ArgumentParser(description='Microsoft Rewards 自動化工具（單次執行版）')
    parser.add_argument('--dry-run', action='store_true', help='測試模式，不寫入資料庫')
    parser.add_argument('--skip-trends', action='store_true', help='跳過 Google Trends 抓取')
    parser.add_argument('--skip-search', action='store_true', help='跳過 Bing 搜尋')
    parser.add_argument('--skip-rewards', action='store_true', help='跳過 Rewards 點數抓取')
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
                        # 建立或取得 KeywordID，設定 Category 為 'Google Trends'
                        keyword_id = get_or_create_keyword_id(
                            conn, 
                            kw['keyword'], 
                            category='Google Trends',
                            search_intent='Trending'
                        )
                        # 儲存一筆初始記錄到 KeywordsLog (尚未搜尋)
                        # 這可以選擇性做，或在後續搜尋時才記錄
                    except Exception as e:
                        logger.error(f"處理關鍵字 '{kw['keyword']}' 時發生錯誤: {e}")
        else:
            logger.info("跳過 Google Trends 抓取")
        
        # Step 2: 在 Bing 搜尋前五個關鍵字
        if not args.skip_search and keywords:
            logger.info(f"\n=== 步驟 2: 在 Bing 搜尋前 {len(keywords)} 個關鍵字 ===")
            
            for idx, kw_data in enumerate(keywords, 1):
                keyword = kw_data['keyword']
                summary_text = None
                status = 'Success'
                error_message = None
                
                try:
                    # 搜尋關鍵字並取得摘要
                    summary_text = search_bing_keyword(driver, keyword)
                    
                    # 儲存搜尋記錄到 KeywordsLog
                    if not args.dry_run and conn:
                        keyword_id = get_or_create_keyword_id(
                            conn, 
                            keyword, 
                            category='Google Trends',
                            search_intent='Trending'
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
                                category='Google Trends',
                                search_intent='Trending'
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
                if idx < len(keywords):
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
        
        # Step 3: 抓取 Microsoft Rewards 點數
        if not args.skip_rewards:
            logger.info("\n=== 步驟 3: 抓取 Microsoft Rewards 點數 ===")
            points_data = fetch_rewards_points(driver)
            
            # 儲存點數到資料庫
            if not args.dry_run and conn:
                status = 'Success' if points_data['available_points'] is not None else 'Fail'
                error_msg = None if status == 'Success' else '無法取得點數'
                
                save_daily_points(
                    conn,
                    log_date=log_date,
                    available_points=points_data['available_points'],
                    today_points=points_data['today_points'],
                    points_gained=points_data['points_gained'],
                    status=status,
                    error_message=error_msg
                )
        else:
            logger.info("跳過 Rewards 點數抓取")
        
        logger.info("\n=== 所有步驟完成 ===")
        
    except Exception as e:
        logger.error(f"執行過程發生錯誤: {e}", exc_info=True)
        
        # 記錄失敗到 DailyPointsLog
        if not args.dry_run and conn:
            try:
                save_daily_points(
                    conn,
                    log_date=log_date,
                    available_points=None,
                    today_points=None,
                    points_gained=None,
                    status='Fail',
                    error_message=str(e)
                )
            except Exception as db_err:
                logger.error(f"記錄失敗狀態時發生錯誤: {db_err}")
        
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
