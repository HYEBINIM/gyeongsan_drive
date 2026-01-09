"""
test_station_list.py
테스트 4: 노선별경유정류소목록 조회 (MySQL DB 저장 기능 포함)
노선별로 경유하는 정류장의 목록을 조회하고 MySQL DB에 저장합니다.
전체 정류소를 수집하기 위해 페이지네이션을 구현했습니다.
"""

from bus_route_api import BusRouteAPI, print_result
from config import SERVICE_KEY, BASE_URL, DEFAULT_NUM_OF_ROWS, DEFAULT_PAGE_NO, AUTO_SAVE_TO_DB
from database import BusRouteDatabase, print_db_info
import time


def test_station_list(city_code: str = None, route_id: str = None, save_to_db: bool = AUTO_SAVE_TO_DB, fetch_all: bool = True):
    """
    노선별경유정류소목록 조회 테스트 (단일 노선)
    
    Args:
        city_code: 도시코드
        route_id: 노선ID (test_route_list.py에서 확인 가능)
        save_to_db: DB 저장 여부
        fetch_all: 전체 데이터 수집 여부 (True: 모든 페이지 조회, False: 첫 페이지만 조회)
    """
    
    print("\n" + "="*80)
    print("  [테스트 4] 노선별경유정류소목록 조회")
    print("="*80)
    
    # 서비스 키 확인
    if SERVICE_KEY == "여기에_발급받은_서비스키를_입력하세요":
        print("\n[경고] config.py 파일에서 SERVICE_KEY를 설정해주세요!")
        return
    
    # 파라미터 입력
    if city_code is None:
        print("\n※ 노선ID는 test_route_list.py를 실행하여 확인할 수 있습니다.")
        print("\n사용 가능한 도시코드 예시:")
        print("  22 - 대구광역시")
        print("  25 - 대전광역시")
        print("  37100 - 경산시")
        city_code = input("\n도시코드를 입력하세요: ").strip()
    
    if not city_code:
        print("도시코드를 입력하지 않았습니다.")
        return
    
    if route_id is None:
        print("\n노선ID 예시:")
        print("  대전 5번 버스: DJB30300004")
        print("  경산 509번: GYB3000509002")
        route_id = input("\n노선ID를 입력하세요: ").strip()
    
    if not route_id:
        print("노선ID를 입력하지 않았습니다.")
        return
    
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
        print(f"  노선ID: {route_id}")
        print(f"  데이터 수집 모드: {'전체 수집' if fetch_all else '첫 페이지만'}")
        
        all_items = []
        page_no = 1
        total_count = 0
        
        # 전체 데이터 수집
        if fetch_all:
            print("\n전체 정류소 데이터를 수집합니다...")
            
            while True:
                print(f"\n페이지 {page_no} 조회 중...")
                result = api.get_route_through_station_list(
                    city_code=city_code,
                    route_id=route_id,
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
                        print(f"총 {total_count}개의 정류소를 경유합니다.")
                    
                    print(f"  → {len(items)}건 수집 완료 (누적: {len(all_items)}건)")
                    
                    # 모든 데이터를 수집했으면 종료
                    if len(all_items) >= total_count:
                        break
                    
                    page_no += 1
                else:
                    break
            
            print(f"\n✓ 총 {len(all_items)}건의 정류소 데이터를 수집했습니다.")
            
        else:
            # 첫 페이지만 조회
            print("\nAPI 호출 중...")
            result = api.get_route_through_station_list(
                city_code=city_code,
                route_id=route_id,
                num_of_rows=DEFAULT_NUM_OF_ROWS,
                page_no=DEFAULT_PAGE_NO
            )
            
            print_result("경유 정류소 목록", result)
            
            if 'body' in result and 'items' in result['body']:
                all_items = result['body']['items']
                total_count = int(result['body'].get('totalCount', 0))
        
        # 결과 상세 출력
        if all_items:
            print("\n[정류소 목록 상세]")
            print("="*80)
            print(f"수집된 정류소: {len(all_items)}개")
            if total_count > len(all_items):
                print(f"전체 정류소: {total_count}개 (일부만 수집됨)")
            print("="*80)
            
            # 처음 10개만 출력
            display_count = min(10, len(all_items))
            for item in all_items[:display_count]:
                updown = "상행" if item.get('updowncd', '0') == '0' else "하행"
                print(f"\n[{item.get('nodeord', 'N/A')}번째 정류소] {updown}")
                print(f"  정류소명: {item.get('nodenm', 'N/A')}")
                print(f"  정류소ID: {item.get('nodeid', 'N/A')}")
                print(f"  정류소번호: {item.get('nodeno', 'N/A')}")
                print(f"  좌표: 위도 {item.get('gpslati', 'N/A')}, 경도 {item.get('gpslong', 'N/A')}")
            
            if len(all_items) > display_count:
                print(f"\n... 외 {len(all_items) - display_count}개 정류소")
            print("="*80)
            
            # DB에 저장
            if save_to_db and db:
                print(f"\n데이터베이스에 저장 중...")
                saved_count = db.save_station_list(all_items)
                print(f"✓ {saved_count}건의 정류소가 tago_route_list 테이블에 저장되었습니다.")
                
                # DB 통계 출력
                print_db_info(db)
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")
        print("\n가능한 해결 방법:")
        print("1. 올바른 도시코드와 노선ID를 입력했는지 확인")
        print("2. test_route_list.py를 실행하여 정확한 노선ID 확인")
        print("3. MySQL 연결 정보 확인 (config.py의 DB_CONFIG)")
    finally:
        if db:
            db.close()


def collect_all_routes_stations(city_code: str = None, save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    데이터베이스에 저장된 모든 노선의 경유 정류소를 수집
    
    Args:
        city_code: 도시코드 (선택사항, None이면 전체)
        save_to_db: DB 저장 여부
    """
    
    print("\n" + "="*80)
    print("  [테스트 4-전체] 모든 노선의 경유 정류소 수집")
    print("="*80)
    
    # 서비스 키 확인
    if SERVICE_KEY == "여기에_발급받은_서비스키를_입력하세요":
        print("\n[경고] config.py 파일에서 SERVICE_KEY를 설정해주세요!")
        return
    
    # DB 초기화
    db = None
    try:
        db = BusRouteDatabase()
    except Exception as e:
        print(f"\n[오류] 데이터베이스 연결 실패: {e}")
        return
    
    try:
        # DB에서 노선 목록 조회
        print("\n데이터베이스에서 노선 목록을 조회합니다...")
        routes = db.get_routes_by_city(city_code)
        
        if not routes:
            print(f"\n데이터베이스에 저장된 노선이 없습니다.")
            print("먼저 test_route_list.py를 실행하여 노선 목록을 수집하세요.")
            return
        
        print(f"총 {len(routes)}개의 노선을 찾았습니다.")
        
        # 도시코드 추출
        if not city_code and routes:
            print("\n※ API 호출을 위해 도시코드가 필요합니다.")
            city_code = input("도시코드를 입력하세요: ").strip()
            
            if not city_code:
                print("도시코드를 입력하지 않았습니다.")
                return
        
        # API 초기화
        api = BusRouteAPI(SERVICE_KEY, BASE_URL)
        
        print(f"\n도시코드 {city_code}의 모든 노선의 경유 정류소를 수집합니다...")
        print("="*80)
        
        success_count = 0
        fail_count = 0
        total_stations = 0
        all_stations = []
        
        for idx, route in enumerate(routes, 1):
            route_id = route['routeid']
            route_no = route.get('routeno', 'N/A')
            
            print(f"\n[{idx}/{len(routes)}] 노선 {route_no} (ID: {route_id}) 의 정류소 조회 중...")
            
            try:
                # 전체 정류소 수집 (페이지네이션)
                page_no = 1
                route_stations = []
                
                while True:
                    result = api.get_route_through_station_list(
                        city_code=city_code,
                        route_id=route_id,
                        num_of_rows=100,
                        page_no=page_no
                    )
                    
                    if 'body' in result and 'items' in result['body']:
                        items = result['body']['items']
                        
                        if not items:
                            break
                        
                        route_stations.extend(items)
                        
                        if page_no == 1:
                            total_count = int(result['body'].get('totalCount', 0))
                        
                        # 모든 데이터를 수집했으면 종료
                        if len(route_stations) >= total_count:
                            break
                        
                        page_no += 1
                    else:
                        break
                
                if route_stations:
                    all_stations.extend(route_stations)
                    total_stations += len(route_stations)
                    print(f"  ✓ 성공 ({len(route_stations)}개 정류소)")
                    success_count += 1
                else:
                    print(f"  ✗ 데이터 없음")
                    fail_count += 1
                
                # API 호출 제한을 고려한 대기
                time.sleep(0.5)
                
            except Exception as e:
                print(f"  ✗ 오류: {e}")
                fail_count += 1
                continue
        
        print("\n" + "="*80)
        print(f"수집 완료: 성공 {success_count}건, 실패 {fail_count}건")
        print(f"총 {total_stations}개의 정류소 데이터 수집")
        print("="*80)
        
        # DB에 저장
        if save_to_db and all_stations:
            print(f"\n데이터베이스에 저장 중...")
            saved_count = db.save_station_list(all_stations)
            print(f"✓ {saved_count}건의 정류소가 tago_route_list 테이블에 저장되었습니다.")
            
            # DB 통계 출력
            print_db_info(db)
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")
    finally:
        if db:
            db.close()


if __name__ == "__main__":
    import sys
    
    # 명령줄 인자 처리
    if "--all" in sys.argv:
        # 전체 노선의 정류소 수집 모드
        city_code = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
        save_to_db = "--no-db" not in sys.argv
        collect_all_routes_stations(city_code, save_to_db)
    else:
        # 단일 노선 조회 모드
        city_code = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
        route_id = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else None
        save_to_db = "--no-db" not in sys.argv
        fetch_all = "--first-page-only" not in sys.argv
        test_station_list(city_code, route_id, save_to_db, fetch_all)