"""
config.py
버스노선정보조회 API 설정 파일
"""

# ==================== API 설정 ====================
# 공공데이터포털에서 발급받은 서비스 키를 입력하세요
# 주의: URL 인코딩된 키를 그대로 입력하세요 (예: %2B, %3D 등 포함)
SERVICE_KEY = "czuv6YITK9end%2BE0UBFAV2ulVxC1QYEm8gXCpLT7XL3e3RgrWkCgfxW8htSmlxqZnA2DN4dBfEFV3utOBfmRzQ%3D%3D"

# API 베이스 URL
BASE_URL = "http://apis.data.go.kr/1613000/BusRouteInfoInqireService"

# 기본 설정
DEFAULT_NUM_OF_ROWS = 10
DEFAULT_PAGE_NO = 1
DEFAULT_DATA_TYPE = "xml"  # xml 또는 json


# ==================== MySQL 데이터베이스 설정 ====================
DB_CONFIG = {
    'host': '211.58.207.209',
    'user': 'server',
    'password': 'dltmxm1234',
    'database': 'dataset',
    'charset': 'utf8mb4',
    'port': 3306
}

# 데이터베이스 자동 저장 여부 (기본값)
AUTO_SAVE_TO_DB = True