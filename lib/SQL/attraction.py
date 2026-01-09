#!/usr/bin/env python3
"""
경상북도 경산시 관광자료 API에서 데이터를 가져와 MySQL DB에 저장하는 스크립트
음식(100), 숙박(200), 관광명소(300), 문화재/역사(400) 데이터를 수집합니다.
"""

import requests
import mysql.connector
from datetime import datetime
import time
import urllib.parse

# API 설정 - 경산시 관광 API
SERVICE_KEY_ENCODED = "czuv6YITK9end%2BE0UBFAV2ulVxC1QYEm8gXCpLT7XL3e3RgrWkCgfxW8htSmlxqZnA2DN4dBfEFV3utOBfmRzQ%3D%3D"  # 실제 키로 교체
SERVICE_KEY = urllib.parse.unquote(SERVICE_KEY_ENCODED)
API_BASE_URL = "http://apis.data.go.kr/5130000/openapi/GbgsTourService"

# DB 설정
DB_CONFIG = {
    'host': '211.58.207.209',
    'user': 'server',
    'password': 'dltmxm1234',
    'database': 'dataset',
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_general_ci',
}

# 자료 구분 코드
TOUR_CODES = [
    {'code': '100', 'name': '음식'},
    {'code': '200', 'name': '숙박'},
    {'code': '300', 'name': '관광명소'},
    {'code': '400', 'name': '문화재/역사'},
]

def get_db_connection():
    """DB 연결을 생성하고 반환합니다."""
    return mysql.connector.connect(**DB_CONFIG)

def create_gyeongsan_tour_table(cursor):
    """경산시 관광자료 테이블 생성 (없을 경우)"""
    
    # 기존 테이블 삭제 (구조 변경을 위해)
    try:
        cursor.execute("DROP TABLE IF EXISTS gyeongsan_tour")
        print("✅ 기존 gyeongsan_tour 테이블 삭제 완료")
    except mysql.connector.Error as err:
        print(f"⚠️ 테이블 삭제 오류: {err}")
    
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS gyeongsan_tour (
        id INT PRIMARY KEY,
        tour_code VARCHAR(10),
        tour_category VARCHAR(50),
        title VARCHAR(255) NOT NULL,
        homepage VARCHAR(500),
        phone VARCHAR(100),
        address VARCHAR(500),
        latitude VARCHAR(64),
        longitude VARCHAR(64),
        summary TEXT,
        contents TEXT,
        keyword VARCHAR(500),
        img_file_path VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_tour_code (tour_code),
        INDEX idx_title (title),
        INDEX idx_location (latitude, longitude)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    """
    
    try:
        cursor.execute(create_table_sql)
        print("✅ gyeongsan_tour 테이블 생성 완료")
    except mysql.connector.Error as err:
        print(f"⚠️ 테이블 생성 오류: {err}")

def fetch_tour_list_from_api(tour_code, tour_name):
    """
    경산시 관광 API에서 목록 데이터를 가져옵니다.
    
    Args:
        tour_code: 자료구분 코드 (100=음식, 200=숙박, 300=관광명소, 400=문화재/역사)
        tour_name: 자료구분 이름
    
    Returns:
        관광자료 데이터 리스트
    """
    url = f"{API_BASE_URL}/getTourContentList"
    
    params = {
        'serviceKey': SERVICE_KEY,
        'code': tour_code,
        'srchKwd': '',  # 검색어 없음
        'pageNo': 1,
        'numOfRows': 100,
        'returnType': 'json',
    }
    
    all_items = []
    page_no = 1
    max_pages = 10  # 최대 10페이지까지만
    
    while page_no <= max_pages:
        params['pageNo'] = page_no
        
        try:
            print(f"  페이지 {page_no} 요청 중...", end=' ')
            
            response = requests.get(url, params=params, timeout=10)
            
            # 상태 코드 확인
            if response.status_code != 200:
                print(f"\n❌ HTTP 오류: {response.status_code}")
                print(f"   응답: {response.text[:200]}")
                break
            
            data = response.json()
            
            # 에러 코드 확인
            result_code = data.get('resultCode', '')
            result_msg = data.get('resultMsg', '')
            
            if result_code != '00':
                print(f"\n❌ API 오류: 코드={result_code}, 메시지={result_msg}")
                break
            
            # 데이터 추출
            items = data.get('item', [])
            
            if not items:
                print(f"데이터 없음 (페이지 {page_no})")
                break
            
            # 단일 항목인 경우 리스트로 변환
            if isinstance(items, dict):
                items = [items]
            
            all_items.extend(items)
            print(f"{len(items)}개 수집 (누적: {len(all_items)}개)")
            
            # 전체 개수 확인
            total_count = data.get('totalCount', 0)
            if total_count > 0 and len(all_items) >= total_count:
                print(f"  ✅ 모든 데이터 수집 완료: {len(all_items)}/{total_count}개")
                break
            
            # 다음 페이지가 없으면 종료
            num_of_rows = data.get('numOfRows', 100)
            if len(items) < num_of_rows:
                print(f"  ✅ 마지막 페이지 도달")
                break
            
            page_no += 1
            time.sleep(0.3)
            
        except requests.exceptions.RequestException as e:
            print(f"\n❌ API 요청 오류: {e}")
            break
        except ValueError as e:
            print(f"\n❌ JSON 파싱 오류: {e}")
            print(f"   응답 내용: {response.text[:500]}")
            break
        except Exception as e:
            print(f"\n❌ 예외 발생: {e}")
            break
    
    return all_items

def save_tour_data_to_db(tour_data_list, tour_code, tour_name):
    """
    가져온 관광자료를 DB에 저장합니다.
    
    Args:
        tour_data_list: API에서 가져온 관광자료 리스트
        tour_code: 자료구분 코드
        tour_name: 자료구분 이름
    """
    if not tour_data_list:
        print("  저장할 데이터가 없습니다.")
        return 0, 0
    
    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # UPSERT (INSERT ... ON DUPLICATE KEY UPDATE) 사용
        sql = """
            INSERT INTO gyeongsan_tour (
                id, tour_code, tour_category, title, homepage, phone, address,
                latitude, longitude, summary, contents, keyword, img_file_path
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON DUPLICATE KEY UPDATE
                tour_code = VALUES(tour_code),
                tour_category = VALUES(tour_category),
                title = VALUES(title),
                homepage = VALUES(homepage),
                phone = VALUES(phone),
                address = VALUES(address),
                latitude = VALUES(latitude),
                longitude = VALUES(longitude),
                summary = VALUES(summary),
                contents = VALUES(contents),
                keyword = VALUES(keyword),
                img_file_path = VALUES(img_file_path)
        """
        
        inserted = 0
        updated = 0
        
        for item in tour_data_list:
            values = (
                item.get('id'),
                tour_code,
                tour_name,
                item.get('title', ''),
                item.get('homepage', ''),
                item.get('phone', ''),
                item.get('address', ''),
                item.get('latitude', ''),
                item.get('longitude', ''),
                item.get('summary', ''),
                item.get('contents', ''),
                item.get('keyword', ''),
                item.get('imgFilePath', ''),
            )
            
            cursor.execute(sql, values)
            
            # rowcount: 1=신규, 2=업데이트
            if cursor.rowcount == 1:
                inserted += 1
            elif cursor.rowcount == 2:
                updated += 1
        
        conn.commit()
        return inserted, updated
        
    except mysql.connector.Error as err:
        print(f"\n❌ DB 오류: {err}")
        if conn:
            conn.rollback()
        return 0, 0
    except Exception as e:
        print(f"\n❌ 예외 발생: {e}")
        if conn:
            conn.rollback()
        return 0, 0
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

def test_db_connection():
    """DB 연결을 테스트합니다."""
    print("\n🔍 DB 연결 테스트 중...")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()[0]
        print(f"✅ DB 연결 성공! MySQL 버전: {version}")
        
        # gyeongsan_tour 테이블 존재 확인
        cursor.execute("""
            SELECT COUNT(*) 
            FROM information_schema.tables 
            WHERE table_schema = %s 
            AND table_name = 'gyeongsan_tour'
        """, (DB_CONFIG['database'],))
        
        table_exists = cursor.fetchone()[0] > 0
        
        if table_exists:
            cursor.execute("SELECT COUNT(*) FROM gyeongsan_tour")
            count = cursor.fetchone()[0]
            print(f"   현재 gyeongsan_tour 테이블 행 수: {count}개")
        else:
            print(f"   gyeongsan_tour 테이블이 없습니다. (자동 생성 예정)")
        
        cursor.close()
        conn.close()
        return True
    except mysql.connector.Error as err:
        print(f"❌ DB 연결 실패: {err}")
        return False

def test_api_connection():
    """API 연결을 테스트합니다."""
    print("\n🔍 API 연결 테스트 중...")
    
    url = f"{API_BASE_URL}/getTourContentList"
    params = {
        'serviceKey': SERVICE_KEY,
        'code': '300',  # 관광명소로 테스트
        'srchKwd': '',
        'pageNo': 1,
        'numOfRows': 1,
        'returnType': 'json',
    }
    
    try:
        response = requests.get(url, params=params, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            result_code = data.get('resultCode', '')
            result_msg = data.get('resultMsg', '')
            
            if result_code == '00':
                print(f"✅ API 연결 성공! 메시지: {result_msg}")
                return True
            else:
                print(f"❌ API 오류: 코드={result_code}, 메시지={result_msg}")
                return False
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
            print(f"   응답: {response.text[:300]}")
            return False
            
    except Exception as e:
        print(f"❌ API 테스트 오류: {e}")
        return False

def main():
    """메인 실행 함수"""
    print("=" * 70)
    print(" " * 15 + "경산시 관광자료 데이터 수집 시작")
    print("=" * 70)
    
    # 0. API 연결 테스트
    if not test_api_connection():
        print("\n❌ API 연결에 실패했습니다. 서비스 키를 확인하세요.")
        return
    
    # 1. DB 연결 테스트
    if not test_db_connection():
        print("\n❌ DB 연결에 실패했습니다. 설정을 확인하세요.")
        return
    
    # 2. 테이블 생성
    print("\n📋 테이블 생성 중...")
    conn = get_db_connection()
    cursor = conn.cursor()
    create_gyeongsan_tour_table(cursor)
    cursor.close()
    conn.close()
    
    print("\n" + "=" * 70)
    print("수집 대상 카테고리:")
    for code_info in TOUR_CODES:
        print(f"  - {code_info['name']} (코드: {code_info['code']})")
    print("=" * 70)
    
    total_inserted = 0
    total_updated = 0
    total_collected = 0
    
    # 각 카테고리별로 데이터 수집
    for code_info in TOUR_CODES:
        tour_code = code_info['code']
        tour_name = code_info['name']
        
        print(f"\n📂 [{tour_name}] 데이터 수집 중...")
        
        # 1. API에서 목록 데이터 가져오기
        tour_data = fetch_tour_list_from_api(tour_code, tour_name)
        
        if tour_data:
            total_collected += len(tour_data)
            
            # 2. DB에 저장
            inserted, updated = save_tour_data_to_db(tour_data, tour_code, tour_name)
            total_inserted += inserted
            total_updated += updated
            
            print(f"   💾 저장 완료: 신규 {inserted}개, 업데이트 {updated}개")
        else:
            print(f"   ⚠️  데이터 없음")
        
        time.sleep(0.5)
    
    # 최종 결과
    print("\n" + "=" * 70)
    print("✅ 수집 완료!")
    print(f"   📊 수집된 관광자료: {total_collected}개")
    print(f"   💾 신규 저장: {total_inserted}개")
    print(f"   🔄 업데이트: {total_updated}개")
    
    # DB 최종 상태 확인
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM gyeongsan_tour")
        total_in_db = cursor.fetchone()[0]
        
        print(f"   📁 DB 총 관광자료 수: {total_in_db}개")
        
        # 카테고리별 통계
        cursor.execute("""
            SELECT tour_category, COUNT(*) as cnt 
            FROM gyeongsan_tour 
            GROUP BY tour_category 
            ORDER BY cnt DESC
        """)
        
        print(f"\n   📈 카테고리별 통계:")
        for row in cursor.fetchall():
            category = row[0]
            count = row[1]
            print(f"      - {category}: {count}개")
        
        # 샘플 데이터 출력
        print(f"\n   📝 샘플 데이터 (처음 3개):")
        cursor.execute("""
            SELECT id, title, tour_category, address 
            FROM gyeongsan_tour 
            LIMIT 3
        """)
        
        for row in cursor.fetchall():
            print(f"      [{row[2]}] {row[1]} - {row[3]}")
        
        cursor.close()
        conn.close()
        
    except mysql.connector.Error as err:
        print(f"   ⚠️  통계 조회 오류: {err}")
    
    print("=" * 70)

if __name__ == '__main__':
    main()