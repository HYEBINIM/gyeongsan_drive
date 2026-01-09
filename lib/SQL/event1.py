import requests
import mysql.connector
from mysql.connector import Error
import json

# --- 1. 설정 정보 ---
# serviceKey = 인증키
# MobileApp = 어플명
# MobileOS = IOS (아이폰), AND (안드로이드), WEB (웹), ETC (기타)
# contentTypeId = 관광타입(12: 관광지, 14: 문화시설, 15: 축제공연행사, 25: 여행코스, 28: 레포츠, 32: 숙박, 38: 쇼핑, 39: 음식점) ID
# areaCode = 지역 코드 (경상북도)
# sigunguCode = 시군구 코드 (경산시)
# cat1 = 대분류
# cat2 = 중분류
# cat3 = 소분류
# modifiedtime = 콘텐츠 수정일(형식: YYYYMMDD)
# lDongRegnCd = 법정동 시도 코드 (경상북도)
# lDongSignguCd = 법정동 시군구 코드 (경산시)
# lclsSystm1 = 분류체계 대분류
# lclsSystm2 = 분류체계 중분류
# lclsSystm3 = 분류체계 소분류

# API 요청 URL
API_URL = "https://apis.data.go.kr/B551011/KorService2/areaBasedList2?serviceKey=czuv6YITK9end%2BE0UBFAV2ulVxC1QYEm8gXCpLT7XL3e3RgrWkCgfxW8htSmlxqZnA2DN4dBfEFV3utOBfmRzQ%3D%3D&MobileApp=AppTest&MobileOS=ETC&arrange=C&contentTypeId=15&areaCode=35&sigunguCode=1&cat1=A02&cat2=&cat3=&modifiedtime=&_type=json&numOfRows=10&pageNo=1&lDongRegnCd=47&lDongSignguCd=290&lclsSystm1=EV&lclsSystm2=&lclsSystm3="

# MySQL 연결 정보 (🚨사용자 환경에 맞게 변경 필수🚨)
DB_CONFIG = {
    "host": "211.58.207.209",
    "user": "server",
    "password": "dltmxm1234",
    "database": "dataset"
}

TABLE_NAME = "event"

# --- 2. API 데이터 가져오기 ---
def get_api_data(url):
    try:
        response = requests.get(url)
        response.raise_for_status() # HTTP 오류가 발생하면 예외 발생
        data = response.json()
        
        # 'item' 배열 경로를 따라가서 실제 데이터 리스트 추출
        items = data.get("response", {}).get("body", {}).get("items", {}).get("item", [])
        
        # 'item'이 단일 객체로 올 경우(numOfRows=1)를 대비하여 리스트로 통일
        if isinstance(items, dict):
            items = [items]
            
        return items
        
    except requests.exceptions.RequestException as e:
        print(f"API 요청 중 오류 발생: {e}")
        return None
    except json.JSONDecodeError:
        print("JSON 디코딩 오류: 응답이 JSON 형식이 아닙니다.")
        return None

# --- 3. MySQL 연결 및 데이터 삽입 ---
def insert_data_to_mysql(data_list):
    if not data_list:
        print("삽입할 데이터가 없습니다.")
        return

    connection = None
    try:
        # MySQL 연결
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()

        # INSERT 쿼리 (컬럼이 많으므로 딕셔너리 키를 이용)
        columns = ", ".join(data_list[0].keys())
        placeholders = ", ".join(["%s"] * len(data_list[0]))
        
        insert_query = f"""
            INSERT INTO {TABLE_NAME} ({columns}) 
            VALUES ({placeholders})
            ON DUPLICATE KEY UPDATE title=VALUES(title), modifiedtime=VALUES(modifiedtime);
        """

        # 삽입할 데이터 리스트 생성 (딕셔너리 값만 추출하여 튜플 리스트로 변환)
        data_to_insert = [tuple(item.values()) for item in data_list]

        # 다중 데이터 삽입
        cursor.executemany(insert_query, data_to_insert)
        connection.commit()
        
        print(f"성공적으로 {cursor.rowcount}개의 데이터를 {TABLE_NAME} 테이블에 저장했습니다.")

    except Error as e:
        print(f"MySQL 오류 발생: {e}")
        
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

# --- 4. 메인 실행 ---
if __name__ == "__main__":
    print("API 데이터 가져오기 시작...")
    event_data = get_api_data(API_URL)

    if event_data:
        print(f"가져온 데이터 수: {len(event_data)}개. MySQL에 저장 시작...")
        insert_data_to_mysql(event_data)
    else:
        print("데이터 저장 작업을 건너뜁니다.")