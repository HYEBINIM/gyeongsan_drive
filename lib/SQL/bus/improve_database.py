"""
improve_database.py
데이터베이스 구조 개선 - 정류소 마스터 테이블 추가
"""

import pymysql
from config import DB_CONFIG


def create_station_master_table():
    """정류소 마스터 테이블 생성 및 데이터 통합"""
    
    print("\n" + "="*80)
    print("  정류소 마스터 테이블 생성")
    print("="*80)
    
    try:
        conn = pymysql.connect(
            host=DB_CONFIG['host'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password'],
            database=DB_CONFIG['database'],
            charset=DB_CONFIG['charset'],
            port=DB_CONFIG.get('port', 3306)
        )
        
        cursor = conn.cursor()
        
        # 1. 정류소 마스터 테이블 생성
        print("\n[1단계] 정류소 마스터 테이블 생성 중...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tago_station_master (
                id INT AUTO_INCREMENT PRIMARY KEY COMMENT '자동증가 ID',
                citycode VARCHAR(10) COMMENT '도시코드',
                nodeid VARCHAR(50) NOT NULL COMMENT '정류소ID (대표 ID)',
                nodeno VARCHAR(20) COMMENT '정류소번호 (고유번호)',
                nodenm VARCHAR(100) NOT NULL COMMENT '정류소명',
                gpslati VARCHAR(20) COMMENT 'GPS 위도',
                gpslong VARCHAR(20) COMMENT 'GPS 경도',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
                UNIQUE KEY unique_nodeid (nodeid),
                INDEX idx_citycode (citycode),
                INDEX idx_nodeno (nodeno),
                INDEX idx_nodenm (nodenm)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            COMMENT='정류소 마스터 테이블 (고유 정류소 정보)'
        """)
        print("  ✓ 정류소 마스터 테이블 생성 완료")
        
        # 2. tago_route_list에서 고유 정류소 추출
        print("\n[2단계] 고유 정류소 데이터 추출 및 저장 중...")
        cursor.execute("""
            INSERT INTO tago_station_master (citycode, nodeid, nodeno, nodenm, gpslati, gpslong)
            SELECT DISTINCT
                citycode,
                nodeid,
                nodeno,
                nodenm,
                gpslati,
                gpslong
            FROM tago_route_list
            WHERE nodeid IS NOT NULL
            ON DUPLICATE KEY UPDATE
                nodeno = VALUES(nodeno),
                nodenm = VALUES(nodenm),
                gpslati = VALUES(gpslati),
                gpslong = VALUES(gpslong)
        """)
        
        affected_rows = cursor.rowcount
        conn.commit()
        print(f"  ✓ {affected_rows:,}개의 고유 정류소 저장 완료")
        
        # 3. 통계 확인
        print("\n[3단계] 통계 확인")
        print("-"*80)
        
        cursor.execute("SELECT COUNT(*) as cnt FROM tago_station_master")
        station_count = cursor.fetchone()[0]
        print(f"총 정류소 수: {station_count:,}개")
        
        cursor.execute("""
            SELECT citycode, COUNT(*) as cnt
            FROM tago_station_master
            WHERE citycode IS NOT NULL
            GROUP BY citycode
            ORDER BY citycode
        """)
        
        print("\n도시별 정류소 수:")
        for row in cursor.fetchall():
            print(f"  도시코드 {row[0]}: {row[1]:,}개")
        
        cursor.close()
        conn.close()
        
        print("\n" + "="*80)
        print("  정류소 마스터 테이블 생성 완료!")
        print("="*80)
        
    except Exception as e:
        print(f"\n오류 발생: {e}")
        if 'conn' in locals():
            conn.rollback()
            conn.close()


def create_query_examples():
    """쿼리 예제 파일 생성"""
    
    query_examples = """
-- ============================================================================
-- 버스 정보 조회 쿼리 예제
-- ============================================================================

-- 1. 정류장 클릭 → 해당 정류장에 오는 버스 목록
-- ============================================================================
-- 예제: '유성고후문' 정류장에 정차하는 모든 버스
SELECT DISTINCT 
    r.citycode AS 도시코드,
    r.routeno AS 버스번호,
    r.routeid AS 노선ID,
    r.routetp AS 노선유형,
    r.startnodenm AS 기점,
    r.endnodenm AS 종점,
    s.intervaltime AS 배차간격_평일,
    s.startvehicletime AS 첫차,
    s.endvehicletime AS 막차
FROM tago_route_list rl
JOIN tago_route_id r ON rl.routeid = r.routeid
LEFT JOIN tago_stop_info s ON r.routeid = s.routeid
WHERE rl.nodenm = '유성고후문'
ORDER BY r.routeno;

-- 정류소 번호로 검색
SELECT DISTINCT 
    r.routeno AS 버스번호,
    r.routetp AS 노선유형,
    rl.nodenm AS 정류소명
FROM tago_route_list rl
JOIN tago_route_id r ON rl.routeid = r.routeid
WHERE rl.nodeno = '44490'
ORDER BY r.routeno;

-- 정류소 마스터 테이블 활용
SELECT 
    sm.nodenm AS 정류소명,
    sm.nodeno AS 정류소번호,
    sm.gpslati AS 위도,
    sm.gpslong AS 경도,
    COUNT(DISTINCT rl.routeid) AS 경유노선수
FROM tago_station_master sm
LEFT JOIN tago_route_list rl ON sm.nodeid = rl.nodeid
WHERE sm.nodenm LIKE '%유성고%'
GROUP BY sm.nodeid, sm.nodenm, sm.nodeno, sm.gpslati, sm.gpslong;


-- 2. 버스 번호 클릭 → 해당 버스의 전체 노선
-- ============================================================================
-- 예제: 509번 버스의 전체 경유 정류소
SELECT 
    rl.nodeord AS 순서,
    rl.nodenm AS 정류소명,
    rl.nodeno AS 정류소번호,
    rl.gpslati AS 위도,
    rl.gpslong AS 경도,
    CASE WHEN rl.updowncd = '0' THEN '상행' ELSE '하행' END AS 방향
FROM tago_route_list rl
JOIN tago_route_id r ON rl.routeid = r.routeid
WHERE r.routeno = '509' AND r.citycode = '37100'
ORDER BY CAST(rl.nodeord AS UNSIGNED);

-- 노선 기본 정보 + 전체 정류소
SELECT 
    r.routeno AS 버스번호,
    r.routetp AS 노선유형,
    r.startnodenm AS 기점,
    r.endnodenm AS 종점,
    s.startvehicletime AS 첫차,
    s.endvehicletime AS 막차,
    s.intervaltime AS 배차간격,
    rl.nodeord AS 순서,
    rl.nodenm AS 정류소명
FROM tago_route_id r
LEFT JOIN tago_stop_info s ON r.routeid = s.routeid
LEFT JOIN tago_route_list rl ON r.routeid = rl.routeid
WHERE r.routeid = 'GYB3000509002'
ORDER BY CAST(rl.nodeord AS UNSIGNED);


-- 3. 특정 도시의 모든 정류소 목록
-- ============================================================================
SELECT 
    nodeno AS 정류소번호,
    nodenm AS 정류소명,
    gpslati AS 위도,
    gpslong AS 경도,
    (SELECT COUNT(DISTINCT routeid) 
     FROM tago_route_list 
     WHERE nodeid = sm.nodeid) AS 경유노선수
FROM tago_station_master sm
WHERE citycode = '37100'
ORDER BY nodenm;


-- 4. 두 정류소를 모두 경유하는 버스 찾기
-- ============================================================================
-- 예제: A 정류소와 B 정류소를 모두 지나는 버스
SELECT DISTINCT 
    r.routeno AS 버스번호,
    r.routetp AS 노선유형,
    r.startnodenm AS 기점,
    r.endnodenm AS 종점
FROM tago_route_id r
WHERE EXISTS (
    SELECT 1 FROM tago_route_list rl1 
    WHERE rl1.routeid = r.routeid AND rl1.nodenm = '출발정류소명'
)
AND EXISTS (
    SELECT 1 FROM tago_route_list rl2 
    WHERE rl2.routeid = r.routeid AND rl2.nodenm = '도착정류소명'
)
ORDER BY r.routeno;


-- 5. 근처 정류소 찾기 (GPS 좌표 기반)
-- ============================================================================
-- 예제: 특정 좌표 근처 500m 이내 정류소 (대략적 계산)
SELECT 
    nodenm AS 정류소명,
    nodeno AS 정류소번호,
    gpslati AS 위도,
    gpslong AS 경도,
    SQRT(
        POW((CAST(gpslati AS DECIMAL(10,6)) - 36.293125) * 111, 2) +
        POW((CAST(gpslong AS DECIMAL(10,6)) - 127.30067) * 111 * COS(RADIANS(36.293125)), 2)
    ) AS 거리_km
FROM tago_station_master
WHERE citycode = '37100'
  AND gpslati IS NOT NULL 
  AND gpslong IS NOT NULL
HAVING 거리_km < 0.5
ORDER BY 거리_km
LIMIT 10;


-- 6. 노선별 통계
-- ============================================================================
-- 각 노선의 정류소 수, 상행/하행 구분
SELECT 
    r.citycode AS 도시코드,
    r.routeno AS 버스번호,
    r.routetp AS 노선유형,
    COUNT(*) AS 총정류소수,
    SUM(CASE WHEN rl.updowncd = '0' THEN 1 ELSE 0 END) AS 상행정류소수,
    SUM(CASE WHEN rl.updowncd = '1' THEN 1 ELSE 0 END) AS 하행정류소수
FROM tago_route_id r
LEFT JOIN tago_route_list rl ON r.routeid = rl.routeid
WHERE r.citycode = '37100'
GROUP BY r.citycode, r.routeno, r.routetp, r.routeid
ORDER BY r.routeno;


-- 7. 가장 많은 버스가 정차하는 정류소 TOP 10
-- ============================================================================
SELECT 
    sm.nodenm AS 정류소명,
    sm.nodeno AS 정류소번호,
    COUNT(DISTINCT rl.routeid) AS 정차버스수,
    GROUP_CONCAT(DISTINCT r.routeno ORDER BY r.routeno SEPARATOR ', ') AS 버스목록
FROM tago_station_master sm
JOIN tago_route_list rl ON sm.nodeid = rl.nodeid
JOIN tago_route_id r ON rl.routeid = r.routeid
WHERE sm.citycode = '37100'
GROUP BY sm.nodeid, sm.nodenm, sm.nodeno
ORDER BY 정차버스수 DESC
LIMIT 10;


-- 8. 특정 버스의 다음 정류소 찾기
-- ============================================================================
-- 예제: 509번 버스에서 '방천리공영차고지' 다음 정류소
SELECT 
    rl1.nodenm AS 현재정류소,
    rl2.nodenm AS 다음정류소,
    rl2.nodeno AS 다음정류소번호
FROM tago_route_list rl1
JOIN tago_route_list rl2 ON rl1.routeid = rl2.routeid 
    AND CAST(rl2.nodeord AS UNSIGNED) = CAST(rl1.nodeord AS UNSIGNED) + 1
JOIN tago_route_id r ON rl1.routeid = r.routeid
WHERE r.routeno = '509' 
  AND r.citycode = '37100'
  AND rl1.nodenm = '방천리공영차고지';
"""
    
    with open('query_examples.sql', 'w', encoding='utf-8') as f:
        f.write(query_examples)
    
    print("\n✓ query_examples.sql 파일이 생성되었습니다.")
    print("  이 파일에는 다양한 조회 쿼리 예제가 포함되어 있습니다.")


if __name__ == "__main__":
    print("\n데이터베이스 구조 개선 도구")
    print("1. 정류소 마스터 테이블 생성")
    print("2. 쿼리 예제 파일 생성")
    print("3. 전체 실행")
    
    choice = input("\n선택 (1-3): ").strip()
    
    if choice == '1':
        create_station_master_table()
    elif choice == '2':
        create_query_examples()
    elif choice == '3':
        create_station_master_table()
        create_query_examples()
    else:
        print("올바른 번호를 선택해주세요.")