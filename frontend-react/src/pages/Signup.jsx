import { useState } from 'react';
import { Card, Button, Label, TextInput, Alert } from 'flowbite-react';

export default function Signup({ onLogin, onSwitchToLogin }) {
  const [id, setId] = useState('');
  const [pw, setPw] = useState('');
  const [pwConfirm, setPwConfirm] = useState('');
  const [err, setErr] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setErr('');
    
    // Client-side validation
    if (id.length < 3) {
      setErr('아이디는 3글자 이상이어야 합니다.');
      return;
    }
    if (pw.length < 4) {
      setErr('비밀번호는 4글자 이상이어야 합니다.');
      return;
    }
    if (pw !== pwConfirm) {
      setErr('비밀번호가 일치하지 않습니다.');
      return;
    }
    
    setLoading(true);
    
    try {
      const r = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ id, pw })
      });
      
      const data = await r.json();
      
      if (r.ok) {
        onLogin(); // Auto login after successful signup
      } else {
        setErr(data.detail || '회원가입에 실패했습니다.');
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
            <p className="text-gray-500">새 계정을 만들어 게임을 시작하세요</p>
          </div>
          
          <form onSubmit={submit} className="space-y-6">
            <div>
              <Label htmlFor="userId" value="아이디" className="mb-2 block text-sm font-medium text-gray-900" />
              <TextInput
                id="userId"
                type="text"
                placeholder="3글자 이상의 아이디"
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
                placeholder="4글자 이상의 비밀번호"
                value={pw}
                onChange={(e) => setPw(e.target.value)}
                required
                className="w-full"
                sizing="lg"
              />
            </div>
            
            <div>
              <Label htmlFor="passwordConfirm" value="비밀번호 확인" className="mb-2 block text-sm font-medium text-gray-900" />
              <TextInput
                id="passwordConfirm"
                type="password"
                placeholder="비밀번호를 다시 입력하세요"
                value={pwConfirm}
                onChange={(e) => setPwConfirm(e.target.value)}
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
              className="w-full !bg-gradient-to-r !from-lime-600 !to-green-600 hover:!from-lime-700 hover:!to-green-700"
              size="lg"
              disabled={loading}
              style={{
                background: 'linear-gradient(to right, #65a30d, #16a34a)',
                borderColor: 'transparent'
              }}
            >
              {loading ? (
                <>
                  <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  가입 중...
                </>
              ) : (
                '회원가입'
              )}
            </Button>
          </form>
          
          <div className="mt-6 text-center">
            <p className="text-sm text-gray-500">
              이미 계정이 있으신가요? 
              <button 
                type="button"
                onClick={onSwitchToLogin}
                className="ml-1 text-purple-600 hover:text-purple-700 font-medium"
              >
                로그인
              </button>
            </p>
          </div>
        </Card>
      </div>
    </div>
  );
}
