#!/usr/bin/env python3
"""
한국관광공사 문화행사 API에서 데이터를 가져와 MySQL DB에 저장하는 스크립트
정기적으로 실행하여 DB를 최신 상태로 유지합니다.
"""

import requests
import mysql.connector
from datetime import datetime, timedelta
import time
import urllib.parse

# API 설정 - requests가 자동으로 인코딩하므로 디코딩된 키 사용
SERVICE_KEY_ENCODED = "czuv6YITK9end%2BE0UBFAV2ulVxC1QYEm8gXCpLT7XL3e3RgrWkCgfxW8htSmlxqZnA2DN4dBfEFV3utOBfmRzQ%3D%3D"
SERVICE_KEY = urllib.parse.unquote(SERVICE_KEY_ENCODED)  # 디코딩: requests가 다시 인코딩함
API_URL = "https://apis.data.go.kr/B551011/KorService2/searchFestival2"

# DB 설정 - Collation 명시
DB_CONFIG = {
    'host': '211.58.207.209',
    'user': 'server',
    'password': 'dltmxm1234',
    'database': 'dataset',
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_general_ci',  # MySQL 5.7 호환
}

def get_db_connection():
    """DB 연결을 생성하고 반환합니다."""
    return mysql.connector.connect(**DB_CONFIG)

def fetch_events_from_api(area_code='35', sigungu_code='1', start_date=None, end_date=None):
    """
    공공 API에서 문화행사 데이터를 가져옵니다.
    
    Args:
        area_code: 지역코드 (35: 경북)
        sigungu_code: 시군구코드 (1: 경산시)
        start_date: 행사 시작일 (YYYYMMDD), None이면 20250101
        end_date: 행사 종료일 (YYYYMMDD), None이면 20261231
    """
    if start_date is None:
        start_date = '20250101'
    if end_date is None:
        end_date = '20261231'
    
    # 실행 가능한 주소와 동일한 파라미터 구조
    # requests가 자동으로 URL 인코딩하므로 디코딩된 키 사용
    params = {
        'serviceKey': SERVICE_KEY,  # 디코딩된 키 (requests가 자동 인코딩)
        'MobileApp': 'AppTest',
        'MobileOS': 'ETC',
        'pageNo': 1,
        'numOfRows': 100,
        'eventStartDate': start_date,
        'arrange': 'C',
        'modifiedtime': '',
        'areaCode': area_code,
        'sigunguCode': sigungu_code,
        'eventEndDate': end_date,
        '_type': 'json',
        'cat1': 'A02',
        'cat2': '',
        'cat3': '',
        'lDongRegnCd': '47',
        'lDongSignguCd': '290',
        'lclsSystm1': 'EV',
        'lclsSystm2': '',
        'lclsSystm3': '',
    }
    
    all_items = []
    page_no = 1
    
    while True:
        params['pageNo'] = page_no
        
        try:
            print(f"페이지 {page_no} 요청 중...")
            
            # requests가 자동으로 URL 인코딩함
            response = requests.get(API_URL, params=params, timeout=10)
            
            print(f"요청 URL: {response.url}")  # 디버깅용
            
            if response.status_code == 401:
                print(f"❌ 인증 오류 (401): 서비스 키를 확인하세요.")
                print(f"   디코딩된 키: {SERVICE_KEY[:20]}...")
                break
            
            response.raise_for_status()
            
            data = response.json()
            
            # 응답 구조 확인
            if 'response' not in data:
                print(f"오류: 잘못된 응답 구조 - {data}")
                break
            
            header = data['response']['header']
            if header['resultCode'] != '0000':
                print(f"API 오류: {header['resultMsg']}")
                break
            
            body = data['response']['body']
            items = body.get('items', {})
            
            # items가 빈 문자열('')인 경우 처리
            if items == '' or items is None:
                print(f"페이지 {page_no}에 데이터 없음. 종료.")
                break
            
            item_list = items.get('item', [])
            
            if not item_list:
                print(f"페이지 {page_no}에 항목 없음. 종료.")
                break
            
            all_items.extend(item_list)
            print(f"페이지 {page_no}: {len(item_list)}개 항목 수집 (총 {len(all_items)}개)")
            
            # 전체 개수 확인
            total_count = body.get('totalCount', 0)
            if len(all_items) >= total_count:
                print(f"모든 데이터 수집 완료: {len(all_items)}/{total_count}개")
                break
            
            page_no += 1
            time.sleep(0.5)  # API 호출 제한 방지
            
        except requests.exceptions.RequestException as e:
            print(f"❌ API 요청 오류: {e}")
            break
        except Exception as e:
            print(f"❌ 예외 발생: {e}")
            break
    
    return all_items

def save_events_to_db(events):
    """
    가져온 행사 데이터를 DB에 저장합니다.
    
    Args:
        events: API에서 가져온 행사 데이터 리스트
    """
    if not events:
        print("저장할 데이터가 없습니다.")
        return
    
    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # UPSERT (INSERT ... ON DUPLICATE KEY UPDATE) 사용
        sql = """
            INSERT INTO event (
                contentid, contenttypeid, title, addr1, addr2, areacode, sigungucode,
                cat1, cat2, cat3, mapx, mapy, mlevel, tel, zipcode,
                firstimage, firstimage2, cpyrhtDivCd, createdtime, modifiedtime,
                eventstartdate, eventenddate,
                lDongRegnCd, lDongSignguCd, lclsSystm1, lclsSystm2, lclsSystm3,
                progresstype, festivaltype
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s
            )
            ON DUPLICATE KEY UPDATE
                contenttypeid = VALUES(contenttypeid),
                title = VALUES(title),
                addr1 = VALUES(addr1),
                addr2 = VALUES(addr2),
                areacode = VALUES(areacode),
                sigungucode = VALUES(sigungucode),
                cat1 = VALUES(cat1),
                cat2 = VALUES(cat2),
                cat3 = VALUES(cat3),
                mapx = VALUES(mapx),
                mapy = VALUES(mapy),
                mlevel = VALUES(mlevel),
                tel = VALUES(tel),
                zipcode = VALUES(zipcode),
                firstimage = VALUES(firstimage),
                firstimage2 = VALUES(firstimage2),
                cpyrhtDivCd = VALUES(cpyrhtDivCd),
                createdtime = VALUES(createdtime),
                modifiedtime = VALUES(modifiedtime),
                eventstartdate = VALUES(eventstartdate),
                eventenddate = VALUES(eventenddate),
                lDongRegnCd = VALUES(lDongRegnCd),
                lDongSignguCd = VALUES(lDongSignguCd),
                lclsSystm1 = VALUES(lclsSystm1),
                lclsSystm2 = VALUES(lclsSystm2),
                lclsSystm3 = VALUES(lclsSystm3),
                progresstype = VALUES(progresstype),
                festivaltype = VALUES(festivaltype)
        """
        
        inserted = 0
        updated = 0
        
        for event in events:
            values = (
                event.get('contentid'),
                event.get('contenttypeid'),
                event.get('title'),
                event.get('addr1'),
                event.get('addr2'),
                event.get('areacode'),
                event.get('sigungucode'),
                event.get('cat1'),
                event.get('cat2'),
                event.get('cat3'),
                event.get('mapx'),
                event.get('mapy'),
                event.get('mlevel'),
                event.get('tel'),
                event.get('zipcode'),
                event.get('firstimage'),
                event.get('firstimage2'),
                event.get('cpyrhtDivCd'),
                event.get('createdtime'),
                event.get('modifiedtime'),
                event.get('eventstartdate'),
                event.get('eventenddate'),
                event.get('lDongRegnCd'),
                event.get('lDongSignguCd'),
                event.get('lclsSystm1'),
                event.get('lclsSystm2'),
                event.get('lclsSystm3'),
                event.get('progresstype'),
                event.get('festivaltype'),
            )
            
            cursor.execute(sql, values)
            
            if cursor.rowcount == 1:
                inserted += 1
            elif cursor.rowcount == 2:
                updated += 1
        
        conn.commit()
        print(f"\n✅ DB 저장 완료: 신규 {inserted}개, 업데이트 {updated}개")
        
    except mysql.connector.Error as err:
        print(f"❌ DB 오류: {err}")
        if conn:
            conn.rollback()
    except Exception as e:
        print(f"❌ 예외 발생: {e}")
        if conn:
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

# def clean_old_events():
#     """
#     종료된 행사 데이터를 DB에서 삭제합니다.
#     """
#     conn = None
#     cursor = None
    
#     try:
#         conn = get_db_connection()
#         cursor = conn.cursor()
        
#         # 행사 종료일이 3개월 이전인 데이터 삭제
#         cutoff_date = (datetime.now() - timedelta(days=90)).strftime('%Y%m%d')
        
#         sql = """
#             DELETE FROM event 
#             WHERE eventenddate IS NOT NULL 
#             AND eventenddate < %s
#         """
        
#         cursor.execute(sql, (cutoff_date,))
#         deleted_count = cursor.rowcount
#         conn.commit()
        
#         print(f"🗑️  종료된 행사 {deleted_count}개 삭제됨 (기준일: {cutoff_date})")
        
#     except mysql.connector.Error as err:
#         print(f"❌ DB 정리 오류: {err}")
#     finally:
#         if cursor:
#             cursor.close()
#         if conn and conn.is_connected():
#             conn.close()

def test_db_connection():
    """DB 연결을 테스트합니다."""
    print("\n🔍 DB 연결 테스트 중...")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()[0]
        print(f"✅ DB 연결 성공! MySQL 버전: {version}")
        
        cursor.execute("SELECT COUNT(*) FROM event")
        count = cursor.fetchone()[0]
        print(f"   현재 event 테이블 행 수: {count}개")
        
        cursor.close()
        conn.close()
        return True
    except mysql.connector.Error as err:
        print(f"❌ DB 연결 실패: {err}")
        return False

def main():
    """메인 실행 함수"""
    print("=" * 60)
    print("문화행사 데이터 수집 시작")
    print("=" * 60)
    
    # 0. DB 연결 테스트
    if not test_db_connection():
        print("\n❌ DB 연결에 실패했습니다. 설정을 확인하세요.")
        return
    
    # 1. 공공 API에서 데이터 가져오기
    print("\n[1/3] 공공 API에서 데이터 가져오는 중...")
    events = fetch_events_from_api(
        area_code='35',  # 경상북도
        sigungu_code='1',  # 경산시
    )
    
    print(f"총 {len(events)}개의 행사 데이터를 가져왔습니다.")
    
    # 2. DB에 저장
    if events:
        print("\n[2/3] DB에 저장 중...")
        save_events_to_db(events)
    else:
        print("\n⚠️  가져온 데이터가 없어 DB 저장을 건너뜁니다.")
        print("   API 키를 확인하거나, 해당 지역에 행사가 없을 수 있습니다.")
    
    # 3. 오래된 데이터 정리
    # print("\n[3/3] 종료된 행사 정리 중...")
    # clean_old_events()
    
    print("\n" + "=" * 60)
    print("✅ 작업 완료!")
    print("=" * 60)

if __name__ == '__main__':
    main()