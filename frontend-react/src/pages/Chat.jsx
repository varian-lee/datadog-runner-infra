import { useEffect, useRef, useState } from 'react';
import { Card, Button, TextInput, Badge, Avatar } from 'flowbite-react';
import { rumAction } from '../lib/rum';

export default function Chat(){
  const [msgs, setMsgs] = useState([]);
  const [text, setText] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [currentUser, setCurrentUser] = useState('익명');
  const [connectedUsers, setConnectedUsers] = useState([]); // 실시간 사용자 목록
  const [userLoading, setUserLoading] = useState(true); // 사용자 정보 로딩 상태
  const wsRef = useRef(null);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [msgs]);

  // Get current user info
  useEffect(() => {
    // 🎯 퍼널 추적: 채팅 페이지 방문
    rumAction('page_visited', { page: 'chat' });
    
    setUserLoading(true);
    fetch('/api/session/me', { credentials: 'include' })
      .then(r => {
        if (!r.ok) {
          // 세션 만료 또는 인증 실패 시 로그인 페이지로 리다이렉트
          if (r.status === 401 || r.status === 403) {
            console.log('세션이 만료되었습니다. 로그인 페이지로 이동합니다.');
            window.location.href = '/login';
            return Promise.reject('Session expired');
          }
          return Promise.reject('Session check failed');
        }
        return r.json();
      })
      .then(data => {
        setCurrentUser(data.user_id || '익명');
        setUserLoading(false);
      })
      .catch((error) => {
        console.error('세션 확인 실패:', error);
        // 일시적인 네트워크 에러의 경우에만 '익명'으로 설정
        if (error !== 'Session expired') {
          setCurrentUser('익명');
          setUserLoading(false);
        }
      });
  }, []);

  useEffect(()=>{
    // 사용자 정보 로딩이 완료된 후에만 WebSocket 연결
    if (userLoading) return;

    const ws = new WebSocket((location.protocol==='https:'?'wss':'ws')+'://'+location.host+'/chat/ws');
    wsRef.current = ws;
    
    ws.onopen = () => {
      setIsConnected(true);
      // 연결 즉시 사용자 입장 메시지 전송
      if (currentUser) {
        // 💬 채팅방 입장 - RUM 추적
        rumAction('chat_room_joined', { user: currentUser });
        
        ws.send(JSON.stringify({ 
          type: 'user_join', 
          user: currentUser 
        }));
      }
    };
    ws.onclose = () => setIsConnected(false);
    ws.onerror = () => setIsConnected(false);
    ws.onmessage = (e)=> {
      const data = JSON.parse(e.data);
      
      // 사용자 목록 업데이트 메시지 처리
      if (data.type === 'user_list_update') {
        setConnectedUsers(data.userList || []);
        // 💬 사용자 목록 업데이트 - RUM 추적
        rumAction('chat_user_list_updated', { connectedUsers: data.userList?.length || 0 });
      } else {
        // 일반 채팅 메시지 (type === 'chat' 또는 기타)
        setMsgs(m => [...m, data]);
        // 💬 메시지 수신 - RUM 추적 (본인 메시지가 아닌 경우에만)
        if (data.user !== currentUser) {
          rumAction('chat_message_received', { 
            fromUser: data.user,
            messageLength: data.text?.length || 0
          });
        }
      }
    };
    
    return ()=> ws.close();
  }, [userLoading, currentUser]); // userLoading과 currentUser 변경 시 재연결

  function send(e, inputMethod = 'unknown'){
    e?.preventDefault();
    if (!text.trim()) return;
    
    // 💬 채팅 전송 - RUM 추적 (입력 방법 포함)
    const messageData = {
      messageLength: text.trim().length,
      messagePreview: text.trim().substring(0, 20) + (text.trim().length > 20 ? '...' : ''), // 처음 20자만
      user: currentUser,
      isConnected: isConnected,
      inputMethod: inputMethod // 입력 방법 추가 (send_button, enter_key 등)
    };
    rumAction('chat_message_sent', messageData);
    
    wsRef.current?.send(JSON.stringify({ text, user: currentUser }));
    setText('');
  }

  function handleKeyPress(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      // 💬 엔터키로 채팅 전송
      send(e, 'enter_key');
    }
  }

  // 사용자 정보 로딩 중일 때 로딩 화면 표시
  if (userLoading) {
    return (
      <div className="max-w-full md:max-w-4xl mx-auto px-2 md:px-0">
        <div className="flex items-center justify-center h-96">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p className="text-gray-600">사용자 정보를 확인 중입니다...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-full md:max-w-4xl mx-auto px-2 md:px-0">
      <div className="mb-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-gray-900 mb-2">💬 실시간 채팅</h1>
            <p className="text-sm md:text-base text-gray-600">다른 플레이어들과 대화해보세요!</p>
          </div>
          <div className="flex items-center gap-2">
            <div className={`h-3 w-3 rounded-full ${isConnected ? 'bg-green-500' : 'bg-red-500'}`}></div>
            <Badge color={isConnected ? 'success' : 'failure'} className="text-sm">
              {isConnected ? '연결됨' : '연결 끊어짐'}
            </Badge>
          </div>
        </div>
      </div>

      <Card className="shadow-lg border-0">
        {/* 모바일: 상단에 사용자 목록 컴팩트하게 표시 */}
        <div className="md:hidden mb-4 p-3 bg-gray-50 rounded-lg">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 bg-green-500 rounded-full"></div>
              <h3 className="font-semibold text-gray-700 text-sm">접속 중 ({connectedUsers.length}명)</h3>
            </div>
          </div>
          
          {connectedUsers.length === 0 ? (
            <p className="text-center text-gray-500 text-xs py-2">접속 중인 사용자가 없습니다</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {connectedUsers.map((user, i) => (
                <div key={i} className="flex items-center gap-2 bg-white px-2 py-1 rounded-full shadow-sm">
                  <div className="w-5 h-5 bg-green-100 rounded-full flex items-center justify-center ring-1 ring-green-200">
                    <span className="text-xs font-semibold text-green-700">
                      {user.userId?.charAt(0)?.toUpperCase() || '?'}
                    </span>
                  </div>
                  <span className={`text-xs font-medium ${user.userId === currentUser ? 'text-blue-600' : 'text-gray-700'}`}>
                    {user.userId} {user.userId === currentUser && '(나)'}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* 데스크톱: 기존 2열 레이아웃, 모바일: 1열 레이아웃 */}
        <div className="flex flex-col md:flex-row gap-4 h-80 md:h-96">
          {/* 채팅 메시지 영역 */}
          <div className="flex-1 overflow-y-auto p-4 bg-gray-50 rounded-lg">
          {msgs.length === 0 ? (
            <div className="flex items-center justify-center h-full text-gray-500">
              <div className="text-center">
                <div className="text-4xl mb-2">🗨️</div>
                <p>아직 메시지가 없습니다.</p>
                <p className="text-sm">첫 번째 메시지를 보내보세요!</p>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              {msgs.map((msg, i) => {
                const isMyMessage = msg.user === currentUser;
                
                return (
                  <div key={i} className={`flex items-start gap-3 ${isMyMessage ? 'flex-row-reverse' : ''}`}>
                    <Avatar 
                      placeholderInitials={msg.user?.charAt(0)?.toUpperCase() || '?'} 
                      rounded 
                      size="sm"
                      className={`ring-2 ${isMyMessage ? 'ring-blue-200' : 'ring-purple-200'}`}
                      data-dd-action-name="채팅 메시지 작성자 아바타 클릭"
                    />
                    <div className="flex-1 min-w-0">
                      <div className={`flex items-center gap-2 mb-1 ${isMyMessage ? 'flex-row-reverse' : ''}`}>
                        <span className={`font-semibold text-sm ${isMyMessage ? 'text-blue-700' : 'text-purple-700'}`}>
                          {msg.user || '익명'} {isMyMessage && '(나)'}
                        </span>
                        <span className="text-xs text-gray-500">
                          {new Date(msg.ts || Date.now()).toLocaleTimeString()}
                        </span>
                      </div>
                      <div className={`p-3 rounded-lg shadow-sm border ${
                        isMyMessage 
                          ? 'bg-blue-100 border-blue-200' 
                          : 'bg-white border-gray-100'
                      }`}>
                        <p className="text-gray-800 text-sm break-words">{msg.text}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
              <div ref={messagesEndRef} />
            </div>
          )}
          </div>
          
          {/* 데스크톱: 오른쪽 사용자 목록 (모바일에서는 숨김) */}
          <div className="hidden md:block w-64 bg-white rounded-lg border border-gray-200 p-4">
            <div className="flex items-center gap-2 mb-4">
              <div className="h-2 w-2 bg-green-500 rounded-full"></div>
              <h3 className="font-semibold text-gray-700">접속 중 ({connectedUsers.length}명)</h3>
            </div>
            
            {connectedUsers.length === 0 ? (
              <div className="text-center text-gray-500 text-sm py-8">
                <div className="text-2xl mb-2">👥</div>
                <p>접속 중인 사용자가 없습니다</p>
              </div>
            ) : (
              <div className="space-y-2">
                {connectedUsers.map((user, i) => (
                  <div key={i} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50">
                    <Avatar 
                      placeholderInitials={user.userId?.charAt(0)?.toUpperCase() || '?'} 
                      rounded 
                      size="xs"
                      className="ring-2 ring-green-200"
                      data-dd-action-name="접속 사용자 아바타 클릭"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className={`text-sm font-medium ${user.userId === currentUser ? 'text-blue-600' : 'text-gray-700'}`}>
                          {user.userId} {user.userId === currentUser && '(나)'}
                        </span>
                      </div>
                      <p className="text-xs text-gray-500">
                        {new Date(user.connectionTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})} 입장
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* 입력 영역 */}
        <form onSubmit={(e) => send(e, 'send_button')} className="flex gap-3 mt-2 md:mt-4">
          <TextInput
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="메시지를 입력하세요... (Enter로 전송)"
            className="flex-1"
            sizing="lg"
            disabled={!isConnected}
          />
          <Button 
            type="submit"
            disabled={!text.trim() || !isConnected}
            className="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700"
            size="lg"
          >
            <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
            전송
          </Button>
        </form>

        {!isConnected && (
          <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-700 text-sm text-center">
              채팅 서버와 연결이 끊어졌습니다. 페이지를 새로고침해주세요.
            </p>
          </div>
        )}
      </Card>
    </div>
  );
}
