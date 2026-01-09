"""
test_city_code.py
테스트 1: 도시코드 목록 조회 (MySQL DB 저장 기능 포함)
서비스 가능한 지역들의 도시코드 목록을 조회하고 MySQL DB에 저장합니다.
"""

from bus_route_api import BusRouteAPI, print_result
from config import SERVICE_KEY, BASE_URL, DEFAULT_DATA_TYPE, AUTO_SAVE_TO_DB
from database import BusRouteDatabase, print_db_info


def test_city_code_list(save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    도시코드 목록 조회 테스트
    
    Args:
        save_to_db: DB 저장 여부 (기본값: config.AUTO_SAVE_TO_DB)
    """
    
    print("\n" + "="*80)
    print("  [테스트 1] 도시코드 목록 조회")
    print("="*80)
    
    # 서비스 키 확인
    if SERVICE_KEY == "여기에_발급받은_서비스키를_입력하세요":
        print("\n[경고] config.py 파일에서 SERVICE_KEY를 설정해주세요!")
        print("공공데이터포털(https://www.data.go.kr)에서 인증키를 발급받을 수 있습니다.")
        return
    
    # API 초기화
    api = BusRouteAPI(SERVICE_KEY, BASE_URL)
    
    # DB 초기화 (저장이 필요한 경우)
    db = None
    if save_to_db:
        try:
            db = BusRouteDatabase()
        except Exception as e:
            print(f"\n[경고] 데이터베이스 연결 실패: {e}")
            print("API 조회는 계속 진행하지만 DB 저장은 하지 않습니다.")
            save_to_db = False
    
    try:
        # XML 형식으로 조회
        print("\n1. API 호출 중...")
        result_xml = api.get_city_code_list(data_type='xml')
        print_result("도시코드 목록 (XML)", result_xml)
        
        # 도시코드 목록 출력 및 DB 저장
        if 'body' in result_xml and 'items' in result_xml['body']:
            items = result_xml['body']['items']
            
            print("\n[사용 가능한 도시코드]")
            print("-" * 80)
            for item in items:
                print(f"  코드: {item.get('citycode', 'N/A'):5s} - {item.get('cityname', 'N/A')}")
            print("-" * 80)
            print(f"총 {len(items)}개의 도시코드")
            
            # DB에 저장
            if save_to_db and db:
                print(f"\n데이터베이스에 저장 중...")
                saved_count = db.save_city_codes(items)
                print(f"✓ {saved_count}건의 도시코드가 tago_city_code 테이블에 저장되었습니다.")
                
                # 저장 결과 확인
                print("\n[DB에 저장된 데이터 확인]")
                saved_data = db.get_all_city_codes()
                print(f"총 {len(saved_data)}건의 도시코드가 저장되어 있습니다.")
                
                # DB 통계 출력
                print_db_info(db)
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")
        print("\n가능한 해결 방법:")
        print("1. config.py에서 SERVICE_KEY를 올바르게 설정했는지 확인")
        print("2. 서비스 키가 URL 인코딩된 상태인지 확인 (%2B, %3D 등)")
        print("3. 공공데이터포털에서 서비스 승인 상태 확인")
        print("4. 네트워크 연결 상태 확인")
        print("5. MySQL 연결 정보 확인 (config.py의 DB_CONFIG)")
    finally:
        if db:
            db.close()


if __name__ == "__main__":
    import sys
    
    # 명령줄 인자로 DB 저장 여부 결정
    # python test_city_code.py --no-db  (DB 저장 안함)
    save_to_db = "--no-db" not in sys.argv
    
    test_city_code_list(save_to_db=save_to_db)