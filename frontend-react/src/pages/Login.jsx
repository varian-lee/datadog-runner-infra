import { useState } from 'react';
import { Card, Button, Label, TextInput, Alert } from 'flowbite-react';
import { setRumUser } from '../lib/rum';

export default function Login({ onLogin, onSwitchToSignup }) {
  const [id, setId] = useState('');
  const [pw, setPw] = useState('');
  const [err, setErr] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setErr('');
    setLoading(true);
    
    try {
      // 1. 로그인 시도
      const loginResponse = await fetch('/api/auth/login', {
        method: 'POST',
        headers:{'Content-Type':'application/json'},
        credentials: 'include',
        body: JSON.stringify({ id, pw })
      });
      
      if (loginResponse.ok) {
        // 2. 로그인 성공 시 사용자 정보 가져오기
        try {
          const userResponse = await fetch('/api/session/me', {
            method: 'GET',
            credentials: 'include'
          });
          
          if (userResponse.ok) {
            const userInfo = await userResponse.json();
            // 3. Datadog RUM에 사용자 정보 설정 - 디버깅 추가
            console.log('🔍 API 응답 원본:', userInfo);
            console.log('🔍 DD_RUM 객체 상태:', window.DD_RUM ? '✅ 존재' : '❌ 없음');
            console.log('🔍 setUser 함수:', window.DD_RUM?.setUser ? '✅ 존재' : '❌ 없음');
            
            setRumUser(userInfo);
            console.log('🔐 로그인 성공 & RUM User 설정 시도:', userInfo);
          }
        } catch (userError) {
          console.warn('⚠️ 사용자 정보 조회 실패 (로그인은 성공):', userError);
        }
        
        onLogin();
      } else {
        setErr('로그인에 실패했습니다. 아이디와 비밀번호를 확인해주세요.');
      }
    } catch (error) {
      setErr('서버와의 연결에 문제가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md">
        <Card className="shadow-2xl border-0">
          <div className="text-center mb-6">
            <div className="text-6xl mb-4">🐶</div>
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Datadog Runners</h1>
            <p className="text-gray-500">게임에 참가하려면 로그인하세요</p>
          </div>
          
          <form onSubmit={submit} className="space-y-6">
            <div>
              <Label htmlFor="userId" value="아이디" className="mb-2 block text-sm font-medium text-gray-900" />
              <TextInput
                id="userId"
                type="text"
                placeholder="아이디를 입력하세요"
                value={id}
                onChange={(e) => setId(e.target.value)}
                required
                className="w-full"
                sizing="lg"
              />
            </div>
            
            <div>
              <Label htmlFor="password" value="비밀번호" className="mb-2 block text-sm font-medium text-gray-900" />
              <TextInput
                id="password"
                type="password"
                placeholder="비밀번호를 입력하세요"
                value={pw}
                onChange={(e) => setPw(e.target.value)}
                required
                className="w-full"
                sizing="lg"
              />
            </div>
            
            {err && (
              <Alert color="failure" className="mb-4">
                <span className="font-medium">오류!</span> {err}
              </Alert>
            )}
            
            <Button 
              type="submit" 
              className="w-full bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700"
              size="lg"
              disabled={loading}
            >
              {loading ? (
                <>
                  <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  로그인 중...
                </>
              ) : (
                '로그인'
              )}
            </Button>
          </form>
          
          <div className="mt-6 text-center">
            <p className="text-sm text-gray-500">
              계정이 없으신가요? 
              <button 
                type="button"
                onClick={onSwitchToSignup}
                className="ml-1 text-purple-600 hover:text-purple-700 font-medium"
              >
                회원가입
              </button>
            </p>
          </div>
        </Card>
      </div>
    </div>
  );
}
