import { useEffect, useState } from 'react';
import { Card, Table, Badge, Avatar, Spinner } from 'flowbite-react';

export default function Ranking(){
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => { 
    fetch('/rankings/top?limit=20', {credentials:'include'})
      .then(r => {
        if (!r.ok) throw new Error('랭킹 데이터를 불러올 수 없습니다.');
        return r.json();
      })
      .then(data => {
        setRows(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setRows([]);
        setLoading(false);
      });
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
            <button 
              onClick={() => window.location.reload()} 
              className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg"
            >
              다시 시도
            </button>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">🏆 리더보드</h1>
        <p className="text-gray-600">최고 점수를 기록한 플레이어들을 확인해보세요!</p>
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
                          />
                          <div>
                            <div className="font-semibold text-gray-900">{row.userId}</div>
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
    </div>
  );
}
