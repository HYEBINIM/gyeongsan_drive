"""
test_route_list.py
테스트 2: 노선번호목록 조회 (MySQL DB 저장 기능 포함)
버스 노선번호의 목록을 조회하고 MySQL DB에 저장합니다.
전체 노선을 수집하기 위해 페이지네이션을 구현했습니다.
"""

from bus_route_api import BusRouteAPI, print_result
from config import SERVICE_KEY, BASE_URL, DEFAULT_NUM_OF_ROWS, DEFAULT_PAGE_NO, AUTO_SAVE_TO_DB
from database import BusRouteDatabase, print_db_info


def test_route_no_list(city_code: str = None, route_no: str = None, save_to_db: bool = AUTO_SAVE_TO_DB, fetch_all: bool = True):
    """
    노선번호목록 조회 테스트
    
    Args:
        city_code: 도시코드 (예: 25-대전, 22-대구)
        route_no: 노선번호 (선택사항)
        save_to_db: DB 저장 여부
        fetch_all: 전체 데이터 수집 여부 (True: 모든 페이지 조회, False: 첫 페이지만 조회)
    """
    
    print("\n" + "="*80)
    print("  [테스트 2] 노선번호목록 조회")
    print("="*80)
    
    # 서비스 키 확인
    if SERVICE_KEY == "여기에_발급받은_서비스키를_입력하세요":
        print("\n[경고] config.py 파일에서 SERVICE_KEY를 설정해주세요!")
        return
    
    # 파라미터 입력
    if city_code is None:
        print("\n사용 가능한 도시코드 예시:")
        print("  22 - 대구광역시")
        print("  25 - 대전광역시")
        print("  37100 - 경산시")
        print("  (전체 목록은 test_city_code.py를 실행하세요)")
        city_code = input("\n도시코드를 입력하세요: ").strip()
    
    if not city_code:
        print("도시코드를 입력하지 않았습니다.")
        return
    
    if route_no is None:
        route_no = input("노선번호를 입력하세요 (선택사항, Enter로 건너뛰기): ").strip()
        if not route_no:
            route_no = None
    
    # API 초기화
    api = BusRouteAPI(SERVICE_KEY, BASE_URL)
    
    # DB 초기화
    db = None
    if save_to_db:
        try:
            db = BusRouteDatabase()
        except Exception as e:
            print(f"\n[경고] 데이터베이스 연결 실패: {e}")
            print("API 조회는 계속 진행하지만 DB 저장은 하지 않습니다.")
            save_to_db = False
    
    try:
        print(f"\n[조회 조건]")
        print(f"  도시코드: {city_code}")
        print(f"  노선번호: {route_no if route_no else '전체'}")
        print(f"  데이터 수집 모드: {'전체 수집' if fetch_all else '첫 페이지만'}")
        
        all_items = []
        page_no = 1
        total_count = 0
        
        # 전체 데이터 수집
        if fetch_all:
            print("\n전체 노선 데이터를 수집합니다...")
            
            while True:
                print(f"\n페이지 {page_no} 조회 중...")
                result = api.get_route_no_list(
                    city_code=city_code,
                    route_no=route_no,
                    num_of_rows=100,  # 한 번에 100건씩 조회
                    page_no=page_no
                )
                
                if 'body' in result and 'items' in result['body']:
                    items = result['body']['items']
                    
                    if not items:
                        break
                    
                    all_items.extend(items)
                    
                    if page_no == 1:
                        total_count = int(result['body'].get('totalCount', 0))
                        print(f"총 {total_count}건의 노선이 검색되었습니다.")
                    
                    print(f"  → {len(items)}건 수집 완료 (누적: {len(all_items)}건)")
                    
                    # 모든 데이터를 수집했으면 종료
                    if len(all_items) >= total_count:
                        break
                    
                    page_no += 1
                else:
                    break
            
            print(f"\n✓ 총 {len(all_items)}건의 노선 데이터를 수집했습니다.")
            
        else:
            # 첫 페이지만 조회
            print("\nAPI 호출 중...")
            result = api.get_route_no_list(
                city_code=city_code,
                route_no=route_no,
                num_of_rows=DEFAULT_NUM_OF_ROWS,
                page_no=DEFAULT_PAGE_NO
            )
            
            print_result("노선번호 목록", result)
            
            if 'body' in result and 'items' in result['body']:
                all_items = result['body']['items']
                total_count = int(result['body'].get('totalCount', 0))
        
        # 결과 요약 출력
        if all_items:
            print("\n[조회 결과 요약]")
            print("-" * 80)
            print(f"수집된 노선: {len(all_items)}건")
            if total_count > len(all_items):
                print(f"전체 노선: {total_count}건 (일부만 수집됨)")
            print("-" * 80)
            
            # 처음 10개만 출력
            display_count = min(10, len(all_items))
            for idx, item in enumerate(all_items[:display_count], 1):
                print(f"\n{idx}. 노선번호: {item.get('routeno', 'N/A')}")
                print(f"   노선ID: {item.get('routeid', 'N/A')}")
                print(f"   노선유형: {item.get('routetp', 'N/A')}")
                print(f"   기점: {item.get('startnodenm', 'N/A')} → 종점: {item.get('endnodenm', 'N/A')}")
                print(f"   운행시간: {item.get('startvehicletime', 'N/A')} ~ {item.get('endvehicletime', 'N/A')}")
            
            if len(all_items) > display_count:
                print(f"\n... 외 {len(all_items) - display_count}건")
            print("-" * 80)
            
            # DB에 저장 (city_code 전달)
            if save_to_db and db:
                print(f"\n데이터베이스에 저장 중...")
                saved_count = db.save_route_list(all_items, city_code=city_code)
                print(f"✓ {saved_count}건의 노선이 tago_route_id 테이블에 저장되었습니다.")
                
                # DB 통계 출력
                print_db_info(db)
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")
        print("\n가능한 해결 방법:")
        print("1. 올바른 도시코드를 입력했는지 확인")
        print("2. 해당 도시에 입력한 노선번호가 존재하는지 확인")
        print("3. MySQL 연결 정보 확인 (config.py의 DB_CONFIG)")
    finally:
        if db:
            db.close()


if __name__ == "__main__":
    import sys
    
    # 명령줄 인자 처리
    city_code = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
    route_no = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else None
    save_to_db = "--no-db" not in sys.argv
    fetch_all = "--first-page-only" not in sys.argv  # --first-page-only 옵션이 없으면 전체 수집
    
    test_route_no_list(city_code, route_no, save_to_db, fetch_all)