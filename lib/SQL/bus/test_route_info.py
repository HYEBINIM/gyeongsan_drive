"""
test_route_info.py
테스트 3: 노선정보항목 조회 (MySQL DB 저장 기능 포함)
노선의 기본정보(운행시간, 배차간격 등)를 조회하고 MySQL DB에 저장합니다.
"""

from bus_route_api import BusRouteAPI, print_result
from config import SERVICE_KEY, BASE_URL, AUTO_SAVE_TO_DB
from database import BusRouteDatabase, print_db_info
import time


def test_route_info(city_code: str = None, route_id: str = None, save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    노선정보항목 조회 테스트 (단일 노선)
    
    Args:
        city_code: 도시코드
        route_id: 노선ID (test_route_list.py에서 확인 가능)
        save_to_db: DB 저장 여부
    """
    
    print("\n" + "="*80)
    print("  [테스트 3] 노선정보항목 조회")
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
        
        # 노선 정보 조회
        print("\nAPI 호출 중...")
        result = api.get_route_info_item(
            city_code=city_code,
            route_id=route_id
        )
        
        print_result("노선 정보", result)
        
        # 결과 상세 출력 및 DB 저장
        if 'body' in result and 'items' in result['body']:
            items = result['body']['items']
            if items:
                item = items[0]
                print("\n[노선 상세 정보]")
                print("="*80)
                print(f"노선번호: {item.get('routeno', 'N/A')}")
                print(f"노선ID: {item.get('routeid', 'N/A')}")
                print(f"노선유형: {item.get('routetp', 'N/A')}")
                print("-"*80)
                print(f"기점: {item.get('startnodenm', 'N/A')}")
                print(f"종점: {item.get('endnodenm', 'N/A')}")
                print("-"*80)
                print(f"첫차시간: {item.get('startvehicletime', 'N/A')}")
                print(f"막차시간: {item.get('endvehicletime', 'N/A')}")
                print("-"*80)
                print(f"배차간격 (평일): {item.get('intervaltime', 'N/A')}분")
                print(f"배차간격 (토요일): {item.get('intervalsattime', 'N/A')}분")
                print(f"배차간격 (일요일): {item.get('intervalsuntime', 'N/A')}분")
                print("="*80)
                
                # DB에 저장
                if save_to_db and db:
                    print(f"\n데이터베이스에 저장 중...")
                    saved_count = db.save_route_info(items)
                    print(f"✓ {saved_count}건의 노선 정보가 tago_stop_info 테이블에 저장되었습니다.")
                    
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


def collect_all_routes_info(city_code: str = None, save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    데이터베이스에 저장된 모든 노선의 상세 정보를 수집
    
    Args:
        city_code: 도시코드 (선택사항, None이면 전체)
        save_to_db: DB 저장 여부
    """
    
    print("\n" + "="*80)
    print("  [테스트 3-전체] 모든 노선의 상세 정보 수집")
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
        # 도시코드 입력
        if not city_code:
            city_code = input("\n도시코드를 입력하세요: ").strip()
            
            if not city_code:
                print("도시코드를 입력하지 않았습니다.")
                return
        
        # DB에서 노선 목록 조회
        print(f"\n데이터베이스에서 도시코드 {city_code}의 노선 목록을 조회합니다...")
        routes = db.get_routes_by_city(city_code)
        
        if not routes:
            print(f"\n도시코드 {city_code}에 해당하는 노선이 데이터베이스에 없습니다.")
            print("먼저 test_route_list.py를 실행하여 노선 목록을 수집하세요.")
            return
        
        print(f"총 {len(routes)}개의 노선을 찾았습니다.")
        
        # API 초기화
        api = BusRouteAPI(SERVICE_KEY, BASE_URL)
        
        print(f"\n도시코드 {city_code}의 모든 노선 정보를 수집합니다...")
        print("="*80)
        
        success_count = 0
        fail_count = 0
        all_route_info = []
        
        for idx, route in enumerate(routes, 1):
            route_id = route['routeid']
            route_no = route.get('routeno', 'N/A')
            
            print(f"\n[{idx}/{len(routes)}] 노선 {route_no} (ID: {route_id}) 조회 중...")
            
            try:
                result = api.get_route_info_item(
                    city_code=city_code,
                    route_id=route_id
                )
                
                if 'body' in result and 'items' in result['body']:
                    items = result['body']['items']
                    if items:
                        all_route_info.extend(items)
                        print(f"  ✓ 성공")
                        success_count += 1
                    else:
                        print(f"  ✗ 데이터 없음")
                        fail_count += 1
                else:
                    print(f"  ✗ 응답 오류")
                    fail_count += 1
                
                # API 호출 제한을 고려한 대기 (초당 1회 정도)
                time.sleep(0.5)
                
            except Exception as e:
                print(f"  ✗ 오류: {e}")
                fail_count += 1
                continue
        
        print("\n" + "="*80)
        print(f"수집 완료: 성공 {success_count}건, 실패 {fail_count}건")
        print("="*80)
        
        # DB에 저장 (city_code 전달)
        if save_to_db and all_route_info:
            print(f"\n데이터베이스에 저장 중...")
            saved_count = db.save_route_info(all_route_info, city_code=city_code)
            print(f"✓ {saved_count}건의 노선 정보가 tago_stop_info 테이블에 저장되었습니다.")
            
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
        # 전체 노선 정보 수집 모드
        city_code = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
        save_to_db = "--no-db" not in sys.argv
        collect_all_routes_info(city_code, save_to_db)
    else:
        # 단일 노선 조회 모드
        city_code = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
        route_id = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else None
        save_to_db = "--no-db" not in sys.argv
        test_route_info(city_code, route_id, save_to_db)