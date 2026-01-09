"""
database.py
MySQL 데이터베이스 관리 모듈
버스노선정보 API 결과를 MySQL에 저장합니다.
"""

import pymysql
import json
from datetime import datetime
from typing import List, Dict, Any
from config import DB_CONFIG


class BusRouteDatabase:
    """버스노선정보 MySQL 데이터베이스 관리 클래스"""
    
    def __init__(self, db_config: Dict[str, Any] = None):
        """
        데이터베이스 초기화
        
        Args:
            db_config: 데이터베이스 연결 설정 (기본값: config.DB_CONFIG)
        """
        self.db_config = db_config or DB_CONFIG
        self.conn = None
        print(f"MySQL 데이터베이스 연결: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
        self.create_tables()
    
    def connect(self):
        """데이터베이스 연결"""
        if self.conn is None or not self.conn.open:
            try:
                self.conn = pymysql.connect(
                    host=self.db_config['host'],
                    user=self.db_config['user'],
                    password=self.db_config['password'],
                    database=self.db_config['database'],
                    charset=self.db_config['charset'],
                    port=self.db_config.get('port', 3306),
                    cursorclass=pymysql.cursors.DictCursor
                )
                print("✓ 데이터베이스 연결 성공")
            except pymysql.Error as e:
                print(f"✗ 데이터베이스 연결 실패: {e}")
                raise
        return self.conn
    
    def close(self):
        """데이터베이스 연결 종료"""
        if self.conn and self.conn.open:
            self.conn.close()
            self.conn = None
            print("✓ 데이터베이스 연결 종료")
    
    def create_tables(self):
        """테이블 생성"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            # 1. 도시코드 테이블
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tago_city_code (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    citycode VARCHAR(10) NOT NULL,
                    cityname VARCHAR(100) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_citycode (citycode)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 2. 노선번호목록 테이블 (citycode 컬럼 추가)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tago_route_id (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    citycode VARCHAR(10),
                    routeid VARCHAR(50) NOT NULL,
                    routeno VARCHAR(50),
                    routetp VARCHAR(50),
                    endnodenm VARCHAR(100),
                    startnodenm VARCHAR(100),
                    endvehicletime VARCHAR(10),
                    startvehicletime VARCHAR(10),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_routeid (routeid),
                    INDEX idx_citycode (citycode)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 3. 노선정보항목 테이블 (citycode 컬럼 추가)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tago_stop_info (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    citycode VARCHAR(10),
                    routeid VARCHAR(50) NOT NULL,
                    routeno VARCHAR(50),
                    routetp VARCHAR(50),
                    endnodenm VARCHAR(100),
                    startnodenm VARCHAR(100),
                    endvehicletime VARCHAR(10),
                    startvehicletime VARCHAR(10),
                    intervaltime VARCHAR(10),
                    intervalsattime VARCHAR(10),
                    intervalsuntime VARCHAR(10),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_routeid (routeid),
                    INDEX idx_citycode (citycode)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 4. 경유정류소목록 테이블 (citycode 컬럼 추가)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tago_route_list (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    citycode VARCHAR(10),
                    routeid VARCHAR(50) NOT NULL,
                    nodeid VARCHAR(50) NOT NULL,
                    nodenm VARCHAR(100),
                    nodeno VARCHAR(20),
                    nodeord VARCHAR(10),
                    gpslati VARCHAR(20),
                    gpslong VARCHAR(20),
                    updowncd VARCHAR(5),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_route_node (routeid, nodeid, nodeord),
                    INDEX idx_citycode (citycode)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            conn.commit()
            print("✓ 테이블 생성 완료")
            
        except pymysql.Error as e:
            print(f"✗ 테이블 생성 실패: {e}")
            conn.rollback()
            raise
        finally:
            cursor.close()
    
    def save_city_codes(self, items: List[Dict[str, Any]]) -> int:
        """
        도시코드 목록 저장
        
        Args:
            items: 도시코드 목록
            
        Returns:
            저장된 레코드 수
        """
        conn = self.connect()
        cursor = conn.cursor()
        saved_count = 0
        
        try:
            for item in items:
                try:
                    cursor.execute("""
                        INSERT INTO tago_city_code (citycode, cityname)
                        VALUES (%s, %s)
                        ON DUPLICATE KEY UPDATE cityname = VALUES(cityname)
                    """, (
                        item.get('citycode'),
                        item.get('cityname')
                    ))
                    saved_count += 1
                except pymysql.Error as e:
                    print(f"도시코드 저장 오류: {e}, 데이터: {item}")
            
            conn.commit()
        except Exception as e:
            print(f"트랜잭션 오류: {e}")
            conn.rollback()
        finally:
            cursor.close()
        
        return saved_count
    
    def save_route_list(self, items: List[Dict[str, Any]], city_code: str = None) -> int:
        """
        노선번호목록 저장
        
        Args:
            items: 노선 목록
            city_code: 도시코드 (선택사항)
            
        Returns:
            저장된 레코드 수
        """
        conn = self.connect()
        cursor = conn.cursor()
        saved_count = 0
        
        try:
            for item in items:
                try:
                    cursor.execute("""
                        INSERT INTO tago_route_id 
                        (citycode, routeid, routeno, routetp, endnodenm, startnodenm, 
                         endvehicletime, startvehicletime)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                            citycode = VALUES(citycode),
                            routeno = VALUES(routeno),
                            routetp = VALUES(routetp),
                            endnodenm = VALUES(endnodenm),
                            startnodenm = VALUES(startnodenm),
                            endvehicletime = VALUES(endvehicletime),
                            startvehicletime = VALUES(startvehicletime)
                    """, (
                        city_code,
                        item.get('routeid'),
                        item.get('routeno'),
                        item.get('routetp'),
                        item.get('endnodenm'),
                        item.get('startnodenm'),
                        item.get('endvehicletime'),
                        item.get('startvehicletime')
                    ))
                    saved_count += 1
                except pymysql.Error as e:
                    print(f"노선 저장 오류: {e}, 데이터: {item}")
            
            conn.commit()
        except Exception as e:
            print(f"트랜잭션 오류: {e}")
            conn.rollback()
        finally:
            cursor.close()
        
        return saved_count
    
    def save_route_info(self, items: List[Dict[str, Any]], city_code: str = None) -> int:
        """
        노선정보항목 저장
        
        Args:
            items: 노선 상세정보 목록
            city_code: 도시코드 (선택사항)
            
        Returns:
            저장된 레코드 수
        """
        conn = self.connect()
        cursor = conn.cursor()
        saved_count = 0
        
        try:
            for item in items:
                try:
                    cursor.execute("""
                        INSERT INTO tago_stop_info 
                        (citycode, routeid, routeno, routetp, endnodenm, startnodenm, 
                         endvehicletime, startvehicletime, intervaltime, 
                         intervalsattime, intervalsuntime)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                            citycode = VALUES(citycode),
                            routeno = VALUES(routeno),
                            routetp = VALUES(routetp),
                            endnodenm = VALUES(endnodenm),
                            startnodenm = VALUES(startnodenm),
                            endvehicletime = VALUES(endvehicletime),
                            startvehicletime = VALUES(startvehicletime),
                            intervaltime = VALUES(intervaltime),
                            intervalsattime = VALUES(intervalsattime),
                            intervalsuntime = VALUES(intervalsuntime),
                            updated_at = CURRENT_TIMESTAMP
                    """, (
                        city_code,
                        item.get('routeid'),
                        item.get('routeno'),
                        item.get('routetp'),
                        item.get('endnodenm'),
                        item.get('startnodenm'),
                        item.get('endvehicletime'),
                        item.get('startvehicletime'),
                        item.get('intervaltime'),
                        item.get('intervalsattime'),
                        item.get('intervalsuntime')
                    ))
                    saved_count += 1
                except pymysql.Error as e:
                    print(f"노선정보 저장 오류: {e}, 데이터: {item}")
            
            conn.commit()
        except Exception as e:
            print(f"트랜잭션 오류: {e}")
            conn.rollback()
        finally:
            cursor.close()
        
        return saved_count
    
    def save_station_list(self, items: List[Dict[str, Any]], city_code: str = None) -> int:
        """
        경유정류소목록 저장
        
        Args:
            items: 정류소 목록
            city_code: 도시코드 (선택사항)
            
        Returns:
            저장된 레코드 수
        """
        conn = self.connect()
        cursor = conn.cursor()
        saved_count = 0
        
        try:
            for item in items:
                try:
                    cursor.execute("""
                        INSERT INTO tago_route_list 
                        (citycode, routeid, nodeid, nodenm, nodeno, nodeord, 
                         gpslati, gpslong, updowncd)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                            citycode = VALUES(citycode),
                            nodenm = VALUES(nodenm),
                            nodeno = VALUES(nodeno),
                            gpslati = VALUES(gpslati),
                            gpslong = VALUES(gpslong),
                            updowncd = VALUES(updowncd)
                    """, (
                        city_code,
                        item.get('routeid'),
                        item.get('nodeid'),
                        item.get('nodenm'),
                        item.get('nodeno'),
                        item.get('nodeord'),
                        item.get('gpslati'),
                        item.get('gpslong'),
                        item.get('updowncd')
                    ))
                    saved_count += 1
                except pymysql.Error as e:
                    print(f"정류소 저장 오류: {e}, 데이터: {item}")
            
            conn.commit()
        except Exception as e:
            print(f"트랜잭션 오류: {e}")
            conn.rollback()
        finally:
            cursor.close()
        
        return saved_count
    
    def get_all_city_codes(self) -> List[Dict[str, Any]]:
        """모든 도시코드 조회"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tago_city_code ORDER BY citycode")
        result = cursor.fetchall()
        cursor.close()
        return result
    
    def get_routes_by_city(self, city_code: str = None) -> List[Dict[str, Any]]:
        """도시별 노선 조회"""
        conn = self.connect()
        cursor = conn.cursor()
        if city_code:
            cursor.execute("""
                SELECT * FROM tago_route_id 
                WHERE citycode = %s 
                ORDER BY routeno
            """, (city_code,))
        else:
            cursor.execute("SELECT * FROM tago_route_id ORDER BY routeno")
        result = cursor.fetchall()
        cursor.close()
        return result
    
    def get_route_info(self, route_id: str) -> Dict[str, Any]:
        """특정 노선 상세정보 조회"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tago_stop_info WHERE routeid = %s", (route_id,))
        result = cursor.fetchone()
        cursor.close()
        return result
    
    def get_stations_by_route(self, route_id: str) -> List[Dict[str, Any]]:
        """노선별 정류소 목록 조회"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM tago_route_list 
            WHERE routeid = %s 
            ORDER BY CAST(nodeord AS UNSIGNED)
        """, (route_id,))
        result = cursor.fetchall()
        cursor.close()
        return result
    
    def get_statistics(self) -> Dict[str, int]:
        """데이터베이스 통계"""
        conn = self.connect()
        cursor = conn.cursor()
        
        stats = {}
        
        cursor.execute("SELECT COUNT(*) as count FROM tago_city_code")
        stats['도시코드'] = cursor.fetchone()['count']
        
        cursor.execute("SELECT COUNT(*) as count FROM tago_route_id")
        stats['노선'] = cursor.fetchone()['count']
        
        cursor.execute("SELECT COUNT(*) as count FROM tago_stop_info")
        stats['노선상세정보'] = cursor.fetchone()['count']
        
        cursor.execute("SELECT COUNT(*) as count FROM tago_route_list")
        stats['정류소'] = cursor.fetchone()['count']
        
        cursor.close()
        return stats
    
    def clear_table(self, table_name: str):
        """특정 테이블 데이터 삭제"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute(f"DELETE FROM {table_name}")
        conn.commit()
        cursor.close()
        print(f"{table_name} 테이블 데이터 삭제 완료")
    
    def export_to_json(self, table_name: str, output_file: str):
        """테이블 데이터를 JSON 파일로 내보내기"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute(f"SELECT * FROM {table_name}")
        
        data = cursor.fetchall()
        
        # datetime 객체를 문자열로 변환
        for row in data:
            for key, value in row.items():
                if isinstance(value, datetime):
                    row[key] = value.strftime('%Y-%m-%d %H:%M:%S')
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        cursor.close()
        print(f"{table_name} 데이터를 {output_file}로 내보냈습니다.")


def print_db_info(db: BusRouteDatabase):
    """데이터베이스 정보 출력"""
    print("\n" + "="*80)
    print("  데이터베이스 통계")
    print("="*80)
    
    try:
        stats = db.get_statistics()
        for key, value in stats.items():
            print(f"  {key}: {value:,}건")
    except Exception as e:
        print(f"  통계 조회 실패: {e}")
    
    print("="*80 + "\n")


if __name__ == "__main__":
    # 테스트
    print("데이터베이스 연결 테스트...")
    try:
        db = BusRouteDatabase()
        print("\n테이블 생성 완료")
        print_db_info(db)
        db.close()
    except Exception as e:
        print(f"\n오류 발생: {e}")
        print("\nMySQL 연결 정보를 확인하세요:")
        print(f"  Host: {DB_CONFIG['host']}")
        print(f"  Port: {DB_CONFIG['port']}")
        print(f"  User: {DB_CONFIG['user']}")
        print(f"  Database: {DB_CONFIG['database']}")