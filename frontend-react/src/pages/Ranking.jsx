import { useEffect, useState } from 'react';
import { Card, Table, Badge, Avatar, Spinner, Button, Toast } from 'flowbite-react';
import { rumAction } from '../lib/rum';

export default function Ranking(){
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  
  // 🍞 토스트 메시지 상태
  const [toast, setToast] = useState({ show: false, type: '', message: '' });
  
  // 👤 현재 사용자 정보 (특별 기능 접근 권한 확인용)
  const [currentUser, setCurrentUser] = useState('');

  // 🍞 토스트 메시지 표시 함수
  const showToast = (type, message) => {
    setToast({ show: true, type, message });
    // 3초 후 자동으로 토스트 숨김
    setTimeout(() => {
      setToast({ show: false, type: '', message: '' });
    }, 3000);
  };

  // 🔄 랭킹 데이터를 가져오는 함수
  const fetchRankings = async (isRefresh = false, limit = 100) => {
    try {
      if (isRefresh) {
        setRefreshing(true);
        // 🎯 RUM 추적: 수동 새로고침 (limit 포함)
        rumAction('ranking_refresh', { 
          limit: limit,
          isHighLoad: limit >= 200,
          user: currentUser 
        });
        
        // 🚨 고부하 테스트시 특별 추적
        if (limit >= 200) {
          rumAction('ranking_high_load_test', { 
            limit: limit,
            user: currentUser,
            testType: 'connection_pool_exhaustion'
          });
        }
      } else {
        setLoading(true);
      }
      setError(null);

      const response = await fetch(`/rankings/top?limit=${limit}`, {credentials:'include'});
      
      if (!response.ok) {
        throw new Error('랭킹 데이터를 불러올 수 없습니다.');
      }
      
      const data = await response.json();
      setRows(data);
      
      if (isRefresh) {
        rumAction('ranking_refresh_success', { count: data.length, limit: limit }); // 🎯 RUM 추적: 새로고침 성공
        showToast('success', `✅ 랭킹이 성공적으로 업데이트되었습니다! (${data.length}/${limit}명)`);
      }
    } catch (err) {
      setError(err.message);
      setRows([]);
      
      if (isRefresh) {
        // 🎯 RUM 추적: 새로고침 실패 (limit 및 고부하 테스트 정보 포함)
        rumAction('ranking_refresh_error', { 
          error: err.message,
          limit: limit,
          isHighLoad: limit >= 200,
          user: currentUser,
          errorType: err.message.toLowerCase().includes('connection') ? 'connection_pool' : 'other'
        });
        
        // 🚨 Connection Pool 고갈 에러 특별 추적
        if (limit >= 200 && err.message.toLowerCase().includes('connection')) {
          rumAction('connection_pool_exhaustion_confirmed', {
            limit: limit,
            user: currentUser,
            errorMessage: err.message,
            testSuccess: true
          });
        }
        
        showToast('error', `❌ 랭킹 업데이트 실패: ${err.message}`);
      }
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  // 🚀 페이지 로드 시 데이터 가져오기
  useEffect(() => { 
    // 👤 현재 사용자 정보 가져오기 (특별 기능 접근 권한 확인용)
    fetch('/api/session/me', { credentials: 'include' })
      .then(r => r.ok ? r.json() : Promise.reject())
      .then(data => {
        setCurrentUser(data.user_id || '');
      })
      .catch(() => {
        setCurrentUser('');
      });

    // 🎯 퍼널 추적: 랭킹 페이지 방문
    rumAction('page_visited', { page: 'ranking' });
    
    // 🎯 퍼널 추적: 게임 완료 후 랭킹 확인 여부 체크
    const gameCompletedData = sessionStorage.getItem('game_completed');
    if (gameCompletedData) {
      try {
        const { score, completedAt, newBest } = JSON.parse(gameCompletedData);
        const timeDiff = Date.now() - completedAt;
        
        // 게임 완료 후 5분 이내에 랭킹 페이지 방문한 경우
        if (timeDiff < 5 * 60 * 1000) {
          rumAction('ranking_checked_after_game', { 
            previousScore: score,
            wasNewBest: newBest,
            timeSinceGameCompleted: timeDiff
          });
          
          // 추적 완료 후 세션 스토리지에서 제거
          sessionStorage.removeItem('game_completed');
        }
      } catch (e) {
        console.warn('게임 완료 데이터 파싱 실패:', e);
        sessionStorage.removeItem('game_completed');
      }
    }
    
    fetchRankings(false, 100);
  }, []);

  const getRankBadge = (rank) => {
    if (rank === 1) return <Badge color="warning" className="text-yellow-800">🥇 1위</Badge>;
    if (rank === 2) return <Badge color="gray" className="text-gray-800">🥈 2위</Badge>;
    if (rank === 3) return <Badge color="warning" className="text-amber-800">🥉 3위</Badge>;
    return <Badge color="purple" className="text-purple-800">{rank}위</Badge>;
  };

  const formatScore = (score) => {
    return new Intl.NumberFormat('ko-KR').format(score);
  };

  const formatDate = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffInSeconds = Math.floor((now - date) / 1000);
    
    if (diffInSeconds < 60) return '방금 전';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}분 전`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}시간 전`;
    if (diffInSeconds < 2592000) return `${Math.floor(diffInSeconds / 86400)}일 전`;
    
    return date.toLocaleDateString('ko-KR');
  };

  // 🎖️ 사용자 레벨 배지 - 간단한 CSS 변수 방식
  const getLevelBadge = (level) => {
    // 레벨별 스타일 정의 - 간단한 객체 방식
    const levelStyles = {
      '마스터': { bg: 'bg-purple-600', icon: '👑' },
      '전문가': { bg: 'bg-blue-600', icon: '🎓' },
      '중급자': { bg: 'bg-green-600', icon: '⭐' },
      '초보자': { bg: 'bg-yellow-600', icon: '🌱' },
      '쌩초보': { bg: 'bg-gray-600', icon: '🥚' }
    };
    
    const style = levelStyles[level] || { bg: 'bg-gray-100', icon: '❓' };
    const textColor = level && levelStyles[level] ? 'text-white' : 'text-gray-800';
    
    return (
      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${style.bg} ${textColor} shadow-sm`}>
        {style.icon} {level}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-center min-h-96">
          <div className="text-center">
            <Spinner size="xl" className="mb-4" />
            <p className="text-gray-600">랭킹 데이터를 불러오는 중...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-6xl mx-auto">
        <Card className="shadow-lg border-0">
          <div className="text-center py-12">
            <div className="text-6xl mb-4">😅</div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">데이터를 불러올 수 없습니다</h3>
            <p className="text-gray-600 mb-4">{error}</p>
            <Button 
              onClick={() => {
                setError(null); // 에러 상태 초기화
                fetchRankings(true, 100);
              }} 
              disabled={refreshing}
              className="bg-purple-600 hover:bg-purple-700"
            >
              {refreshing ? (
                <>
                  <Spinner size="sm" className="mr-2" />
                  새로고침 중...
                </>
              ) : (
                '다시 시도'
              )}
            </Button>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">🏆 리더보드</h1>
          <p className="text-gray-600">최고 점수를 기록한 플레이어들을 확인해보세요!</p>
        </div>
        <div className="flex items-center gap-3">
          <Button
            onClick={() => fetchRankings(true, 100)}
            disabled={refreshing || loading}
            size="sm"
            className="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700"
          >
            {refreshing ? (
              <>
                <Spinner size="sm" className="mr-2" />
                새로고침 중...
              </>
            ) : (
              <>
                🔄 새로고침
              </>
            )}
          </Button>
          
          {/* 🚨 Connection Pool 고갈 테스트용 - Kihyun 전용 버튼 */}
          {currentUser === 'Kihyun' && (
            <Button
              onClick={() => fetchRankings(true, 200)}
              disabled={refreshing || loading}
              size="sm"
              className="bg-gradient-to-r from-red-500 to-orange-500 hover:from-red-600 hover:to-orange-600 text-white border-0"
            >
              {refreshing ? (
                <>
                  <Spinner size="sm" className="mr-2" />
                  로딩 중...
                </>
              ) : (
                <>
                  🔥 200명 랭킹 (고부하)
                </>
              )}
            </Button>
          )}
        </div>
      </div>

      <Card className="shadow-lg border-0">
        {rows.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">🎮</div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">아직 기록이 없습니다</h3>
            <p className="text-gray-600 mb-4">첫 번째 플레이어가 되어보세요!</p>
            <button 
              onClick={() => window.location.href = '/game'} 
              className="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 text-white px-6 py-2 rounded-lg"
            >
              게임 시작하기
            </button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <Table hoverable>
              <Table.Head>
                <Table.HeadCell className="bg-gradient-to-r from-purple-50 to-blue-50 text-purple-900 font-bold">
                  순위
                </Table.HeadCell>
                <Table.HeadCell className="bg-gradient-to-r from-purple-50 to-blue-50 text-purple-900 font-bold">
                  플레이어
                </Table.HeadCell>
                <Table.HeadCell className="bg-gradient-to-r from-purple-50 to-blue-50 text-purple-900 font-bold">
                  점수
                </Table.HeadCell>
                <Table.HeadCell className="bg-gradient-to-r from-purple-50 to-blue-50 text-purple-900 font-bold">
                  달성 시간
                </Table.HeadCell>
              </Table.Head>
              <Table.Body className="divide-y">
                {rows.map((row, index) => {
                  const rank = index + 1;
                  return (
                    <Table.Row 
                      key={row.userId} 
                      className={`bg-white dark:border-gray-700 dark:bg-gray-800 hover:bg-gray-50 ${
                        rank <= 3 ? 'ring-2 ring-purple-100' : ''
                      }`}
                    >
                      <Table.Cell className="whitespace-nowrap font-medium text-gray-900">
                        {getRankBadge(rank)}
                      </Table.Cell>
                      <Table.Cell>
                        <div className="flex items-center gap-3">
                          <Avatar 
                            placeholderInitials={row.userId?.charAt(0)?.toUpperCase() || '?'} 
                            rounded 
                            size="sm"
                            className={`ring-2 ${
                              rank === 1 ? 'ring-yellow-300' : 
                              rank === 2 ? 'ring-gray-300' : 
                              rank === 3 ? 'ring-amber-300' : 
                              'ring-purple-200'
                            }`}
                            data-dd-action-name="랭킹 플레이어 아바타 클릭"
                          />
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-1">
                              {/* 🎖️ 레벨 배지 - 사용자 ID 왼쪽에 표시 */}
                              {getLevelBadge(row.level)}
                              <div className="font-semibold text-gray-900">{row.userId}</div>
                            </div>
                            {rank <= 3 && (
                              <div className="text-xs text-gray-500">
                                {rank === 1 ? '챔피언' : rank === 2 ? '준우승' : '3위'}
                              </div>
                            )}
                          </div>
                        </div>
                      </Table.Cell>
                      <Table.Cell>
                        <span className={`font-bold text-lg ${
                          rank === 1 ? 'text-yellow-600' : 
                          rank === 2 ? 'text-gray-600' : 
                          rank === 3 ? 'text-amber-600' : 
                          'text-purple-600'
                        }`}>
                          {formatScore(row.score)}
                        </span>
                      </Table.Cell>
                      <Table.Cell className="text-gray-500">
                        {formatDate(row.ts)}
                      </Table.Cell>
                    </Table.Row>
                  );
                })}
              </Table.Body>
            </Table>
          </div>
        )}

        {rows.length > 0 && (
          <div className="mt-6 text-center text-sm text-gray-500 border-t pt-4">
            총 {rows.length}명의 플레이어가 기록을 세웠습니다
          </div>
        )}
      </Card>

      {/* 🍞 토스트 메시지 */}
      {toast.show && (
        <div className="fixed bottom-4 right-4 z-50">
          <Toast>
            <div className={`inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ${
              toast.type === 'success' 
                ? 'bg-green-100 text-green-500' 
                : 'bg-red-100 text-red-500'
            }`}>
              {toast.type === 'success' ? (
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
              ) : (
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              )}
            </div>
            <div className="ml-3 text-sm font-normal">{toast.message}</div>
            <Toast.Toggle onClick={() => setToast({ show: false, type: '', message: '' })} />
          </Toast>
        </div>
      )}
    </div>
  );
}
