"""
run_all_tests.py
버스노선정보조회 API 통합 테스트 프로그램 (MySQL DB 저장 기능 포함)
모든 기능을 한 번에 테스트하거나 개별 테스트를 선택할 수 있습니다.
"""

from bus_route_api import BusRouteAPI, print_result
from config import SERVICE_KEY, BASE_URL, AUTO_SAVE_TO_DB
import test_city_code
import test_route_list
import test_route_info
import test_station_list


def run_all_tests(save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    모든 테스트를 순차적으로 실행
    
    Args:
        save_to_db: DB 저장 여부
    """
    print("\n" + "="*80)
    print("  전체 테스트 실행 (MySQL DB 저장)")
    print("="*80)
    
    # 서비스 키 확인
    if SERVICE_KEY == "여기에_발급받은_서비스키를_입력하세요":
        print("\n[경고] config.py 파일에서 SERVICE_KEY를 설정해주세요!")
        print("공공데이터포털(https://www.data.go.kr)에서 인증키를 발급받을 수 있습니다.")
        return
    
    try:
        # 테스트 1: 도시코드 목록 조회
        print("\n" + "#"*80)
        print("# 테스트 1: 도시코드 목록 조회 → tago_city_code 테이블")
        print("#"*80)
        test_city_code.test_city_code_list(save_to_db=save_to_db)
        
        input("\n계속하려면 Enter를 누르세요...")
        
        # 테스트 2: 노선번호목록 조회 (대전 5번 버스 예제)
        print("\n" + "#"*80)
        print("# 테스트 2: 노선번호목록 조회 (예제: 대전 5번) → tago_route_id 테이블")
        print("#"*80)
        test_route_list.test_route_no_list(city_code='25', route_no='5', save_to_db=save_to_db, fetch_all=True)
        
        input("\n계속하려면 Enter를 누르세요...")
        
        # 테스트 3: 노선정보항목 조회 (DJB30300004 예제)
        print("\n" + "#"*80)
        print("# 테스트 3: 노선정보항목 조회 (예제: DJB30300004) → tago_stop_info 테이블")
        print("#"*80)
        test_route_info.test_route_info(city_code='25', route_id='DJB30300004', save_to_db=save_to_db)
        
        input("\n계속하려면 Enter를 누르세요...")
        
        # 테스트 4: 노선별경유정류소목록 조회 (DJB30300004 예제)
        print("\n" + "#"*80)
        print("# 테스트 4: 노선별경유정류소목록 조회 (예제: DJB30300004) → tago_route_list 테이블")
        print("#"*80)
        test_station_list.test_station_list(city_code='25', route_id='DJB30300004', save_to_db=save_to_db, fetch_all=True)
        
        print("\n" + "="*80)
        print("  전체 테스트 완료!")
        print("="*80)
        
        # MySQL 데이터 확인 안내
        if save_to_db:
            print("\n[MySQL 데이터 확인]")
            print("MySQL에 접속하여 다음 쿼리로 저장된 데이터를 확인할 수 있습니다:")
            print("-" * 80)
            print("SELECT COUNT(*) FROM tago_city_code;      -- 도시코드")
            print("SELECT COUNT(*) FROM tago_route_id;       -- 노선")
            print("SELECT COUNT(*) FROM tago_stop_info;      -- 노선상세정보")
            print("SELECT COUNT(*) FROM tago_route_list;     -- 정류소")
            print("-" * 80)
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")


def collect_all_city_data(save_to_db: bool = AUTO_SAVE_TO_DB):
    """
    특정 도시의 모든 데이터를 수집 (노선 목록 → 노선 정보 → 정류소)
    
    Args:
        save_to_db: DB 저장 여부
    """
    print("\n" + "="*80)
    print("  특정 도시의 전체 데이터 수집 (완전 자동화)")
    print("="*80)
    
    city_code = input("\n도시코드를 입력하세요 (예: 25-대전, 37100-경산): ").strip()
    
    if not city_code:
        print("도시코드를 입력하지 않았습니다.")
        return
    
    print(f"\n도시코드 {city_code}의 전체 데이터를 수집합니다...")
    print("="*80)
    
    try:
        # 1단계: 노선 목록 수집
        print("\n[1단계] 노선 목록 수집")
        print("-"*80)
        test_route_list.test_route_no_list(city_code=city_code, route_no=None, save_to_db=save_to_db, fetch_all=True)
        
        input("\n1단계 완료. 2단계로 진행하려면 Enter를 누르세요...")
        
        # 2단계: 모든 노선의 상세 정보 수집
        print("\n[2단계] 모든 노선의 상세 정보 수집")
        print("-"*80)
        test_route_info.collect_all_routes_info(city_code=city_code, save_to_db=save_to_db)
        
        input("\n2단계 완료. 3단계로 진행하려면 Enter를 누르세요...")
        
        # 3단계: 모든 노선의 경유 정류소 수집
        print("\n[3단계] 모든 노선의 경유 정류소 수집")
        print("-"*80)
        test_station_list.collect_all_routes_stations(city_code=city_code, save_to_db=save_to_db)
        
        print("\n" + "="*80)
        print(f"  도시코드 {city_code}의 전체 데이터 수집 완료!")
        print("="*80)
        
        # 최종 DB 통계
        if save_to_db:
            from database import BusRouteDatabase, print_db_info
            try:
                db = BusRouteDatabase()
                print("\n[최종 데이터베이스 통계]")
                print_db_info(db)
                db.close()
            except Exception as e:
                print(f"\n[오류] {e}")
        
    except Exception as e:
        print(f"\n[오류 발생] {e}")


def interactive_menu():
    """대화형 메뉴"""
    while True:
        print("\n" + "="*80)
        print("  버스노선정보조회 API 테스트 프로그램 (MySQL DB)")
        print("="*80)
        print("\n테스트할 기능을 선택하세요:")
        print("  1. 도시코드 목록 조회 → tago_city_code")
        print("  2. 노선번호목록 조회 → tago_route_id")
        print("  3. 노선정보항목 조회 (단일) → tago_stop_info")
        print("  4. 노선별경유정류소목록 조회 (단일) → tago_route_list")
        print("  5. 전체 테스트 실행 (예제 데이터)")
        print("-"*80)
        print("  6. 특정 도시 전체 노선 수집")
        print("  7. 모든 노선의 상세 정보 수집")
        print("  8. 모든 노선의 정류소 수집")
        print("  9. 특정 도시 완전 자동화 수집 (1→2→3→4 순차 실행)")
        print("-"*80)
        print("  0. DB 통계 확인")
        print("  Q. 종료")
        print("="*80)
        
        choice = input("\n선택: ").strip().upper()
        
        try:
            if choice == 'Q':
                print("\n프로그램을 종료합니다.")
                break
            elif choice == '1':
                test_city_code.test_city_code_list()
            elif choice == '2':
                test_route_list.test_route_no_list()
            elif choice == '3':
                test_route_info.test_route_info()
            elif choice == '4':
                test_station_list.test_station_list()
            elif choice == '5':
                run_all_tests()
            elif choice == '6':
                city_code = input("\n도시코드를 입력하세요: ").strip()
                if city_code:
                    test_route_list.test_route_no_list(city_code=city_code, route_no=None, save_to_db=True, fetch_all=True)
            elif choice == '7':
                city_code = input("\n도시코드를 입력하세요 (Enter=전체): ").strip() or None
                test_route_info.collect_all_routes_info(city_code=city_code)
            elif choice == '8':
                city_code = input("\n도시코드를 입력하세요 (Enter=전체): ").strip() or None
                test_station_list.collect_all_routes_stations(city_code=city_code)
            elif choice == '9':
                collect_all_city_data()
            elif choice == '0':
                from database import BusRouteDatabase, print_db_info
                try:
                    db = BusRouteDatabase()
                    print_db_info(db)
                    db.close()
                except Exception as e:
                    print(f"\n[오류] {e}")
            else:
                print("\n올바른 번호를 선택해주세요.")
        except Exception as e:
            print(f"\n[오류 발생] {e}")
        
        if choice != 'Q':
            input("\n메뉴로 돌아가려면 Enter를 누르세요...")


def main():
    """메인 함수"""
    print("\n" + "="*80)
    print("  버스노선정보조회 API 테스트 프로그램 (MySQL DB)")
    print("="*80)
    print("\n※ 개별 기능 테스트:")
    print("  - test_city_code.py      : 도시코드 목록 조회")
    print("  - test_route_list.py     : 노선번호목록 조회")
    print("  - test_route_info.py     : 노선정보항목 조회")
    print("  - test_station_list.py   : 경유정류소목록 조회")
    print("\n※ 전체 수집 기능:")
    print("  - python test_route_info.py --all 37100      : 모든 노선 정보 수집")
    print("  - python test_station_list.py --all 37100    : 모든 정류소 수집")
    print("\n실행 모드를 선택하세요:")
    print("  1. 대화형 메뉴 모드")
    print("  2. 전체 테스트 자동 실행")
    print("  3. 특정 도시 완전 자동화 수집")
    
    mode = input("\n선택 (1, 2 또는 3): ").strip()
    
    if mode == '1':
        interactive_menu()
    elif mode == '2':
        run_all_tests()
    elif mode == '3':
        collect_all_city_data()
    else:
        print("\n올바른 모드를 선택해주세요.")


if __name__ == "__main__":
    main()