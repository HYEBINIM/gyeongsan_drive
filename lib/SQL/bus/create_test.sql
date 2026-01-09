-- 버스노선정보 데이터베이스 테이블 생성 스크립트
-- MySQL 5.7 이상 지원

-- 데이터베이스 생성 (필요시)
CREATE DATABASE IF NOT EXISTS dataset CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE dataset;

-- 1. 도시코드 테이블
DROP TABLE IF EXISTS tago_city_code;
CREATE TABLE tago_city_code (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '자동증가 ID',
    citycode VARCHAR(10) NOT NULL COMMENT '도시코드',
    cityname VARCHAR(100) NOT NULL COMMENT '도시명',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
    UNIQUE KEY unique_citycode (citycode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='도시코드 목록';

-- 2. 노선번호목록 테이블
DROP TABLE IF EXISTS tago_route_id;
CREATE TABLE tago_route_id (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '자동증가 ID',
    routeid VARCHAR(50) NOT NULL COMMENT '노선ID',
    routeno VARCHAR(50) COMMENT '노선번호',
    routetp VARCHAR(50) COMMENT '노선유형',
    endnodenm VARCHAR(100) COMMENT '종점',
    startnodenm VARCHAR(100) COMMENT '기점',
    endvehicletime VARCHAR(10) COMMENT '막차시간 (HHMM)',
    startvehicletime VARCHAR(10) COMMENT '첫차시간 (HHMM)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
    UNIQUE KEY unique_routeid (routeid),
    INDEX idx_routeno (routeno),
    INDEX idx_citycode (routeid(3))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='노선번호 목록';

-- 3. 노선정보항목 테이블
DROP TABLE IF EXISTS tago_stop_info;
CREATE TABLE tago_stop_info (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '자동증가 ID',
    routeid VARCHAR(50) NOT NULL COMMENT '노선ID',
    routeno VARCHAR(50) COMMENT '노선번호',
    routetp VARCHAR(50) COMMENT '노선유형',
    endnodenm VARCHAR(100) COMMENT '종점',
    startnodenm VARCHAR(100) COMMENT '기점',
    endvehicletime VARCHAR(10) COMMENT '막차시간 (HHMM)',
    startvehicletime VARCHAR(10) COMMENT '첫차시간 (HHMM)',
    intervaltime VARCHAR(10) COMMENT '배차간격-평일 (분)',
    intervalsattime VARCHAR(10) COMMENT '배차간격-토요일 (분)',
    intervalsuntime VARCHAR(10) COMMENT '배차간격-일요일 (분)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
    UNIQUE KEY unique_routeid (routeid),
    INDEX idx_routeno (routeno)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='노선 상세정보 (배차간격 포함)';

-- 4. 경유정류소목록 테이블
DROP TABLE IF EXISTS tago_route_list;
CREATE TABLE tago_route_list (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '자동증가 ID',
    routeid VARCHAR(50) NOT NULL COMMENT '노선ID',
    nodeid VARCHAR(50) NOT NULL COMMENT '정류소ID',
    nodenm VARCHAR(100) COMMENT '정류소명',
    nodeno VARCHAR(20) COMMENT '정류소번호',
    nodeord VARCHAR(10) COMMENT '정류소순번',
    gpslati VARCHAR(20) COMMENT 'WGS84 위도',
    gpslong VARCHAR(20) COMMENT 'WGS84 경도',
    updowncd VARCHAR(5) COMMENT '상하행구분 (0:상행, 1:하행)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '생성일시',
    UNIQUE KEY unique_route_node (routeid, nodeid, nodeord),
    INDEX idx_routeid (routeid),
    INDEX idx_nodeid (nodeid),
    INDEX idx_nodeord (nodeord)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='노선별 경유 정류소 목록';

-- 통계 조회용 뷰 생성
CREATE OR REPLACE VIEW v_bus_statistics AS
SELECT 
    (SELECT COUNT(*) FROM tago_city_code) as total_cities,
    (SELECT COUNT(*) FROM tago_route_id) as total_routes,
    (SELECT COUNT(*) FROM tago_stop_info) as total_route_details,
    (SELECT COUNT(*) FROM tago_route_list) as total_stations;

-- 샘플 데이터 조회 쿼리
-- 1. 모든 도시 목록
-- SELECT * FROM tago_city_code ORDER BY citycode;

-- 2. 특정 도시의 노선 목록 (예: 대전 = 25)
-- SELECT * FROM tago_route_id WHERE routeid LIKE '25%' ORDER BY routeno;

-- 3. 특정 노선의 상세정보b
-- SELECT * FROM tago_stop_info WHERE routeid = 'DJB30300004';

-- 4. 특정 노선의 정류소 목록
-- SELECT * FROM tago_route_list WHERE routeid = 'DJB30300004' ORDER BY CAST(nodeord AS UNSIGNED);

-- 5. 통계 조회
-- SELECT * FROM v_bus_statistics;

SHOW TABLES;