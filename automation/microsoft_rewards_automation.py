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
TRENDS_URL = "https://trends.google.com.tw/trending?geo=US&status=active&sort=search-volume"

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
EDGE_USER_DATA_DIR = None  # r"C:\Users\<YourUser>\AppData\Local\Microsoft\Edge\User Data"
EDGE_PROFILE = None  # "Default"

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


def save_keyword_to_db(conn, keyword, rank, search_volume=None):
    """
    將關鍵字儲存到資料庫
    """
    try:
        cursor = conn.cursor()
        query = """
            INSERT INTO TrendingKeywords (Keyword, Rank, SearchVolume, FetchedAt)
            VALUES (?, ?, ?, GETDATE())
        """
        cursor.execute(query, (keyword, rank, search_volume))
        conn.commit()
        logger.info(f"關鍵字已儲存: {keyword} (排名: {rank})")
    except Exception as e:
        logger.error(f"儲存關鍵字失敗: {e}")
        conn.rollback()


def save_daily_points(conn, points, activity_type='搜尋'):
    """
    將當日點數寫入 DailyPointsLog
    """
    try:
        cursor = conn.cursor()
        query = """
            INSERT INTO DailyPointsLog (Points, ActivityType, LoggedAt)
            VALUES (?, ?, GETDATE())
        """
        cursor.execute(query, (points, activity_type))
        conn.commit()
        logger.info(f"已記錄點數: {points} ({activity_type})")
    except Exception as e:
        logger.error(f"儲存點數失敗: {e}")
        conn.rollback()


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
    
    # 其他常用選項
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    
    try:
        service = Service(DRIVER_PATH)
        driver = webdriver.Edge(service=service, options=options)
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
            
            # 等待頁面載入
            wait = WebDriverWait(driver, 20)
            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "div.feed-item")))
            
            # 抓取關鍵字（實際 selector 可能需要根據頁面調整）
            time.sleep(3)  # 額外等待確保頁面完全載入
            
            # Google Trends 的結構可能會變化，這裡提供基本抓取邏輯
            trend_items = driver.find_elements(By.CSS_SELECTOR, "div.feed-item")
            
            for idx, item in enumerate(trend_items[:TOP_N], 1):
                try:
                    # 嘗試多種可能的 selector
                    keyword_element = None
                    selectors = [
                        "div.title a",
                        "div.mdc-layout-grid__cell span",
                        "a.title",
                        "span.title"
                    ]
                    
                    for selector in selectors:
                        try:
                            keyword_element = item.find_element(By.CSS_SELECTOR, selector)
                            break
                        except:
                            continue
                    
                    if keyword_element:
                        keyword = keyword_element.text.strip()
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
            if retries < MAX_RETRIES:
                backoff = INITIAL_BACKOFF * (2 ** (retries - 1))
                logger.info(f"等待 {backoff} 秒後重試...")
                time.sleep(backoff)
            else:
                logger.error("已達到最大重試次數，放棄抓取")
                raise
    
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
        
        # 可選：擷取搜尋結果摘要
        try:
            results = driver.find_elements(By.CSS_SELECTOR, "li.b_algo")
            if results:
                first_result = results[0].text[:200]  # 取前 200 字元
                logger.info(f"搜尋結果摘要: {first_result}...")
                return first_result
        except Exception as e:
            logger.warning(f"擷取摘要失敗: {e}")
        
        return None
        
    except Exception as e:
        logger.error(f"Bing 搜尋失敗 ({keyword}): {e}")
        raise


def fetch_rewards_points(driver):
    """
    抓取 Microsoft Rewards 當日點數
    """
    try:
        logger.info("正在抓取 Microsoft Rewards 點數...")
        driver.get(REWARDS_URL)
        
        # 等待點數元素載入（實際 selector 需根據頁面調整）
        wait = WebDriverWait(driver, 20)
        
        # Microsoft Rewards 頁面的點數顯示位置可能變化
        # 這裡提供幾種可能的 selector
        points = None
        selectors = [
            "span.mee-rewards-counter-balance",
            "div.dashboard-balance span",
            "[data-bi-id='rewardsBalance']",
            "span.points-value"
        ]
        
        for selector in selectors:
            try:
                points_element = wait.until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, selector))
                )
                points_text = points_element.text.strip()
                # 提取數字
                points = int(''.join(filter(str.isdigit, points_text)))
                logger.info(f"目前點數: {points}")
                return points
            except Exception as e:
                continue
        
        if points is None:
            logger.warning("無法取得點數，可能需要登入或調整 selector")
            return 0
            
    except Exception as e:
        logger.error(f"抓取 Rewards 點數失敗: {e}")
        return 0


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
            
            # 儲存關鍵字到資料庫
            if not args.dry_run and conn:
                for kw in keywords:
                    save_keyword_to_db(conn, kw['keyword'], kw['rank'])
        else:
            logger.info("跳過 Google Trends 抓取")
        
        # Step 2: 在 Bing 搜尋前五個關鍵字
        if not args.skip_search and keywords:
            logger.info(f"\n=== 步驟 2: 在 Bing 搜尋前 {len(keywords)} 個關鍵字 ===")
            
            for idx, kw_data in enumerate(keywords, 1):
                keyword = kw_data['keyword']
                
                # 搜尋關鍵字
                search_bing_keyword(driver, keyword)
                
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
            points = fetch_rewards_points(driver)
            
            # 儲存點數到資料庫
            if not args.dry_run and conn and points > 0:
                save_daily_points(conn, points)
        else:
            logger.info("跳過 Rewards 點數抓取")
        
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
