# Microsoft Rewards Automation - Configuration Template
# 複製此檔案為 config.py 並根據您的環境調整設定值

# ==================== SQL Server 設定 ====================
SQL_SERVER = 'localhost'  # SQL Server 位址，例如：'localhost' 或 '192.168.1.100'
SQL_DATABASE = 'MicrosoftRDB'  # 資料庫名稱

# ==================== WebDriver 設定 ====================
DRIVER_PATH = r"C:\automation\msedgedriver.exe"  # Edge WebDriver 的完整路徑（建議使用 ASCII 路徑）

# ==================== Google Trends 設定 ====================
# 可以根據需要調整地區和排序方式
# 地區代碼範例：US (美國), TW (台灣), JP (日本), GB (英國)
TRENDS_URL = "https://trends.google.com.tw/trending?geo=US&status=active&sort=search-volume"

# 要抓取的關鍵字數量（建議 5 個）
TOP_N = 5

# ==================== 搜尋間隔設定（秒） ====================
# 每個關鍵字搜尋之間的間隔（隨機）
PER_KEYWORD_MIN = 30  # 最小間隔
PER_KEYWORD_MAX = 90  # 最大間隔

# 完成所有關鍵字搜尋後的休息時間（隨機）
AFTER_ALL_KEYWORDS_MIN = 120  # 2 分鐘
AFTER_ALL_KEYWORDS_MAX = 300  # 5 分鐘

# 每個關鍵字完成後的額外休息（可選，目前未使用）
AFTER_KEYWORD_MIN = 10
AFTER_KEYWORD_MAX = 20

# ==================== 重試設定 ====================
MAX_RETRIES = 3  # 最大重試次數
INITIAL_BACKOFF = 2  # 初始退避時間（秒），會指數增長

# ==================== Edge Profile 設定（選用） ====================
# 如果您想使用已登入的 Edge 設定檔，請取消註解並設定以下路徑
# 注意：使用 profile 時，請確保 Edge 瀏覽器已完全關閉

# EDGE_USER_DATA_DIR = r"C:\Users\YourUsername\AppData\Local\Microsoft\Edge\User Data"
# EDGE_PROFILE = "Default"  # 或其他設定檔名稱，如 "Profile 1"

# 預設值（不使用特定 profile）
EDGE_USER_DATA_DIR = None
EDGE_PROFILE = None

# ==================== Microsoft Rewards URL ====================
REWARDS_URL = "https://rewards.microsoft.com/"

# ==================== 日誌設定 ====================
LOG_FILE = 'microsoft_rewards_automation.log'  # 日誌檔案名稱
LOG_LEVEL = 'INFO'  # 日誌等級：DEBUG, INFO, WARNING, ERROR, CRITICAL

# ==================== 進階設定 ====================
# 瀏覽器視窗大小（像素）
WINDOW_WIDTH = 1366
WINDOW_HEIGHT = 768

# 是否啟用無頭模式（背景執行，不顯示瀏覽器視窗）
HEADLESS_MODE = False

# 頁面載入逾時時間（秒）
PAGE_LOAD_TIMEOUT = 30

# 元素等待逾時時間（秒）
ELEMENT_WAIT_TIMEOUT = 20
