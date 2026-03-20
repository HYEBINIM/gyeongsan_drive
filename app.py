# app.py (전체 코드)

from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql
import requests
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

# ⚠️ DB 연결 설정
DB_CONFIG = {
    'host': '211.58.207.216',  # localhost에서 연결 (원격 IP 대신)
    'port': 3306,
    'user': 'server',
    'password': 'dltmxm1234',
    'database': 'dataset',
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_unicode_ci',
    'use_unicode': True,
}
TABLE_NAME = 'place'
EVENT_TABLE_NAME = 'event'
BUS_STOP_TABLE_NAME = 'tago_station_master'
GYEONGSAN_TOUR_TABLE = 'gyeongsan_tour'

# ODsay API 설정
ODSAY_API_KEY = '7PHOvDn+54Hipnou8ALmKSa3YxNEeH/KFanrKP288Xc'
ODSAY_API_URL = 'https://api.odsay.com/v1/api'

# 캐시 설정
_loadlane_cache = {}  # loadLane API 응답 캐시
CACHE_EXPIRY_MINUTES = 60  # 캐시 유효 시간 (분)

def get_bus_station_indices(bus_id, start_station_id, end_station_id):
    """버스 노선의 전체 정류장 목록에서 승차/하차 정류장의 인덱스 찾기"""
    try:
        # busLaneDetail API로 전체 정류장 목록 조회
        url = f"{ODSAY_API_URL}/busLaneDetail"
        params = {
            'lang': 0,
            'busID': bus_id,
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }

        response = requests.get(url, params=params, timeout=10)

        if response.status_code == 200:
            data = response.json()

            if data.get('result') and data['result'].get('station'):
                stations = data['result']['station']

                start_idx = -1
                end_idx = -1

                # 정류장 ID로 인덱스 찾기
                for i, station in enumerate(stations):
                    station_id = station.get('stationID')

                    if station_id == start_station_id:
                        start_idx = i
                    if station_id == end_station_id:
                        end_idx = i

                    # 둘 다 찾았으면 종료
                    if start_idx != -1 and end_idx != -1:
                        break

                return start_idx, end_idx
        else:
            print(f"⚠️ busLaneDetail API 실패: {response.status_code}")

    except Exception as e:
        print(f"⚠️ get_bus_station_indices 오류: {e}")

    return -1, -1

def get_bus_route_coordinates_with_cache(bus_id):
    """loadLane API 호출 - 전체 노선 (캐싱 적용)"""
    return get_bus_route_segment_with_cache(bus_id, -1, -1)

def get_bus_route_segment_with_cache(bus_id, start_idx=-1, end_idx=-1):
    """loadLane API 호출 - 특정 구간 (캐싱 적용)"""

    # 캐시 키 생성
    cache_key = f"{bus_id}:{start_idx}:{end_idx}"

    # 캐시 확인
    if cache_key in _loadlane_cache:
        cached_data = _loadlane_cache[cache_key]
        cache_time = cached_data['timestamp']

        # 캐시가 유효한지 확인 (1시간 이내)
        if datetime.now() - cache_time < timedelta(minutes=CACHE_EXPIRY_MINUTES):
            print(f"✅ 캐시 사용: {cache_key}, {len(cached_data['coordinates'])}개 좌표")
            return cached_data['coordinates']
        else:
            print(f"⏰ 캐시 만료: {cache_key}")
            del _loadlane_cache[cache_key]

    # 캐시 없음 - loadLane API 호출
    segment_info = f"전체 노선" if start_idx == -1 else f"구간 {start_idx}→{end_idx}"
    print(f"🌐 loadLane API 호출: busID={bus_id}, {segment_info}")

    route_coordinates = []

    try:
        lane_url = f"{ODSAY_API_URL}/loadLane"
        lane_params = {
            'mapObject': f'0:0@{bus_id}:1:{start_idx}:{end_idx}',
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }

        lane_response = requests.get(lane_url, params=lane_params, timeout=10)

        if lane_response.status_code == 200:
            lane_data = lane_response.json()

            if lane_data.get('result') and lane_data['result'].get('lane'):
                lanes = lane_data['result']['lane']

                for lane in lanes:
                    if lane.get('section'):
                        for section in lane['section']:
                            if section.get('graphPos'):
                                for pos in section['graphPos']:
                                    if pos.get('x') and pos.get('y'):
                                        try:
                                            route_coordinates.append({
                                                "lat": float(pos['y']),
                                                "lng": float(pos['x']),
                                                "type": "bus"
                                            })
                                        except (ValueError, TypeError):
                                            continue

                if route_coordinates:
                    # 캐시에 저장
                    _loadlane_cache[cache_key] = {
                        'coordinates': route_coordinates,
                        'timestamp': datetime.now()
                    }
                    print(f"💾 캐시 저장: {cache_key}, {len(route_coordinates)}개 좌표")
                    return route_coordinates
            else:
                if lane_data.get('error'):
                    print(f"⚠️ loadLane API 오류: {lane_data['error']}")
        else:
            print(f"⚠️ loadLane API 실패: {lane_response.status_code}")

    except Exception as e:
        print(f"⚠️ loadLane API 예외: {e}")

    return []

def get_db_connection():
    """데이터베이스 연결 생성 (PyMySQL 사용)"""
    try:
        print(f"🔌 DB 연결 시도: {DB_CONFIG['host']}:{DB_CONFIG['database']}")

        # PyMySQL 연결
        connection = pymysql.connect(
            host=DB_CONFIG['host'],
            port=DB_CONFIG['port'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password'],
            database=DB_CONFIG['database'],
            charset=DB_CONFIG['charset'],
            connect_timeout=10,
            autocommit=True,
            cursorclass=pymysql.cursors.DictCursor  # dictionary 형태로 결과 반환
        )
        print("✅ 데이터베이스 연결 성공")
        return connection
    except pymysql.MySQLError as e:
        print(f"❌ 데이터베이스 연결 실패 (PyMySQL Error): {e}")
        print(f"   Error Code: {e.args[0] if e.args else 'N/A'}")
        print(f"   Host: {DB_CONFIG['host']}")
        print(f"   User: {DB_CONFIG['user']}")
        print(f"   Database: {DB_CONFIG['database']}")
        raise
    except Exception as e:
        print(f"❌ 데이터베이스 연결 실패 (일반 오류): {type(e).__name__}: {e}")
        print(f"   Host: {DB_CONFIG['host']}")
        print(f"   User: {DB_CONFIG['user']}")
        print(f"   Database: {DB_CONFIG['database']}")
        import traceback
        traceback.print_exc()
        raise

def check_table_exists(cursor, table_name):
    """테이블 존재 여부 확인"""
    cursor.execute(f"""
        SELECT COUNT(*) as count
        FROM information_schema.tables 
        WHERE table_schema = '{DB_CONFIG['database']}' 
        AND table_name = '{table_name}'
    """)
    result = cursor.fetchone()
    return result['count'] > 0

def normalize_city_name(city_name):
    """도시명 정규화"""
    prefixes_to_remove = [
        '경상북도 ', '경상남도 ', '전라북도 ', '전라남도 ', 
        '충청북도 ', '충청남도 ', '강원도 ', '경기도 ',
        '제주특별자치도 ', '세종특별자치시 '
    ]
    
    normalized = city_name
    for prefix in prefixes_to_remove:
        if normalized.startswith(prefix):
            normalized = normalized[len(prefix):]
            break
    
    print(f"🔄 도시명 정규화: '{city_name}' -> '{normalized}'")
    return normalized

def get_city_code(cursor, city_name):
    """도시명으로 도시코드 찾기"""
    
    if not check_table_exists(cursor, 'tago_city_code'):
        print(f"⚠️ tago_city_code 테이블이 없습니다.")
        return None
    
    search_queries = [
        city_name,
        normalize_city_name(city_name),
    ]
    
    search_queries = list(dict.fromkeys(search_queries))
    
    for query in search_queries:
        cursor.execute(
            "SELECT citycode FROM tago_city_code WHERE cityname = %s LIMIT 1",
            (query,)
        )
        result = cursor.fetchone()
        if result:
            print(f"✅ 도시코드 발견 (정확 매칭): {query} -> {result['citycode']}")
            return result['citycode']
        
        cursor.execute(
            "SELECT citycode FROM tago_city_code WHERE cityname LIKE %s LIMIT 1",
            (f"%{query}%",)
        )
        result = cursor.fetchone()
        if result:
            print(f"✅ 도시코드 발견 (부분 매칭): {query} -> {result['citycode']}")
            return result['citycode']
    
    city_keywords = ['광역시', '특별시', '특별자치시', '도', '시', '군', '구']
    clean_city = city_name
    for keyword in city_keywords:
        clean_city = clean_city.replace(keyword, '').strip()
    
    if clean_city and clean_city != city_name:
        cursor.execute(
            "SELECT citycode FROM tago_city_code WHERE cityname LIKE %s LIMIT 1",
            (f"%{clean_city}%",)
        )
        result = cursor.fetchone()
        if result:
            print(f"✅ 도시코드 발견 (키워드 매칭): {clean_city} -> {result['citycode']}")
            return result['citycode']
    
    print(f"❌ 도시코드를 찾을 수 없음: {city_name}")
    return None

# ----------------------------------------------------
#  테스트 엔드포인트
# ----------------------------------------------------
@app.route('/api/v1/check-ip', methods=['GET'])
def check_server_ip():
    """서버의 실제 외부 IP 확인"""
    try:
        response = requests.get('https://httpbin.org/ip', timeout=5)
        server_ip = response.json().get('origin', 'Unknown')
        
        return jsonify({
            "server_external_ip": server_ip,
            "registered_ip": "211.58.207.216",
            "client_ip": request.remote_addr,
            "message": f"ODsay API에 {server_ip}를 등록해야 합니다."
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"IP 확인 실패: {str(e)}"}), 500

@app.route('/api/v1/test', methods=['GET'])
def test_connection():
    """데이터베이스 연결 및 테이블 존재 여부 테스트"""
    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                SCHEMA_NAME,
                DEFAULT_CHARACTER_SET_NAME,
                DEFAULT_COLLATION_NAME
            FROM information_schema.SCHEMATA
            WHERE SCHEMA_NAME = DATABASE()
        """)
        db_info = cursor.fetchone()
        
        cursor.execute(f"SELECT COUNT(*) as count FROM {TABLE_NAME}")
        place_count = cursor.fetchone()
        
        cursor.execute(f"SELECT COUNT(*) as count FROM {EVENT_TABLE_NAME}")
        event_count = cursor.fetchone()

        cursor.execute(f"SELECT COUNT(*) as count FROM {BUS_STOP_TABLE_NAME}")
        bus_stop_count = cursor.fetchone()
        
        tago_tables = {}
        tago_counts = {}
        for table in ['tago_city_code', 'tago_route_list', 'tago_stop_info', 'tago_station_master']:
            exists = check_table_exists(cursor, table)
            tago_tables[table] = exists
            if exists:
                cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
                tago_counts[table] = cursor.fetchone()['count']
        
        city_list = []
        if tago_tables.get('tago_city_code'):
            cursor.execute("SELECT citycode, cityname FROM tago_city_code LIMIT 20")
            city_list = cursor.fetchall()
        
        return jsonify({
            "status": "success",
            "database_info": db_info,
            "place_count": place_count['count'],
            "event_count": event_count['count'],
            "bus_stop_count": bus_stop_count['count'],
            "tago_tables": tago_tables,
            "tago_counts": tago_counts,
            "city_list": city_list
        }), 200
        
    except pymysql.MySQLError as err:
        print(f"테스트 오류: {err}")
        return jsonify({"status": "error", "message": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/place/top
# ----------------------------------------------------
@app.route('/api/v1/place/top', methods=['GET'])
def get_top_place():
    location_name = request.args.get('location')
    
    if not location_name:
        location_name = '대구'
    
    target_local = '경상북도 경산시'
    if location_name == '대구':
        target_local = '대구광역시'
    elif location_name == '경산':
        target_local = '경상북도 경산시'
    
    print(f"📍 요청 위치: {location_name} → 검색 지역: {target_local}")

    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = f"""
            SELECT 
                id, location, name, content, category, tel_number, type, local, update_date, search_num 
            FROM {TABLE_NAME}
            WHERE local = %s
            ORDER BY search_num DESC
            LIMIT 100;
        """
        
        cursor.execute(sql, (target_local,))
        results = cursor.fetchall()
        
        print(f"✅ 조회 성공: {len(results)}개 장소 발견")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 데이터베이스 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/place/nearby
# ----------------------------------------------------
@app.route('/api/v1/place/nearby', methods=['GET'])
def get_nearby_places():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        
        if lat is None or lon is None:
            return jsonify({"message": "위도(lat)와 경도(lon)가 필요합니다."}), 400

        print(f"📍 현위치: 위도 {lat}, 경도 {lon}")

    except ValueError:
        return jsonify({"message": "유효하지 않은 위도 또는 경도 형식입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        sql = f"""
            SELECT
                id, location, name, content, category, tel_number, type, local, search_num,
                (6371 * acos(
                    cos(radians(%s)) * cos(radians(SUBSTRING_INDEX(location, ',', 1))) *
                    cos(radians(SUBSTRING_INDEX(location, ',', -1)) - radians(%s)) +
                    sin(radians(%s)) * sin(radians(SUBSTRING_INDEX(location, ',', 1)))
                )) AS distance_km
            FROM {TABLE_NAME}
            WHERE location IS NOT NULL AND location != '' AND location LIKE '%%,%%'
            ORDER BY distance_km
            LIMIT 10;
        """
        
        cursor.execute(sql, (lat, lon, lat))
        results = cursor.fetchall()
        
        print(f"✅ 주변 장소 조회 성공: {len(results)}개")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 데이터베이스 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/event/nearby
# ----------------------------------------------------
@app.route('/api/v1/event/nearby', methods=['GET'])
def get_nearby_events():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        if lat is None or lon is None:
            return jsonify({"message": "위도(lat)와 경도(lon)가 필요합니다."}), 400
        
        if lat < -90 or lat > 90 or lon < -180 or lon > 180:
            return jsonify({"message": "유효하지 않은 위도 또는 경도 범위입니다."}), 400
        
        print(f"📍 현위치: 위도 {lat}, 경도 {lon}")
        if start_date:
            print(f"📅 날짜 필터: {start_date} ~ {end_date}")

    except ValueError:
        return jsonify({"message": "유효하지 않은 파라미터 형식입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        sql = f"""
            SELECT 
                CAST(contentid AS CHAR) as contentid, contenttypeid, title, addr1, addr2, areacode, sigungucode,
                cat1, cat2, cat3, mapx, mapy, tel, zipcode, firstimage, firstimage2,
                createdtime, modifiedtime, eventstartdate, eventenddate,
                (6371 * acos(
                    cos(radians(%s)) * cos(radians(CAST(mapy AS DECIMAL(10,6)))) * 
                    cos(radians(CAST(mapx AS DECIMAL(10,6))) - radians(%s)) + 
                    sin(radians(%s)) * sin(radians(CAST(mapy AS DECIMAL(10,6))))
                )) AS distance_km
            FROM {EVENT_TABLE_NAME}
            WHERE mapx IS NOT NULL AND mapy IS NOT NULL AND mapx != '' AND mapy != ''
                AND CAST(mapx AS DECIMAL(10,6)) != 0 AND CAST(mapy AS DECIMAL(10,6)) != 0
        """
        
        params = [lat, lon, lat]
        
        if start_date:
            sql += " AND eventstartdate >= %s"
            params.append(start_date)
        
        if end_date:
            sql += " AND eventenddate <= %s"
            params.append(end_date)
        
        sql += " ORDER BY distance_km ASC LIMIT 20;"
        
        cursor.execute(sql, tuple(params))
        results = cursor.fetchall()
        
        print(f"✅ 문화 행사 조회 성공: {len(results)}개")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 데이터베이스 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/bus/nearby
# ----------------------------------------------------

@app.route('/api/v1/bus/nearby', methods=['GET'])
def get_nearby_bus_stops():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        radius = request.args.get('radius', type=int, default=1)

        if lat is None or lon is None:
            return jsonify({"message": "위도(lat)와 경도(lon)가 필요합니다."}), 400

        if lat < -90 or lat > 90 or lon < -180 or lon > 180:
            return jsonify({"message": "유효하지 않은 위도 또는 경도 범위입니다."}), 400

        if radius < 1 or radius > 10:
            return jsonify({"message": "검색 반경은 1km ~ 10km 사이여야 합니다."}), 400

        print(f"🚌 버스 정류장 검색 - 현위치: 위도 {lat}, 경도 {lon}, 반경 {radius}km")

    except ValueError:
        return jsonify({"message": "유효하지 않은 파라미터 형식입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        sql = f"""
            SELECT
                id, citycode, nodeid, nodeno, nodenm, gpslati, gpslong, created_at, updated_at,
                (6371 * acos(
                    cos(radians(%s)) * cos(radians(gpslati)) * cos(radians(gpslong) - radians(%s)) +
                    sin(radians(%s)) * sin(radians(gpslati))
                )) AS distance_km
            FROM {BUS_STOP_TABLE_NAME}
            HAVING distance_km <= %s
            ORDER BY distance_km ASC
            LIMIT 50;
        """

        cursor.execute(sql, (lat, lon, lat, radius))
        results = cursor.fetchall()

        # ⭐ Dart 모델에 맞게 필드명 변환
        transformed_results = []
        for row in results:
            # citycode를 도시명으로 변환
            cursor.execute("SELECT cityname FROM tago_city_code WHERE citycode = %s", (row['citycode'],))
            city_result = cursor.fetchone()
            city_name = city_result['cityname'] if city_result else '경산'

            transformed_results.append({
                'id': row['id'],
                'stop_code': row['nodeid'],      # ⭐ nodeid를 stop_code로
                'stop_name': row['nodenm'],      # ⭐ nodenm을 stop_name으로
                'lat': float(row['gpslati']) if row['gpslati'] else 0.0,
                'lon': float(row['gpslong']) if row['gpslong'] else 0.0,
                'mobile_code': row['nodeno'],    # ⭐ nodeno를 mobile_code로
                'city_name': city_name,           # ⭐ citycode를 도시명으로 변환
                'distance_km': float(row['distance_km']) if row['distance_km'] else 0.0,
            })

        print(f"✅ 주변 버스 정류장 조회 성공: {len(transformed_results)}개")
        return jsonify(transformed_results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 버스 정류장 DB 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/bus/stop/<stop_code>/routes
# ----------------------------------------------------
@app.route('/api/v1/bus/stop/<stop_code>/routes', methods=['GET'])
def get_bus_routes_at_stop(stop_code):
    try:
        city = request.args.get('city', default='경산', type=str)

        # ⭐ 빈 값 검증 추가
        if not stop_code or stop_code.strip() == '':
            return jsonify({"message": "정류장 ID(stop_code)가 필요합니다."}), 400

        if not city or city.strip() == '':
            return jsonify({"message": "도시명(city)이 필요합니다."}), 400

        print(f"🚌 노선 조회 - 정류장: {stop_code}, 도시: {city}")

    except ValueError:
        return jsonify({"message": "유효하지 않은 파라미터입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if not check_table_exists(cursor, 'tago_city_code'):
            print(f"⚠️ tago_city_code 테이블이 존재하지 않습니다.")
            return jsonify([]), 200

        if not check_table_exists(cursor, 'tago_route_list') or not check_table_exists(cursor, 'tago_stop_info'):
            print(f"⚠️ 필요한 tago 테이블이 존재하지 않습니다.")
            return jsonify([]), 200

        city_code = get_city_code(cursor, city)

        if not city_code:
            print(f"⚠️ 도시를 찾을 수 없음: {city}")
            return jsonify([]), 200

        print(f"✅ 도시코드: {city_code}")

        # ⭐ 방향 정보 포함된 SQL (nodeord, updowncd 추가)
        sql = """
            SELECT DISTINCT
                si.routeid as route_id,
                si.routeno as route_name,
                si.routetp as route_type,
                si.startnodenm as start_stop,
                si.endnodenm as end_stop,
                si.startvehicletime as first_bus_time,
                si.endvehicletime as last_bus_time,
                si.intervaltime as interval_weekday,
                si.intervalsattime as interval_saturday,
                si.intervalsuntime as interval_sunday,
                rl.nodeord as current_stop_order,
                rl.updowncd as direction_code,
                '운수회사' as company_name,
                %s as city_name
            FROM tago_route_list rl
            JOIN tago_stop_info si ON rl.routeid = si.routeid AND rl.citycode = si.citycode
            WHERE rl.nodeid = %s AND rl.citycode = %s
            ORDER BY
                CASE
                    WHEN si.routetp = '4' THEN 1
                    WHEN si.routetp = '2' THEN 2
                    WHEN si.routetp = '1' THEN 3
                    WHEN si.routetp = '3' THEN 4
                    ELSE 5
                END,
                CAST(si.routeno AS UNSIGNED),
                si.routeno,
                rl.updowncd
        """

        print(f"🔍 정류장 {stop_code}을 경유하는 노선 검색 중... (nodeid 기준)")
        cursor.execute(sql, (city, stop_code, city_code))
        results = cursor.fetchall()

        # ⭐ 방향 텍스트 추가
        for row in results:
            # updowncd: 0=상행, 1=하행
            direction_code = row.get('direction_code', '0')
            start_stop = row.get('start_stop', '')
            end_stop = row.get('end_stop', '')

            # 방향 텍스트 생성
            if direction_code == '0':
                # 상행 = 종점 방면
                direction_text = f"{end_stop} 방면" if end_stop else "상행"
            else:
                # 하행 = 시작점 방면
                direction_text = f"{start_stop} 방면" if start_stop else "하행"

            row['direction_text'] = direction_text

        print(f"✅ 경유 노선 조회 성공: {len(results)}개")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 버스 노선 DB 오류: {err}")
        if err.errno == 1146:
            return jsonify([]), 200
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/bus/route/<route_id>/stops
# ----------------------------------------------------
@app.route('/api/v1/bus/route/<route_id>/stops', methods=['GET'])
def get_bus_route_stops(route_id):
    try:
        city = request.args.get('city', default='경산', type=str)
        
        print(f"🚏 정류장 조회 - 노선ID: {route_id}, 도시: {city}")

    except ValueError:
        return jsonify({"message": "유효하지 않은 파라미터입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if not check_table_exists(cursor, 'tago_city_code'):
            print(f"⚠️ tago_city_code 테이블이 존재하지 않습니다.")
            return jsonify([]), 200

        if not check_table_exists(cursor, 'tago_route_list'):
            print(f"⚠️ tago_route_list 테이블이 존재하지 않습니다.")
            return jsonify([]), 200

        city_code = get_city_code(cursor, city)
        
        if not city_code:
            print(f"⚠️ 도시를 찾을 수 없음: {city}")
            return jsonify([]), 200
        
        print(f"✅ 도시코드: {city_code}")

        sql = """
            SELECT 
                nodeid as stop_id,
                nodenm as stop_name,
                nodeno as stop_code,
                CAST(nodeord AS UNSIGNED) as sequence,
                CAST(gpslati AS DECIMAL(10,8)) as lat,
                CAST(gpslong AS DECIMAL(11,8)) as lon,
                updowncd as direction
            FROM tago_route_list
            WHERE routeid = %s AND citycode = %s
            ORDER BY CAST(nodeord AS UNSIGNED)
        """
        
        print(f"🔍 노선 {route_id}의 정류장 검색 중...")
        cursor.execute(sql, (route_id, city_code))
        results = cursor.fetchall()
        
        for stop in results:
            if stop['lat'] is not None:
                stop['lat'] = float(stop['lat'])
            if stop['lon'] is not None:
                stop['lon'] = float(stop['lon'])
        
        print(f"✅ 노선 정류장 조회 성공: {len(results)}개")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 노선 정류장 DB 오류: {err}")
        if err.errno == 1146:
            return jsonify([]), 200
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  API 엔드포인트: /api/v1/bus/route/<route_id>/places
#  ⭐ 버스 노선 주변 맛집/관광지/행사 검색 (수정됨)
# ----------------------------------------------------
@app.route('/api/v1/bus/route/<route_id>/places', methods=['GET'])
def get_bus_route_places(route_id):
    try:
        city = request.args.get('city', default='경산', type=str)
        radius_km = request.args.get('radius', default=0.5, type=float)
        
        print(f"🍴 노선 주변 장소 조회 - 노선ID: {route_id}, 도시: {city}, 반경: {radius_km}km")

    except ValueError:
        return jsonify({"message": "유효하지 않은 파라미터입니다."}), 400

    conn = None
    cursor = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if not check_table_exists(cursor, 'tago_city_code') or not check_table_exists(cursor, 'tago_route_list'):
            print(f"⚠️ 필요한 tago 테이블이 존재하지 않습니다.")
            return jsonify({"restaurants": [], "attractions": [], "events": []}), 200

        city_code = get_city_code(cursor, city)
        
        if not city_code:
            print(f"⚠️ 도시를 찾을 수 없음: {city}")
            return jsonify({"restaurants": [], "attractions": [], "events": []}), 200
        
        print(f"✅ 도시코드: {city_code}")

        # 노선의 정류장 좌표 가져오기
        sql = """
            SELECT 
                CAST(gpslati AS DECIMAL(10,8)) as lat,
                CAST(gpslong AS DECIMAL(11,8)) as lon
            FROM tago_route_list
            WHERE routeid = %s AND citycode = %s
            AND gpslati IS NOT NULL AND gpslong IS NOT NULL
            ORDER BY CAST(nodeord AS UNSIGNED)
        """
        
        cursor.execute(sql, (route_id, city_code))
        stops = cursor.fetchall()
        
        if not stops:
            print(f"⚠️ 노선 정류장을 찾을 수 없음")
            return jsonify({"restaurants": [], "attractions": [], "events": []}), 200
        
        print(f"✅ 노선 정류장 {len(stops)}개")
        
        # 각 정류장 주변 장소 검색 (중복 제거)
        places_dict = {}
        events_dict = {}
        
        for stop in stops:
            lat = float(stop['lat'])
            lon = float(stop['lon'])
            
            # ⭐ 맛집 검색 (type=6, search_num 순)
            restaurant_sql = f"""
                SELECT DISTINCT
                    id, location, name, content, category, tel_number, type, local, search_num,
                    (6371 * acos(
                        cos(radians(%s)) * cos(radians(SUBSTRING_INDEX(location, ',', 1))) *
                        cos(radians(SUBSTRING_INDEX(location, ',', -1)) - radians(%s)) +
                        sin(radians(%s)) * sin(radians(SUBSTRING_INDEX(location, ',', 1)))
                    )) AS distance_km
                FROM {TABLE_NAME}
                WHERE location IS NOT NULL AND location != '' AND location LIKE '%%,%%'
                    AND type = 6
                HAVING distance_km <= %s
                ORDER BY search_num DESC, distance_km ASC
                LIMIT 30
            """
            
            cursor.execute(restaurant_sql, (lat, lon, lat, radius_km))
            nearby_restaurants = cursor.fetchall()
            
            for place in nearby_restaurants:
                if place['id'] not in places_dict:
                    places_dict[place['id']] = place
            
            # 관광지 검색 (type != 6 인 것들 중에서)
            attraction_sql = f"""
                SELECT DISTINCT
                    id, location, name, content, category, tel_number, type, local, search_num,
                    (6371 * acos(
                        cos(radians(%s)) * cos(radians(SUBSTRING_INDEX(location, ',', 1))) *
                        cos(radians(SUBSTRING_INDEX(location, ',', -1)) - radians(%s)) +
                        sin(radians(%s)) * sin(radians(SUBSTRING_INDEX(location, ',', 1)))
                    )) AS distance_km
                FROM {TABLE_NAME}
                WHERE location IS NOT NULL AND location != '' AND location LIKE '%%,%%'
                    AND type != 6 AND type IN (3, 4, 5)
                HAVING distance_km <= %s
                ORDER BY search_num DESC, distance_km ASC
                LIMIT 30
            """
            
            cursor.execute(attraction_sql, (lat, lon, lat, radius_km))
            nearby_attractions = cursor.fetchall()
            
            for place in nearby_attractions:
                place_id = f"attraction_{place['id']}"
                if place_id not in places_dict:
                    places_dict[place_id] = place
            
            # 이벤트 검색
            event_sql = f"""
                SELECT DISTINCT
                    contentid, contenttypeid, title, addr1, addr2, areacode, sigungucode,
                    cat1, cat2, cat3, mapx, mapy, tel, zipcode, firstimage, firstimage2,
                    createdtime, modifiedtime, eventstartdate, eventenddate,
                    (6371 * acos(
                        cos(radians(%s)) * cos(radians(CAST(mapy AS DECIMAL(10,6)))) * 
                        cos(radians(CAST(mapx AS DECIMAL(10,6))) - radians(%s)) + 
                        sin(radians(%s)) * sin(radians(CAST(mapy AS DECIMAL(10,6))))
                    )) AS distance_km
                FROM {EVENT_TABLE_NAME}
                WHERE mapx IS NOT NULL AND mapy IS NOT NULL AND mapx != '' AND mapy != ''
                    AND CAST(mapx AS DECIMAL(10,6)) != 0 AND CAST(mapy AS DECIMAL(10,6)) != 0
                HAVING distance_km <= %s
                ORDER BY distance_km
                LIMIT 20
            """
            
            cursor.execute(event_sql, (lat, lon, lat, radius_km))
            nearby_events = cursor.fetchall()
            
            for event in nearby_events:
                if event['contentid'] not in events_dict:
                    events_dict[event['contentid']] = event
        
        # 맛집만 추출 (이미 type=6으로 필터링되어 있음)
        restaurants = [p for p in places_dict.values() if isinstance(p.get('id'), int)]
        
        # 관광지 추출
        attractions = [p for p in places_dict.values() if not isinstance(p.get('id'), int)]
        
        # 행사
        events = list(events_dict.values())
        
        # search_num 기준 정렬
        restaurants.sort(key=lambda x: (x.get('search_num', 0), -x.get('distance_km', 999)), reverse=True)
        attractions.sort(key=lambda x: (x.get('search_num', 0), -x.get('distance_km', 999)), reverse=True)
        
        print(f"✅ 맛집: {len(restaurants)}개 (type=6), 관광지: {len(attractions)}개, 행사: {len(events)}개")
        
        return jsonify({
            "restaurants": restaurants[:30],
            "attractions": attractions[:20],
            "events": events[:20]
        }), 200

    except pymysql.MySQLError as err:
        print(f"❌ 노선 주변 장소 DB 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ----------------------------------------------------
#  API 엔드포인트: /api/v1/place/search
# ----------------------------------------------------
@app.route('/api/v1/place/search', methods=['GET'])
def search_places():
    query = request.args.get('query', '')
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    
    if not query:
        return jsonify({"message": "검색어가 필요합니다."}), 400
    
    print(f"🔍 장소 검색: '{query}', 위치: ({lat}, {lon})")
    
    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 검색어로 이름 검색 (LIKE 사용)
        if lat is not None and lon is not None:
            # 현재 위치가 있으면 거리 계산하여 정렬
            sql = f"""
                SELECT 
                    id, location, name, content, category, tel_number, type, local, update_date, search_num,
                    (6371 * acos(
                        cos(radians(%s)) * cos(radians(SUBSTRING_INDEX(location, ',', 1))) *
                        cos(radians(SUBSTRING_INDEX(location, ',', -1)) - radians(%s)) +
                        sin(radians(%s)) * sin(radians(SUBSTRING_INDEX(location, ',', 1)))
                    )) AS distance_km
                FROM {TABLE_NAME}
                WHERE (name LIKE %s OR content LIKE %s OR category LIKE %s)
                    AND location IS NOT NULL AND location != '' AND location LIKE '%%,%%'
                ORDER BY distance_km ASC, search_num DESC
                LIMIT 50;
            """
            search_pattern = f'%{query}%'
            cursor.execute(sql, (lat, lon, lat, search_pattern, search_pattern, search_pattern))
        else:
            # 현재 위치 없으면 검색 횟수로 정렬
            sql = f"""
                SELECT 
                    id, location, name, content, category, tel_number, type, local, update_date, search_num
                FROM {TABLE_NAME}
                WHERE name LIKE %s OR content LIKE %s OR category LIKE %s
                ORDER BY search_num DESC
                LIMIT 50;
            """
            search_pattern = f'%{query}%'
            cursor.execute(sql, (search_pattern, search_pattern, search_pattern))
        
        results = cursor.fetchall()
        
        print(f"✅ 검색 결과: {len(results)}개")
        return jsonify(results), 200

    except pymysql.MySQLError as err:
        print(f"❌ 검색 오류: {err}")
        return jsonify({"message": "데이터베이스 조회 오류", "error": str(err)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ----------------------------------------------------
#  ODSAY 기반 버스 실제 도로 경로 보여주는 엔드포인트 
# ----------------------------------------------------

@app.route('/api/v1/odsay/bus/route/detail', methods=['GET'])
def get_bus_route_detail_odsay():
    """ODsay API로 버스노선 상세정보 조회 (DB의 route_id를 버스번호로 변환 후 검색)"""
    bus_id = request.args.get('busID')
    
    if not bus_id:
        return jsonify({"message": "busID가 필요합니다."}), 400
    
    conn = None
    cursor = None
    
    try:
        # DB routeid 보존 (loadLane에서 사용)
        db_route_id = bus_id
        odsay_bus_id = bus_id

        # DB 스타일 route_id (예: DGB4070001100)인 경우 routeno를 찾아서 ODsay API로 검색
        if bus_id.startswith('DGB'):
            print(f"🔄 DB route_id를 버스번호로 변환: {bus_id}")

            conn = get_db_connection()
            cursor = conn.cursor()

            # tago_route_id 테이블에서 routeno 조회
            cursor.execute("SELECT routeno FROM tago_route_id WHERE routeid = %s", (bus_id,))
            result = cursor.fetchone()

            if not result:
                print(f"❌ DB에서 routeid {bus_id}를 찾을 수 없음")
                return jsonify({"error": "해당 routeid를 찾을 수 없음"}), 404

            bus_no = result['routeno']
            print(f"✅ routeid {bus_id} → 버스번호: {bus_no}")

            # 버스번호로 ODsay API에서 버스ID 검색
            search_url = f"{ODSAY_API_URL}/searchBusLane"
            search_params = {
                'lang': 0,
                'busNo': bus_no,
                'apiKey': ODSAY_API_KEY,
                'output': 'json'
            }

            search_response = requests.get(search_url, params=search_params, timeout=15)

            if search_response.status_code == 200:
                search_data = search_response.json()
                if search_data.get('result') and search_data['result'].get('lane'):
                    lanes = search_data['result']['lane']
                    if lanes:
                        # 첫 번째 노선 선택
                        odsay_bus_id = lanes[0]['busID']
                        print(f"✅ ODsay 버스ID 찾음: {bus_no} → {odsay_bus_id}")
                    else:
                        print(f"❌ ODsay에서 버스번호 {bus_no}를 찾을 수 없음")
                        return jsonify({"error": f"ODsay에서 버스번호 {bus_no}를 찾을 수 없음"}), 404
                else:
                    print(f"❌ ODsay 버스 검색 실패: {bus_no}")
                    return jsonify({"error": f"ODsay에서 버스번호 {bus_no} 검색 실패"}), 404
            else:
                print(f"❌ ODsay 버스 검색 API 실패: {search_response.status_code}")
                return jsonify({"error": "ODsay 버스 검색 API 실패"}), search_response.status_code

        print(f"🚌 ODsay API로 버스노선 상세정보 조회: {odsay_bus_id}")
        
        # ODsay busLaneDetail API 호출
        url = f"{ODSAY_API_URL}/busLaneDetail"
        params = {
            'lang': 0,
            'busID': odsay_bus_id,
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }
        
        response = requests.get(url, params=params, timeout=15)
        print(f"📍 ODsay busLaneDetail 응답: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()

            if data.get('result'):
                result = data['result']
                stations = result.get('station', [])
                print(f"✅ ODsay 버스상세 조회 성공: {len(stations)}개 정류장")

                # busLaneDetail 응답에서 사용 가능한 ID 확인
                print(f"🔍 busLaneDetail 응답의 ID 정보:")
                print(f"   - busID: {result.get('busID')}")
                print(f"   - busRouteId: {result.get('busRouteId')}")
                print(f"   - busLocalBlID: {result.get('busLocalBlID')}")
                print(f"   - routeID: {result.get('routeID')}")
                print(f"   - busNo: {result.get('busNo')}")
                print(f"   - busName: {result.get('busName')}")
                print(f"   - companyID: {result.get('companyID')}")

                # loadLane API로 노선 그래픽 데이터(실제 도로 경로) 조회
                print(f"🛣️ ODsay loadLane API로 노선 그래픽 데이터 조회: busID={odsay_bus_id}")
                route_coordinates = get_bus_route_coordinates_with_cache(odsay_bus_id)

                # 경로 좌표가 없으면 정류장 좌표 사용
                if not route_coordinates:
                    print("📍 정류장 좌표 사용 (대체)")
                    for station in stations:
                        x = station.get('x')
                        y = station.get('y')
                        if x and y:
                            route_coordinates.append({
                                "lat": float(y),
                                "lng": float(x),
                                "type": "bus",
                                "stationName": station.get('stationName', '')
                            })

                # 응답에 경로 좌표 추가
                data['result']['routeCoordinates'] = route_coordinates
                data['result']['totalRoutePoints'] = len(route_coordinates)

                print(f"✅ 노선 실제 도로 경로 생성 완료: {len(route_coordinates)}개 좌표")

                # ODsay API 응답 + 경로 좌표 반환
                return jsonify(data), 200
            elif data.get('error'):
                print(f"❌ ODsay API 오류: {data['error']}")
                return jsonify({"error": "ODsay API 오류", "details": data['error']}), 400
            else:
                print("❌ ODsay 버스 상세정보 없음")
                return jsonify({"error": "버스 상세정보 없음"}), 404
        else:
            print(f"❌ ODsay API 실패: {response.status_code}")
            error_text = response.text if response.text else "Unknown error"
            return jsonify({"error": "ODsay API 호출 실패", "details": error_text}), response.status_code
            
    except requests.exceptions.Timeout:
        print("❌ ODsay API 타임아웃")
        return jsonify({"error": "API 타임아웃"}), 408
    except Exception as e:
        print(f"❌ ODsay API 오류: {e}")
        return jsonify({"error": f"서버 오류: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route('/api/v1/odsay/search/bus', methods=['GET'])
def search_bus_odsay():
    """ODsay API로 버스노선 검색"""
    bus_no = request.args.get('busNo')
    city_code = request.args.get('CID')
    
    if not bus_no:
        return jsonify({"message": "busNo가 필요합니다."}), 400
    
    try:
        print(f"🚌 ODsay API로 버스노선 검색: {bus_no}")
        if city_code:
            print(f"🏙️ 도시코드: {city_code}")
        
        # ODsay searchBusLane API 직접 호출
        url = f"{ODSAY_API_URL}/searchBusLane"
        params = {
            'lang': 0,
            'busNo': bus_no,
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }
        
        if city_code:
            params['CID'] = city_code
        
        response = requests.get(url, params=params, timeout=15)
        print(f"📍 ODsay searchBusLane 응답: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            if data.get('result') and data['result'].get('lane'):
                lanes = data['result']['lane']
                print(f"✅ ODsay 버스노선 검색 성공: {len(lanes)}개")
                
                # ODsay API 응답을 그대로 반환
                return jsonify(data), 200
            elif data.get('error'):
                print(f"❌ ODsay API 오류: {data['error']}")
                return jsonify({"error": "ODsay API 오류", "details": data['error']}), 400
            else:
                print("⚠️ ODsay 버스노선 검색 결과 없음")
                return jsonify({"error": "버스노선 검색 결과 없음"}), 404
        else:
            print(f"❌ ODsay API 실패: {response.status_code}")
            error_text = response.text if response.text else "Unknown error"
            return jsonify({"error": "ODsay API 호출 실패", "details": error_text}), response.status_code
            
    except requests.exceptions.Timeout:
        print("❌ ODsay API 타임아웃")
        return jsonify({"error": "API 타임아웃"}), 408
    except Exception as e:
        print(f"❌ ODsay API 오류: {e}")
        return jsonify({"error": f"서버 오류: {str(e)}"}), 500

@app.route('/api/v1/odsay/search/route', methods=['GET'])
def search_odsay_route():
    """ODsay 대중교통 경로검색 프록시 (경로 좌표 포함)"""
    start_lat = request.args.get('SY', type=float)
    start_lon = request.args.get('SX', type=float)
    end_lat = request.args.get('EY', type=float)
    end_lon = request.args.get('EX', type=float)
    opt = request.args.get('OPT', default=1, type=int)
    include_path = request.args.get('includePath', default='true', type=str).lower() == 'true'

    if not all([start_lat, start_lon, end_lat, end_lon]):
        return jsonify({"message": "출발지/목적지 좌표가 필요합니다."}), 400

    try:
        print(f"🚌 ODsay 대중교통 경로검색: ({start_lat}, {start_lon}) → ({end_lat}, {end_lon})")

        # searchPubTransPathT 사용 (최신 버전 v1.8)
        url = f"{ODSAY_API_URL}/searchPubTransPathT?SX={start_lon}&SY={start_lat}&EX={end_lon}&EY={end_lat}&apiKey={ODSAY_API_KEY}&lang=0&OPT={opt}&output=json"
        print(f"🌐 ODsay API URL (v1.8): {url}")

        response = requests.get(url, timeout=15)
        print(f"📍 ODsay API 응답: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"🔍 ODsay 응답 데이터: {str(data)[:500]}...")

            if data.get('result'):
                print("✅ ODsay 경로검색 성공")

                # includePath=true인 경우 각 경로에 좌표 배열 추가
                if include_path and data['result'].get('path'):
                    for path in data['result']['path']:
                        path['routeCoordinates'] = extract_route_coordinates_from_path(path)
                        print(f"📍 경로 좌표 추출: {len(path['routeCoordinates'])}개 좌표점")

                return jsonify(data), 200
            elif data.get('error'):
                print(f"❌ ODsay API 오류: {data['error']}")
                return jsonify({"error": "ODsay API 오류", "details": data['error']}), 400
            else:
                print("❌ ODsay 경로 없음")
                return jsonify({"error": "경로를 찾을 수 없음"}), 404
        else:
            print(f"❌ ODsay API 실패: {response.status_code}")
            return jsonify({"error": "ODsay API 호출 실패", "status_code": response.status_code}), response.status_code

    except requests.exceptions.Timeout:
        print("❌ ODsay API 타임아웃")
        return jsonify({"error": "API 타임아웃"}), 408
    except Exception as e:
        print(f"❌ ODsay API 오류: {e}")
        return jsonify({"error": f"서버 오류: {str(e)}"}), 500

def extract_route_coordinates_from_path(path):
    """ODsay 경로 응답에서 실제 도로 경로 좌표 추출 (버스는 loadLane API 사용)"""
    coordinates = []

    try:
        sub_paths = path.get('subPath', [])

        for sub_path in sub_paths:
            traffic_type = sub_path.get('trafficType')

            # 2: 버스 - loadLane API로 실제 도로 경로 가져오기 (방향별 ID 사용)
            if traffic_type == 2:
                lane_info = sub_path.get('lane', [{}])[0] if sub_path.get('lane') else {}
                bus_id = lane_info.get('busID')
                local_bus_id = lane_info.get('busLocalBlID')  # 상행/하행 구분 ID (예: "상행ID/하행ID")

                if bus_id:
                    # passStopList에서 승차/하차 정류장 정보 확인
                    pass_stop_list = sub_path.get('passStopList')
                    start_station_id = sub_path.get('startID')
                    end_station_id = sub_path.get('endID')

                    print(f"🚌 버스 구간 발견 - busID: {bus_id}, localBusID: {local_bus_id}, stationID: {start_station_id} → {end_station_id}")

                    # busLaneDetail API로 전체 정류장 목록 조회하여 index 찾기
                    start_idx, end_idx = get_bus_station_indices(bus_id, start_station_id, end_station_id)

                    if start_idx != -1 and end_idx != -1:
                        print(f"📍 버스 정류장 인덱스: {start_idx} → {end_idx}")

                        # 방향 판단 및 적절한 ID 선택
                        direction_bus_id = bus_id

                        # localBusID가 "상행ID/하행ID" 형태인지 확인
                        if local_bus_id and '/' in str(local_bus_id):
                            ids = str(local_bus_id).split('/')
                            if len(ids) == 2:
                                upward_id = ids[0].strip()
                                downward_id = ids[1].strip()

                                # 방향 판단: start_idx < end_idx이면 정방향, 아니면 역방향
                                if start_idx < end_idx:
                                    print(f"➡️ 정방향 (상행) 사용: {upward_id}")
                                    direction_bus_id = upward_id
                                else:
                                    print(f"⬅️ 역방향 (하행) 사용: {downward_id}")
                                    direction_bus_id = downward_id
                                    # 역방향인 경우 index 교환
                                    start_idx, end_idx = end_idx, start_idx
                                    print(f"🔄 인덱스 교환: {start_idx} → {end_idx}")

                        # loadLane API로 구간 경로 조회
                        bus_coords = get_bus_route_segment_with_cache(direction_bus_id, start_idx, end_idx)

                        if bus_coords:
                            coordinates.extend(bus_coords)
                            print(f"✅ 버스 구간 경로 추가: {len(bus_coords)}개 좌표")
                        else:
                            print(f"⚠️ loadLane 결과 없음, 정류장 좌표 사용")
                            # Fallback: 정류장 좌표 사용
                            if pass_stop_list:
                                stations = pass_stop_list.get('stations', [])
                                for station in stations:
                                    x = station.get('x')
                                    y = station.get('y')
                                    if x and y:
                                        try:
                                            coordinates.append({
                                                "lat": float(y),
                                                "lng": float(x),
                                                "type": "bus",
                                                "stationName": station.get('stationName', '')
                                            })
                                        except (ValueError, TypeError):
                                            continue
                    else:
                        # 인덱스를 찾지 못한 경우 정류장 좌표 사용
                        print(f"⚠️ 정류장 인덱스 찾기 실패, 정류장 좌표 사용")
                        if pass_stop_list:
                            stations = pass_stop_list.get('stations', [])
                            for station in stations:
                                x = station.get('x')
                                y = station.get('y')
                                if x and y:
                                    try:
                                        coordinates.append({
                                            "lat": float(y),
                                            "lng": float(x),
                                            "type": "bus",
                                            "stationName": station.get('stationName', '')
                                        })
                                    except (ValueError, TypeError):
                                        continue
                else:
                    # busID 없으면 정류장 좌표 사용
                    print(f"⚠️ 버스 구간이지만 busID 없음, 정류장 좌표 사용")
                    pass_stop_list = sub_path.get('passStopList')
                    if pass_stop_list:
                        stations = pass_stop_list.get('stations', [])
                        for station in stations:
                            x = station.get('x')
                            y = station.get('y')
                            if x and y:
                                try:
                                    coordinates.append({
                                        "lat": float(y),
                                        "lng": float(x),
                                        "type": "bus",
                                        "stationName": station.get('stationName', '')
                                    })
                                except (ValueError, TypeError):
                                    continue

            # 1: 지하철, 3: 도보 - 기존 방식대로
            elif traffic_type in [1, 3]:
                # 시작 좌표 추가
                start_x = sub_path.get('startX')
                start_y = sub_path.get('startY')
                if start_x and start_y:
                    try:
                        coordinates.append({
                            "lat": float(start_y),
                            "lng": float(start_x),
                            "type": get_traffic_type_name(traffic_type)
                        })
                    except (ValueError, TypeError):
                        pass

                # passStopList의 정류장 좌표 추가 (지하철인 경우)
                if traffic_type == 1:
                    pass_stop_list = sub_path.get('passStopList')
                    if pass_stop_list:
                        stations = pass_stop_list.get('stations', [])
                        for station in stations:
                            x = station.get('x')
                            y = station.get('y')
                            if x and y:
                                try:
                                    coordinates.append({
                                        "lat": float(y),
                                        "lng": float(x),
                                        "type": get_traffic_type_name(traffic_type),
                                        "stationName": station.get('stationName', '')
                                    })
                                except (ValueError, TypeError):
                                    continue

                # 종료 좌표 추가
                end_x = sub_path.get('endX')
                end_y = sub_path.get('endY')
                if end_x and end_y:
                    try:
                        coordinates.append({
                            "lat": float(end_y),
                            "lng": float(end_x),
                            "type": get_traffic_type_name(traffic_type)
                        })
                    except (ValueError, TypeError):
                        pass

        # 중복 좌표 제거 (연속된 같은 좌표)
        unique_coordinates = []
        prev_coord = None
        for coord in coordinates:
            if prev_coord is None or (
                abs(coord['lat'] - prev_coord['lat']) > 0.00001 or
                abs(coord['lng'] - prev_coord['lng']) > 0.00001
            ):
                unique_coordinates.append(coord)
                prev_coord = coord

        return unique_coordinates

    except Exception as e:
        print(f"⚠️ 경로 좌표 추출 오류: {e}")
        return []

def get_traffic_type_name(traffic_type):
    """교통수단 타입을 이름으로 변환"""
    type_names = {
        1: "subway",
        2: "bus",
        3: "walk"
    }
    return type_names.get(traffic_type, "unknown")

@app.route('/api/v1/odsay/bus/station/info', methods=['GET'])
def get_odsay_station_info():
    """ODsay API로 정류장 정보 조회"""
    station_id = request.args.get('stationID')
    
    if not station_id:
        return jsonify({"message": "stationID가 필요합니다."}), 400
    
    try:
        print(f"🚏 ODsay API로 정류장 정보 조회: {station_id}")
        
        # ODsay busStationInfo API 직접 호출
        url = f"{ODSAY_API_URL}/busStationInfo"
        params = {
            'lang': 0,
            'stationID': station_id,
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }
        
        response = requests.get(url, params=params, timeout=15)
        print(f"📍 ODsay busStationInfo 응답: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            if data.get('result'):
                result_data = data['result']
                station_name = result_data.get('stationName', '')
                routes = result_data.get('lane', [])
                print(f"✅ ODsay 정류장 조회 성공: {station_name}, 경유 노선 {len(routes)}개")
                
                # ODsay API 응답을 그대로 반환
                return jsonify(data), 200
            elif data.get('error'):
                print(f"❌ ODsay API 오류: {data['error']}")
                return jsonify({"error": "ODsay API 오류", "details": data['error']}), 400
            else:
                print("❌ ODsay 정류장 정보 없음")
                return jsonify({"error": "정류장 정보 없음"}), 404
        else:
            print(f"❌ ODsay API 실패: {response.status_code}")
            error_text = response.text if response.text else "Unknown error"
            return jsonify({"error": "ODsay API 호출 실패", "details": error_text}), response.status_code
            
    except requests.exceptions.Timeout:
        print("❌ ODsay API 타임아웃")
        return jsonify({"error": "API 타임아웃"}), 408
    except Exception as e:
        print(f"❌ ODsay API 오류: {e}")
        return jsonify({"error": f"서버 오류: {str(e)}"}), 500

# 기존 direct 엔드포인트들은 제거됨 (중복)

@app.route('/api/v1/odsay/bus/route/path', methods=['GET'])
def get_odsay_bus_route_path():
    """ODsay API로 버스 노선의 실제 도로 경로 조회 (searchPubTransPath 사용)"""
    bus_id = request.args.get('busID')

    if not bus_id:
        return jsonify({"message": "busID가 필요합니다."}), 400

    try:
        print(f"🚌 ODsay API로 버스 노선 경로 조회: {bus_id}")

        # 1. busLaneDetail API로 정류장 목록 조회
        detail_url = f"{ODSAY_API_URL}/busLaneDetail"
        params = {
            'lang': 0,
            'busID': bus_id,
            'apiKey': ODSAY_API_KEY,
            'output': 'json'
        }

        response = requests.get(detail_url, params=params, timeout=15)
        print(f"📍 ODsay busLaneDetail 응답: {response.status_code}")

        if response.status_code != 200:
            error_text = response.text if response.text else "Unknown error"
            print(f"❌ ODsay API 실패: {error_text}")
            return jsonify({"error": "ODsay API 호출 실패", "details": error_text}), response.status_code

        data = response.json()

        if not data.get('result'):
            if data.get('error'):
                print(f"❌ ODsay API 오류: {data['error']}")
                return jsonify({"error": "ODsay API 오류", "details": data['error']}), 400
            else:
                print("❌ ODsay 버스 상세정보 없음")
                return jsonify({"error": "버스 상세정보 없음"}), 404

        result = data['result']
        stations = result.get('station', [])

        if not stations or len(stations) < 2:
            print("⚠️ 정류장이 부족하여 경로를 생성할 수 없음")
            # 정류장이 부족하면 원본 데이터만 반환
            return jsonify(data), 200

        print(f"✅ ODsay 정류장 {len(stations)}개 조회됨")

        # 2. 첫 정류장과 마지막 정류장 좌표 추출
        first_station = stations[0]
        last_station = stations[-1]

        start_x = first_station.get('x')
        start_y = first_station.get('y')
        end_x = last_station.get('x')
        end_y = last_station.get('y')

        if not all([start_x, start_y, end_x, end_y]):
            print("⚠️ 시작/종료 좌표가 없어 경로를 생성할 수 없음")
            return jsonify(data), 200

        # 3. searchPubTransPath로 실제 도로 경로 조회
        print(f"🛣️ 실제 도로 경로 조회: ({start_y}, {start_x}) → ({end_y}, {end_x})")

        route_url = f"{ODSAY_API_URL}/searchPubTransPath"
        route_params = {
            'SX': start_x,
            'SY': start_y,
            'EX': end_x,
            'EY': end_y,
            'apiKey': ODSAY_API_KEY,
            'lang': 0,
            'OPT': 1,  # 최적 경로
            'output': 'json'
        }

        route_response = requests.get(route_url, params=route_params, timeout=15)
        print(f"📍 searchPubTransPath 응답: {route_response.status_code}")

        route_coordinates = []

        if route_response.status_code == 200:
            route_data = route_response.json()

            if route_data.get('result') and route_data['result'].get('path'):
                # 첫 번째 경로의 좌표 추출
                first_path = route_data['result']['path'][0]
                route_coordinates = extract_route_coordinates_from_path(first_path)
                print(f"✅ ODsay 실제 도로 경로 조회 성공: {len(route_coordinates)}개 좌표")
            else:
                print("⚠️ searchPubTransPath에서 경로를 찾지 못함")
        else:
            print(f"⚠️ searchPubTransPath 실패: {route_response.status_code}")

        # 4. 경로 좌표가 없으면 정류장 좌표 사용
        if not route_coordinates:
            print("📍 정류장 좌표 사용 (대체)")
            route_coordinates = []
            for station in stations:
                x = station.get('x')
                y = station.get('y')
                if x and y:
                    route_coordinates.append({
                        "lat": float(y),
                        "lng": float(x),
                        "type": "bus",
                        "stationName": station.get('stationName', '')
                    })

        # 5. 응답에 경로 좌표 추가
        data['result']['routeCoordinates'] = route_coordinates
        data['result']['totalRoutePoints'] = len(route_coordinates)

        print(f"✅ 버스 노선 실제 도로 경로 생성 완료: {len(route_coordinates)}개 좌표")
        return jsonify(data), 200

    except requests.exceptions.Timeout:
        print("❌ ODsay API 타임아웃")
        return jsonify({"error": "API 타임아웃"}), 408
    except Exception as e:
        print(f"❌ 버스 경로 조회 오류: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"서버 오류: {str(e)}"}), 500


# ----------------------------------------------------
#  API 엔드포인트: /api/v1/bus/route/<route_id>/path
#  ⭐ DB에 저장된 버스 노선의 실제 운행 경로 GPS 좌표 반환 (NEW)
# ----------------------------------------------------
@app.route('/api/v1/bus/route/<route_id>/path', methods=['GET'])
def get_bus_route_path(route_id):
    """DB에 저장된 버스 노선의 실제 운행 경로 반환 (Fallback: 정류장 좌표)"""
    try:
        city = request.args.get('city', default='경산', type=str)

        print(f"🛣️ 버스 실제 경로 조회 - 노선ID: {route_id}, 도시: {city}")

        conn = None
        cursor = None

        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            # 1. 도시 코드 가져오기
            city_code = get_city_code(cursor, city)
            if not city_code:
                print(f"⚠️ 도시를 찾을 수 없음: {city}")
                return jsonify({'error': 'City not found'}), 404

            print(f"✅ 도시코드: {city_code}")

            # 2. tago_route_path 테이블 존재 여부 확인
            if not check_table_exists(cursor, 'tago_route_path'):
                print(f"⚠️ tago_route_path 테이블이 없음 - 정류장 좌표 사용")
                return get_route_stops_as_fallback_path(cursor, route_id, city_code)

            # 3. DB에서 실제 경로 좌표 조회
            sql = """
                SELECT
                    gpslati as lat,
                    gpslong as lon,
                    sequence
                FROM tago_route_path
                WHERE routeid = %s AND citycode = %s
                ORDER BY sequence ASC
            """

            cursor.execute(sql, (route_id, city_code))
            results = cursor.fetchall()

            # 4. 경로 데이터가 없으면 정류장 좌표 사용 (Fallback)
            if not results:
                print(f"⚠️ DB에 경로 데이터 없음 - 정류장 좌표 사용")
                return get_route_stops_as_fallback_path(cursor, route_id, city_code)

            # 5. 좌표 변환
            coordinates = []
            for row in results:
                coordinates.append({
                    'lat': float(row['lat']),
                    'lon': float(row['lon'])
                })

            print(f"✅ 실제 경로 반환: {len(coordinates)}개 GPS 좌표")

            return jsonify({
                'route_id': route_id,
                'coordinates': coordinates
            }), 200

        except pymysql.MySQLError as err:
            print(f"❌ DB 오류: {err}")
            return jsonify({'error': 'Database error', 'details': str(err)}), 500
        finally:
            if cursor:
                cursor.close()
            if conn:
                conn.close()

    except Exception as e:
        print(f"❌ 버스 경로 조회 오류: {e}")
        return jsonify({'error': 'Server error', 'details': str(e)}), 500


def get_route_stops_as_fallback_path(cursor, route_id, city_code):
    """정류장 좌표를 경로로 반환 (Fallback)"""
    try:
        sql = """
            SELECT
                CAST(gpslati AS DECIMAL(10,8)) as lat,
                CAST(gpslong AS DECIMAL(11,8)) as lon,
                CAST(nodeord AS UNSIGNED) as sequence
            FROM tago_route_list
            WHERE routeid = %s AND citycode = %s
                AND gpslati IS NOT NULL AND gpslong IS NOT NULL
            ORDER BY CAST(nodeord AS UNSIGNED)
        """

        cursor.execute(sql, (route_id, city_code))
        results = cursor.fetchall()

        if not results:
            print(f"❌ 정류장 좌표도 없음")
            return jsonify({'error': 'No route data available'}), 404

        # 좌표 변환
        coordinates = []
        for row in results:
            coordinates.append({
                'lat': float(row['lat']),
                'lon': float(row['lon'])
            })

        print(f"⚠️ 정류장 좌표 반환: {len(coordinates)}개 (실제 경로 아님)")

        return jsonify({
            'route_id': route_id,
            'coordinates': coordinates,
            'fallback': True  # 정류장 좌표 사용 표시
        }), 200

    except pymysql.MySQLError as err:
        print(f"❌ 정류장 좌표 조회 오류: {err}")
        return jsonify({'error': 'Database error', 'details': str(err)}), 500


if __name__ == '__main__':
    print("🚀 Flask 서버 시작...")
    print(f"📊 데이터베이스: {DB_CONFIG['database']}@{DB_CONFIG['host']}")
    print(f"🔤 Charset: {DB_CONFIG['charset']}, Collation: {DB_CONFIG['collation']}")
    print(f"🌐 서버 주소: http://0.0.0.0:2441")
    print("\n✅ 사용 가능한 엔드포인트:")
    print("   - GET  /api/v1/test")
    print("   - GET  /api/v1/place/top?location=대구")
    print("   - GET  /api/v1/place/nearby?lat=LAT&lon=LON")
    print("   - GET  /api/v1/event/nearby?lat=LAT&lon=LON")
    print("   - GET  /api/v1/bus/nearby?lat=LAT&lon=LON&radius=1")
    print("   - GET  /api/v1/bus/stop/<stop_code>/routes?city=경산")
    print("   - GET  /api/v1/bus/route/<route_id>/stops?city=경산")
    print("   - GET  /api/v1/bus/route/<route_id>/places?city=경산  ⭐ UPDATED (type=6 맛집)")
    print("   - GET  /api/v1/bus/route/<route_id>/path?city=경산  ⭐ NEW (실제 도로 경로)")
    print("\n🎯 ODsay API 프록시 엔드포인트:")
    print("   - GET  /api/v1/odsay/bus/route/detail?busID=DGB4070001100")
    print("   - GET  /api/v1/odsay/bus/route/path?busID=DGB4070001100")
    print("   - GET  /api/v1/odsay/search/bus?busNo=100&CID=경산")
    print("   - GET  /api/v1/odsay/search/route?SX=128.7&SY=35.8&EX=128.8&EY=35.9")
    print("   - GET  /api/v1/odsay/bus/station/info?stationID=123456")
    print("\n")
    
    app.run(host='0.0.0.0', debug=True, port=2441)