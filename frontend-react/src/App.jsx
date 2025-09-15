// 메인 App 컴포넌트 - 인증, 라우팅, 네비게이션 관리
// 기존 demo 전용에서 회원가입 지원 및 사용자별 개인화 기능으로 확장
import { BrowserRouter, Routes, Route, Link, Navigate } from 'react-router-dom';
import { Navbar, Avatar, Dropdown, Button } from 'flowbite-react';
import Login from './pages/Login.jsx';
import Signup from './pages/Signup.jsx';  // 회원가입 기능 추가
import Game from './pages/Game.jsx';
import Ranking from './pages/Ranking.jsx';
import Chat from './pages/Chat.jsx';
import { useEffect, useState } from 'react';

export default function App() {
  // 인증 상태 관리
  const [authed, setAuthed] = useState(false);
  
  // 로그인/회원가입 화면 전환 관리 - 새로운 사용자 가입 지원
  const [showSignup, setShowSignup] = useState(false);
  
  // 현재 로그인한 사용자 정보 - 네비게이션 바 및 채팅에서 표시
  const [currentUser, setCurrentUser] = useState('');

  // 앱 초기화 시 세션 확인 - 새로고침해도 로그인 상태 유지
  useEffect(() => {
    fetch('/api/session/me', { credentials: 'include' })
      .then(r => r.ok ? r.json() : Promise.reject())
      .then(data => {
        setAuthed(true);
        // 기존: 고정된 사용자 정보 → 현재: 실제 로그인한 사용자 ID 표시
        setCurrentUser(data.user_id || '사용자');
      })
      .catch(() => {
        setAuthed(false);
        setCurrentUser('');
      });
  }, []);

  // 로그아웃 핸들러 - 프론트엔드 상태 리셋으로 UX 개선
  // 기존: API 호출 후 리다이렉트 → 현재: 즉시 로그인 화면으로 이동
  const handleLogout = () => {
    setAuthed(false);
    setCurrentUser('');
    setShowSignup(false); // 로그인 화면으로 리셋
  };

  // 로그인/회원가입 성공 후 처리 - 사용자 정보 갱신
  // 로그인과 회원가입(자동 로그인) 모두에서 공통으로 사용
  const handleLoginSuccess = () => {
    fetch('/api/session/me', { credentials: 'include' })
      .then(r => r.ok ? r.json() : Promise.reject())
      .then(data => {
        setAuthed(true);
        setCurrentUser(data.user_id || '사용자');
      })
      .catch(() => {
        setAuthed(false);
        setCurrentUser('');
      });
  };

  // 인증 화면 컴포넌트 - 로그인/회원가입 조건부 렌더링
  // 기존: 고정된 Login 컴포넌트 → 현재: 동적 Login/Signup 전환
  const AuthPage = () => {
    if (showSignup) {
      return (
        <Signup 
          onLogin={handleLoginSuccess}                    // 회원가입 후 자동 로그인
          onSwitchToLogin={() => setShowSignup(false)}   // "로그인" 버튼 클릭 시
        />
      );
    } else {
      return (
        <Login 
          onLogin={handleLoginSuccess}                    // 로그인 성공 시
          onSwitchToSignup={() => setShowSignup(true)}   // "회원가입" 버튼 클릭 시
        />
      );
    }
  };

  return (
    <BrowserRouter>
      <Navbar fluid rounded className="bg-gradient-to-r from-purple-600 to-blue-600 shadow-lg">
        <Navbar.Brand as={Link} to="/">
          <span className="self-center whitespace-nowrap text-xl font-semibold text-white flex items-center gap-2">
            🐶 Datadog Runner
          </span>
        </Navbar.Brand>
        {authed && (
          <>
            {/* 사용자 정보 및 로그아웃 드롭다운 - 개인화된 네비게이션 제공 */}
            <div className="flex md:order-2">
              <Dropdown
                arrowIcon={false}
                inline
                label={
                  // 아바타 개선: 기존 고정 이미지 → 사용자 ID 첫 글자 기반 이니셜 표시
                  <Avatar 
                    alt="User settings" 
                    placeholderInitials={currentUser?.charAt(0)?.toUpperCase() || '?'}
                    rounded 
                    className="ring-2 ring-white"
                  />
                }
              >
                {/* 사용자 정보 표시: 기존 "user@example.com" → 실제 로그인 사용자 ID */}
                <Dropdown.Header>
                  <span className="block text-sm">플레이어</span>
                  <span className="block truncate text-sm font-medium">{currentUser || '사용자'}</span>
                </Dropdown.Header>
                {/* 로그아웃: 기존 API 호출 방식 → 즉시 상태 리셋으로 UX 개선 */}
                <Dropdown.Item onClick={handleLogout} className="text-red-600 hover:bg-red-50 cursor-pointer">
                  로그아웃
                </Dropdown.Item>
              </Dropdown>
              <Navbar.Toggle />
            </div>
            <Navbar.Collapse>
              <Navbar.Link as={Link} to="/game" className="text-white hover:text-purple-200 text-base font-medium">
                🎮 게임 하기
              </Navbar.Link>
              <Navbar.Link as={Link} to="/ranking" className="text-white hover:text-purple-200 text-base font-medium">
                🏆 랭킹 보기
              </Navbar.Link>
              <Navbar.Link as={Link} to="/chat" className="text-white hover:text-purple-200 text-base font-medium">
                💬 채팅
              </Navbar.Link>
            </Navbar.Collapse>
          </>
        )}
      </Navbar>
      
      <main className="min-h-screen bg-gradient-to-br from-blue-50 to-purple-50 p-6">
        <div className="mx-auto max-w-7xl">
          <Routes>
            <Route path="/" element={authed ? <Navigate to="/game" /> : <AuthPage />} />
            <Route path="/game" element={authed ? <Game /> : <Navigate to="/" />} />
            <Route path="/ranking" element={authed ? <Ranking /> : <Navigate to="/" />} />
            <Route path="/chat" element={authed ? <Chat /> : <Navigate to="/" />} />
          </Routes>
        </div>
      </main>
    </BrowserRouter>
  );
}
