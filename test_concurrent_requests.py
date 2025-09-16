#!/usr/bin/env python3
"""
🧪 Connection Pool 동시 접속 테스트 스크립트
40명 동시 접속으로 Connection Pool 고갈 시나리오 테스트
"""

import asyncio
import aiohttp
import time
import sys
from datetime import datetime

# 테스트 설정
BASE_URL = "https://game.the-test.work"
RANKING_URL = f"{BASE_URL}/rankings/top"

async def send_request(session, user_id, limit=100):
    """단일 사용자 요청 시뮬레이션"""
    start_time = time.time()
    
    try:
        async with session.get(f"{RANKING_URL}?limit={limit}", timeout=aiohttp.ClientTimeout(total=15)) as response:
            if response.status == 200:
                data = await response.json()
                duration = time.time() - start_time
                return {
                    'user_id': user_id,
                    'status': 'SUCCESS',
                    'duration': round(duration, 2),
                    'results_count': len(data),
                    'http_status': response.status
                }
            else:
                duration = time.time() - start_time
                return {
                    'user_id': user_id,
                    'status': 'HTTP_ERROR',
                    'duration': round(duration, 2),
                    'results_count': 0,
                    'http_status': response.status
                }
    except asyncio.TimeoutError:
        duration = time.time() - start_time
        return {
            'user_id': user_id,
            'status': 'TIMEOUT',
            'duration': round(duration, 2),
            'results_count': 0,
            'http_status': 0
        }
    except Exception as e:
        duration = time.time() - start_time
        return {
            'user_id': user_id,
            'status': 'ERROR',
            'duration': round(duration, 2),
            'results_count': 0,
            'http_status': 0,
            'error': str(e)
        }

async def concurrent_test(num_users, limit=100):
    """동시 접속 테스트 실행"""
    print(f"\n🧪 {num_users}명 동시 접속 테스트 시작 (limit={limit})")
    print(f"📅 시작 시간: {datetime.now().strftime('%H:%M:%S')}")
    print("─" * 60)
    
    test_start = time.time()
    
    # aiohttp 세션 생성
    async with aiohttp.ClientSession() as session:
        # 모든 요청을 동시에 시작
        tasks = [send_request(session, f"User-{i+1}", limit) for i in range(num_users)]
        results = await asyncio.gather(*tasks)
    
    test_duration = time.time() - test_start
    
    # 결과 분석
    success_count = len([r for r in results if r['status'] == 'SUCCESS'])
    timeout_count = len([r for r in results if r['status'] == 'TIMEOUT'])
    error_count = len([r for r in results if r['status'] in ['HTTP_ERROR', 'ERROR']])
    
    success_durations = [r['duration'] for r in results if r['status'] == 'SUCCESS']
    avg_duration = sum(success_durations) / len(success_durations) if success_durations else 0
    
    # 결과 출력
    print("📊 결과 요약:")
    print(f"  총 사용자: {num_users}명")
    print(f"  ✅ 성공: {success_count}명 ({success_count/num_users*100:.1f}%)")
    print(f"  ⏰ 타임아웃: {timeout_count}명 ({timeout_count/num_users*100:.1f}%)")
    print(f"  ❌ 에러: {error_count}명 ({error_count/num_users*100:.1f}%)")
    print(f"  📈 평균 응답시간: {avg_duration:.2f}초")
    print(f"  🕐 전체 테스트 시간: {test_duration:.2f}초")
    
    # 상세 결과 (처음 10명만)
    print("\n📋 상세 결과 (처음 10명):")
    for result in results[:10]:
        status_emoji = "✅" if result['status'] == 'SUCCESS' else "❌"
        print(f"  {status_emoji} {result['user_id']}: {result['status']} ({result['duration']}초)")
    
    if len(results) > 10:
        print(f"  ... 나머지 {len(results)-10}명 생략")
    
    return results

async def main():
    """메인 테스트 실행"""
    print("🔥 Connection Pool 동시 접속 테스트")
    print("=" * 60)
    
    # 테스트 시나리오들
    test_scenarios = []
    
    if len(sys.argv) > 1:
        # 명령행 인자로 사용자 수 지정
        try:
            num_users = int(sys.argv[1])
            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
            test_scenarios.append((num_users, limit))
        except ValueError:
            print("❌ 사용법: python test_concurrent_requests.py <사용자수> [limit]")
            return
    else:
        # 기본 시나리오들
        print("🎯 어떤 테스트를 실행하시겠습니까?")
        print("1. 💚 5명 동시 접속 (안전 테스트)")
        print("2. 🔥 40명 동시 접속 (Connection Pool 고갈 테스트)")
        print("3. 🚀 사용자 정의")
        print("4. 📊 모든 시나리오 순차 실행")
        
        choice = input("\n선택 (1-4): ").strip()
        
        if choice == "1":
            test_scenarios.append((5, 100))
        elif choice == "2":
            test_scenarios.append((40, 100))
        elif choice == "3":
            num_users = int(input("사용자 수: "))
            limit = int(input("랭킹 개수 (기본 100): ") or 100)
            test_scenarios.append((num_users, limit))
        elif choice == "4":
            test_scenarios = [(5, 100), (10, 100), (20, 100), (40, 100)]
        else:
            print("❌ 잘못된 선택입니다.")
            return
    
    # 테스트 실행
    for i, (num_users, limit) in enumerate(test_scenarios):
        if i > 0:
            print("\n" + "="*60)
            print("😴 다음 테스트까지 5초 대기...")
            await asyncio.sleep(5)
        
        await concurrent_test(num_users, limit)
    
    print("\n🎉 모든 테스트 완료!")

if __name__ == "__main__":
    # 필요한 패키지 설치 확인
    try:
        import aiohttp
    except ImportError:
        print("❌ aiohttp 패키지가 필요합니다.")
        print("설치: pip install aiohttp")
        sys.exit(1)
    
    # 테스트 실행
    asyncio.run(main())
