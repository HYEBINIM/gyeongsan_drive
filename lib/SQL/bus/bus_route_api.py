"""
bus_route_api.py
버스노선정보조회 API 클래스
"""

import requests
import json
import xml.etree.ElementTree as ET
from typing import Optional, Dict, Any


class BusRouteAPI:
    """버스노선정보조회 API 클래스"""
    
    def __init__(self, service_key: str, base_url: str):
        """
        API 클래스 초기화
        
        Args:
            service_key: 공공데이터포털에서 발급받은 인증키 (URL 인코딩된 상태)
            base_url: API 베이스 URL
        """
        self.base_url = base_url
        self.service_key = service_key
    
    def _make_request(self, endpoint: str, params: Dict[str, Any]) -> requests.Response:
        """
        API 요청 공통 함수
        
        Args:
            endpoint: API 엔드포인트
            params: 요청 파라미터
            
        Returns:
            requests.Response 객체
        """
        # URL 직접 구성하여 서비스 키 이중 인코딩 방지
        url = f"{self.base_url}/{endpoint}?serviceKey={self.service_key}"
        
        # 다른 파라미터들 추가
        for key, value in params.items():
            if value is not None:
                url += f"&{key}={value}"
        
        try:
            print(f"요청 URL: {url[:100]}...")  # 디버깅용
            response = requests.get(url, timeout=10)
            
            # 에러 응답 확인
            if response.status_code != 200:
                print(f"HTTP 상태 코드: {response.status_code}")
                print(f"응답 내용: {response.text[:500]}")
            
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            print(f"API 요청 오류: {e}")
            raise
    
    def _parse_response(self, response: requests.Response, data_type: str = 'xml') -> Dict[str, Any]:
        """
        응답 데이터 파싱
        
        Args:
            response: API 응답
            data_type: 데이터 타입 (xml 또는 json)
            
        Returns:
            파싱된 데이터
        """
        if data_type == 'json':
            return response.json()
        else:
            return self._parse_xml(response.text)
    
    def _parse_xml(self, xml_text: str) -> Dict[str, Any]:
        """
        XML 응답을 딕셔너리로 변환
        
        Args:
            xml_text: XML 문자열
            
        Returns:
            파싱된 딕셔너리
        """
        try:
            root = ET.fromstring(xml_text)
            result = {}
            
            # header 파싱
            header = root.find('header')
            if header is not None:
                result['header'] = {child.tag: child.text for child in header}
            
            # body 파싱
            body = root.find('body')
            if body is not None:
                result['body'] = {}
                
                # items 파싱
                items = body.find('items')
                if items is not None:
                    result['body']['items'] = []
                    for item in items.findall('item'):
                        item_dict = {child.tag: child.text for child in item}
                        result['body']['items'].append(item_dict)
                
                # 페이징 정보 파싱
                for child in body:
                    if child.tag not in ['items']:
                        result['body'][child.tag] = child.text
            
            # 에러 체크 (OpenAPI_ServiceResponse)
            if root.tag == 'OpenAPI_ServiceResponse':
                cmmMsgHeader = root.find('cmmMsgHeader')
                if cmmMsgHeader is not None:
                    result['error'] = {child.tag: child.text for child in cmmMsgHeader}
            
            return result
        except ET.ParseError as e:
            print(f"XML 파싱 오류: {e}")
            print(f"응답 내용: {xml_text[:500]}")
            raise
    
    def get_route_no_list(self, city_code: str, route_no: Optional[str] = None, 
                          num_of_rows: int = 10, page_no: int = 1, 
                          data_type: str = 'xml') -> Dict[str, Any]:
        """
        1. 노선번호목록 조회
        
        Args:
            city_code: 도시코드 (예: 25 - 대전광역시, 22 - 대구광역시)
            route_no: 노선번호 (선택사항)
            num_of_rows: 한 페이지 결과 수 (기본값: 10)
            page_no: 페이지 번호 (기본값: 1)
            data_type: 데이터 타입 (xml 또는 json, 기본값: xml)
            
        Returns:
            노선번호 목록 데이터
        """
        params = {
            'cityCode': city_code,
            'numOfRows': num_of_rows,
            'pageNo': page_no,
            '_type': data_type
        }
        
        if route_no:
            params['routeNo'] = route_no
        
        response = self._make_request('getRouteNoList', params)
        return self._parse_response(response, data_type)
    
    def get_route_through_station_list(self, city_code: str, route_id: str,
                                       num_of_rows: int = 10, page_no: int = 1,
                                       data_type: str = 'xml') -> Dict[str, Any]:
        """
        2. 노선별경유정류소목록 조회
        
        Args:
            city_code: 도시코드
            route_id: 노선ID (예: DJB30300004)
            num_of_rows: 한 페이지 결과 수 (기본값: 10)
            page_no: 페이지 번호 (기본값: 1)
            data_type: 데이터 타입 (xml 또는 json, 기본값: xml)
            
        Returns:
            노선별 경유 정류소 목록 데이터
        """
        params = {
            'cityCode': city_code,
            'routeId': route_id,
            'numOfRows': num_of_rows,
            'pageNo': page_no,
            '_type': data_type
        }
        
        response = self._make_request('getRouteAcctoThrghSttnList', params)
        return self._parse_response(response, data_type)
    
    def get_route_info_item(self, city_code: str, route_id: str,
                           data_type: str = 'xml') -> Dict[str, Any]:
        """
        3. 노선정보항목 조회
        
        Args:
            city_code: 도시코드
            route_id: 노선ID (예: DJB30300004)
            data_type: 데이터 타입 (xml 또는 json, 기본값: xml)
            
        Returns:
            노선 기본정보 데이터
        """
        params = {
            'cityCode': city_code,
            'routeId': route_id,
            '_type': data_type
        }
        
        response = self._make_request('getRouteInfoIem', params)
        return self._parse_response(response, data_type)
    
    def get_city_code_list(self, data_type: str = 'xml') -> Dict[str, Any]:
        """
        4. 도시코드 목록 조회
        
        Args:
            data_type: 데이터 타입 (xml 또는 json, 기본값: xml)
            
        Returns:
            도시코드 목록 데이터
        """
        params = {
            '_type': data_type
        }
        
        response = self._make_request('getCtyCodeList', params)
        return self._parse_response(response, data_type)


def print_result(title: str, data: Dict[str, Any]):
    """결과 출력 함수"""
    print("\n" + "="*80)
    print(f"  {title}")
    print("="*80)
    
    # 에러가 있는 경우
    if 'error' in data:
        print("[오류 발생]")
        for key, value in data['error'].items():
            print(f"  {key}: {value}")
        print("\n가능한 원인:")
        print("  - 서비스 키가 올바르지 않음")
        print("  - 서비스 키 승인 대기 중")
        print("  - 잘못된 요청 파라미터")
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    
    print("="*80 + "\n")