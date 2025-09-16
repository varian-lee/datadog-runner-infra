import React, { useEffect, useRef, useState } from "react";
import { rumAction, setGamePlayedStatus } from '../lib/rum';

// HTML-based Datadog Runner for Session Replay DOM tracking
export default function Game() {
  // Game state
  const [running, setRunning] = useState(false);
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(0);
  const [gameOver, setGameOver] = useState(false);
  const [dogPosition, setDogPosition] = useState({ x: 80, y: 200, jumping: false, jumpCount: 0 });
  const [obstacles, setObstacles] = useState([]);

  // Refs for game loop
  const gameLoopRef = useRef();
  const runningRef = useRef(running);
  const scoreRef = useRef(score);
  const dogRef = useRef(dogPosition);
  const obstaclesRef = useRef(obstacles);
  const gameOverRef = useRef(gameOver);
  const bestRef = useRef(best);

  // Game constants
  const GAME_WIDTH = 900;
  const GAME_HEIGHT = 320;
  const GROUND_Y = 260;
  
  // 물리 상수 - 프레임레이트 문제 해결 과정에서 조정
  // MacBook ProMotion 120Hz 모니터에서 requestAnimationFrame이 과도하게 빨라지는 문제 발견
  // 30fps 제한을 시도했으나 사용자 요청으로 되돌림, 현재는 60fps 고정 구현
  const GRAVITY = 0.8;        // 중력 (원래 값 유지)
  const JUMP_VELOCITY = -14;  // 점프 속도 (원래 값 유지)

  // Load best score & initialize game state
  useEffect(() => {
    const savedBest = Number(localStorage.getItem("best") || 0);
    setBest(savedBest);
    bestRef.current = savedBest;
    
    // 🎮 페이지 로드 시 게임 플레이 상태 초기화
    setGamePlayedStatus(false);
    
    // 🎯 퍼널 추적: 게임 페이지 방문
    rumAction('page_visited', { page: 'game', previousBest: savedBest });
  }, []);

  // Update refs when state changes
  useEffect(() => { runningRef.current = running; }, [running]);
  useEffect(() => { scoreRef.current = score; }, [score]);
  useEffect(() => { dogRef.current = dogPosition; }, [dogPosition]);
  useEffect(() => { obstaclesRef.current = obstacles; }, [obstacles]);
  useEffect(() => { gameOverRef.current = gameOver; }, [gameOver]);
  useEffect(() => { bestRef.current = best; }, [best]);

  // 🎯 퍼널 추적: 게임 점수 마일스톤
  useEffect(() => {
    if (score <= 0 || !running) return;

    const currentScore = Math.floor(score);
    const milestones = [50, 100, 200, 500, 1000, 2000];
    
    for (const milestone of milestones) {
      const storageKey = `milestone_${milestone}_reached`;
      const hasReached = sessionStorage.getItem(storageKey);
      
      if (currentScore >= milestone && !hasReached) {
        sessionStorage.setItem(storageKey, 'true');
        rumAction('game_milestone', { 
          milestone: `score_${milestone}`,
          currentScore: currentScore,
          isRunning: running
        });
      }
    }
  }, [score, running]);

  // Game over handler
  const handleGameOver = async () => {
    if (gameOverRef.current) return;
    
    setGameOver(true);
    setRunning(false);
    
    const finalScore = Math.floor(scoreRef.current);
    rumAction('game_over', { score: finalScore });
    
    // Update best score
    const newBest = Math.max(bestRef.current, finalScore);
    if (newBest !== bestRef.current) {
      setBest(newBest);
      localStorage.setItem("best", String(newBest));
    }

    // Send score to backend
    try {
      const response = await fetch('/api/score', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ score: finalScore })
      });
      
      if (response.ok) {
        // 🏆 게임 완료 - RUM 추적
        setGamePlayedStatus(true); // 점수 제출 성공 시 게임 완료로 마킹
        
        // 🎯 퍼널 추적: 게임 완료 정보 저장 (랭킹 확인 추적용)
        sessionStorage.setItem('game_completed', JSON.stringify({
          score: finalScore,
          completedAt: Date.now(),
          newBest: newBest > bestRef.current
        }));
        
        console.log('🏆 게임 완료 & 점수 제출 성공:', finalScore);
      }
    } catch (e) {
      console.error('Failed to save score:', e);
    }
  };

  // Start game
  const startGame = () => {
    if (runningRef.current) return;
    
    setRunning(true);
    setGameOver(false);
    setScore(0);
    setDogPosition({ x: 80, y: 200, jumping: false, jumpCount: 0 });
    setObstacles([]);
    
    // 🎯 퍼널 추적: 마일스톤 초기화 (새 게임 시작)
    const milestones = [50, 100, 200, 500, 1000, 2000];
    milestones.forEach(milestone => {
      sessionStorage.removeItem(`milestone_${milestone}_reached`);
    });
    
    // 🎮 게임 시작 - RUM 추적
    rumAction('game_start');
    setGamePlayedStatus(false); // 게임 시작했지만 아직 완료하지 않음
  };

  // Jump function
  const jump = () => {
    if (!runningRef.current || gameOverRef.current) return;
    
    const dog = dogRef.current;
    if (dog.jumpCount < 2) {
      setDogPosition(prev => ({
        ...prev,
        jumping: true,
        jumpCount: prev.jumpCount + 1,
        velocity: prev.jumpCount === 0 ? JUMP_VELOCITY : JUMP_VELOCITY * 0.85
      }));
      rumAction('jump');
    }
  };

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.code === "Space" || e.code === "ArrowUp") {
        e.preventDefault();
        jump();
      } else if (e.code === "KeyR") {
        startGame();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  // Game loop
  useEffect(() => {
    if (!running) return;

    let frameCount = 0;
    let speed = 6.6; // 기본 속도 10% 증가 (기존 6.0 → 6.6) - 난이도 조정 요청 반영
    let spawnTick = 0;
    let nextSpawn = 35;
    
    // 60fps 고정 게임 루프 구현 - 고주사율 모니터 대응
    // 문제: MacBook ProMotion 120Hz에서 requestAnimationFrame이 120fps로 실행되어 게임이 2배 빨라짐
    // 해결: 고정 60fps로 제한하여 일관된 게임 속도 보장
    let lastTime = 0;
    const targetFPS = 60;
    const frameDelay = 1000 / targetFPS; // 16.67ms - 60fps를 위한 프레임 간격

    // 동적 장애물 스폰 시스템 (원본 DogRunner에서 이식)
    // 기존 HTML 버전의 고정 스폰과 달리, 점수 기반 가속 및 랜덤 지터 적용
    const scheduleNextSpawn = () => {
      const base = 44;                                      // 기본 스폰 간격 (프레임 단위)
      const accel = Math.floor(scoreRef.current / 25);      // 점수 기반 가속 (25점당 1프레임 빨라짐, 20% 빠른 진행)
      const minInterval = 24;                               // 최소 스폰 간격 (너무 빠르지 않도록 제한)
      const interval = Math.max(minInterval, base - accel); // 최종 스폰 간격 계산
      nextSpawn = interval + Math.floor(Math.random() * 28); // 랜덤 지터 0~27프레임 추가하여 예측 불가능성 증대
    };
    
    scheduleNextSpawn(); // 첫 번째 장애물 스폰 스케줄링

    // 메인 게임 루프 - 60fps 고정으로 안정적인 게임 플레이 보장
    const gameLoop = (currentTime) => {
      if (!runningRef.current) return;

      // 60fps 제한: 16.67ms(frameDelay)보다 적게 지났으면 현재 프레임 스킵
      // 고주사율 모니터(120Hz, 144Hz 등)에서도 60fps로 일관된 속도 유지
      if (currentTime - lastTime < frameDelay) {
        gameLoopRef.current = requestAnimationFrame(gameLoop);
        return;
      }
      
      lastTime = currentTime;
      frameCount++;
      
      // Update score
      setScore(prev => prev + 0.2);
      
      // 점수 기반 속도 증가 - 난이도 조정 반영
      // 기본 속도: 6.6 (기존 6.0에서 10% 증가)
      // 진행 속도: scoreRef.current / 25 (기존 / 30에서 20% 빠르게 조정)
      // 최대 추가 속도: 11 (기존 10에서 10% 증가)
      speed = 6.6 + Math.min(11, Math.floor(scoreRef.current / 25));

      // Dog physics
      setDogPosition(prev => {
        let newY = prev.y;
        let newVelocity = prev.velocity || 0;
        let newJumping = prev.jumping;
        let newJumpCount = prev.jumpCount;

        if (prev.jumping) {
          newVelocity += GRAVITY;
          newY += newVelocity;
          
          if (newY >= GROUND_Y - 60) {
            newY = GROUND_Y - 60;
            newVelocity = 0;
            newJumping = false;
            newJumpCount = 0;
          }
        }

        return {
          ...prev,
          y: newY,
          velocity: newVelocity,
          jumping: newJumping,
          jumpCount: newJumpCount
        };
      });

      // Smart obstacle spawning (dynamic intervals + random jitter)
      spawnTick++;
      if (spawnTick >= nextSpawn) {
        const types = [
          { w: 18, h: 28 },
          { w: 28, h: 40 },
          { w: 42, h: 30 },
          { w: 30, h: 120 }
        ];
        const obstacle = types[Math.floor(Math.random() * types.length)];
        
        setObstacles(prev => [...prev, {
          id: Date.now(),
          x: GAME_WIDTH + 20,
          y: GROUND_Y - obstacle.h,
          width: obstacle.w,
          height: obstacle.h
        }]);

        // Optional burst spawning (like original)
        if (Math.random() < 0.2) {
          const offset = 40 + Math.floor(Math.random() * 60); // 40~99px ahead
          const burstObstacle = types[Math.floor(Math.random() * types.length)];
          setObstacles(prev => [...prev, {
            id: Date.now() + 1,
            x: GAME_WIDTH + 20 + offset,
            y: GROUND_Y - burstObstacle.h,
            width: burstObstacle.w,
            height: burstObstacle.h
          }]);
        }
        
        spawnTick = 0;
        scheduleNextSpawn(); // Schedule next spawn with new interval
      }

      // Move and clean obstacles
      setObstacles(prev => prev
        .map(obs => ({ ...obs, x: obs.x - speed }))
        .filter(obs => obs.x + obs.width > -50)
      );

      // Collision detection
      const dog = dogRef.current;
      const currentObstacles = obstaclesRef.current;
      
      for (const obs of currentObstacles) {
        if (
          dog.x + 30 > obs.x &&
          dog.x < obs.x + obs.width &&
          dog.y + 50 > obs.y &&
          dog.y < obs.y + obs.height
        ) {
          handleGameOver();
          return;
        }
      }

      gameLoopRef.current = requestAnimationFrame(gameLoop);
    };

    gameLoopRef.current = requestAnimationFrame(gameLoop);

    return () => {
      if (gameLoopRef.current) {
        cancelAnimationFrame(gameLoopRef.current);
      }
    };
  }, [running]);

  return (
    <div style={{maxWidth: 720, margin: '0 auto'}}>
      <h2 style={{textAlign: 'center', color: '#4b1f7e', marginBottom: '16px'}}>
        🐶 Datadog Pup Runner (HTML Edition)
      </h2>
      
      {/* Score Display */}
      <div style={{display: 'flex', gap: 16, marginBottom: 12}}>
        <strong data-testid="current-score">SCORE {Math.floor(score)}</strong>
        <span data-testid="best-score">BEST {best}</span>
      </div>

      {/* Game Container */}
      <div 
        className="game-container"
        onClick={!running ? startGame : jump}
        style={{
          position: 'relative',
          width: '100%',
          height: '320px',
          background: 'linear-gradient(to bottom, #f9fbff 0%, #eef3ff 100%)',
          borderRadius: '12px',
          boxShadow: '0 2px 12px rgba(0,0,0,.1)',
          overflow: 'hidden',
          cursor: 'pointer',
          border: '2px solid #e7e9ff'
        }}
        data-testid="game-area"
      >
        {/* Background Hills */}
        <div style={{
          position: 'absolute',
          bottom: '60px',
          left: 0,
          right: 0,
          height: '100px',
          background: '#e7e9ff',
          clipPath: 'polygon(0% 60%, 25% 40%, 50% 50%, 75% 30%, 100% 45%, 100% 100%, 0% 100%)'
        }} />

        {/* Ground */}
        <div style={{
          position: 'absolute',
          bottom: '60px',
          left: 0,
          right: 0,
          height: '2px',
          background: '#d2d7ff'
        }} />

        {/* Moving Ground Dashes */}
        <div style={{
          position: 'absolute',
          bottom: '46px',
          left: 0,
          right: 0,
          height: '2px',
          background: 'repeating-linear-gradient(to right, #c6cbff 0px, #c6cbff 8px, transparent 8px, transparent 20px)',
          animation: running ? 'groundMove 1s linear infinite' : 'none'
        }} />

        {/* Dog Character */}
        <div
          className="dog-character"
          data-testid="dog-player"
          data-jumping={dogPosition.jumping}
          data-jump-count={dogPosition.jumpCount}
          style={{
            position: 'absolute',
            left: `${dogPosition.x}px`,
            top: `${dogPosition.y}px`,
            width: '40px',
            height: '60px',
            transition: dogPosition.jumping ? 'none' : 'top 0.1s ease-out',
            zIndex: 10
          }}
        >
          {/* Dog Body */}
          <div style={{
            position: 'absolute',
            top: '10px',
            left: 0,
            width: '40px',
            height: '50px',
            background: '#632CA6',
            borderRadius: '10px'
          }} />
          
          {/* Dog Head */}
          <div style={{
            position: 'absolute',
            top: '-6px',
            left: '22px',
            width: '24px',
            height: '33px',
            background: '#632CA6',
            borderRadius: '10px'
          }} />
          
          {/* Ear */}
          <div style={{
            position: 'absolute',
            top: '-10px',
            left: '38px',
            width: '8px',
            height: '15px',
            background: '#4b1f7e',
            borderRadius: '6px'
          }} />
          
          {/* Eye */}
          <div style={{
            position: 'absolute',
            top: '1px',
            left: '38px',
            width: '4px',
            height: '4px',
            background: '#1c1330',
            borderRadius: '50%'
          }} />
          
          {/* Nose */}
          <div style={{
            position: 'absolute',
            top: '7px',
            left: '42px',
            width: '5px',
            height: '5px',
            background: '#1c1330',
            borderRadius: '50%'
          }} />
          
          {/* Collar */}
          <div style={{
            position: 'absolute',
            top: '35px',
            left: '8px',
            width: '20px',
            height: '6px',
            background: '#FF63B2',
            borderRadius: '3px'
          }} />
        </div>

        {/* Obstacles */}
        {obstacles.map(obstacle => (
          <div
            key={obstacle.id}
            className="obstacle"
            data-testid={`obstacle-${obstacle.id}`}
            style={{
              position: 'absolute',
              left: `${obstacle.x}px`,
              top: `${obstacle.y}px`,
              width: `${obstacle.width}px`,
              height: `${obstacle.height}px`,
              background: '#8890ff',
              borderRadius: '4px',
              zIndex: 5
            }}
          />
        ))}

        {/* Game Over / Start Overlay */}
        {!running && (
          <div 
            className="game-overlay"
            data-testid="game-overlay"
            data-game-over={gameOver}
            style={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
              background: 'rgba(255,255,255,0.95)',
              padding: '20px',
              borderRadius: '16px',
              textAlign: 'center',
              boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
              zIndex: 20
            }}
          >
            <h3 style={{color: '#4b1f7e', marginBottom: '10px'}}>
              {gameOver ? "앗! 다시 도전?" : "Datadog Pup Runner"}
            </h3>
            <p style={{fontSize: '14px', color: '#666', marginBottom: '10px'}}>
              스페이스/위쪽 화살표로 2단 점프 (모바일: 탭)
            </p>
            <p style={{fontSize: '12px', color: '#888'}}>
              {gameOver ? "R 키 또는 클릭으로 재시작" : "시작하려면 클릭"}
            </p>
          </div>
        )}
      </div>

      {/* Control Buttons */}
      <div style={{display: 'flex', gap: 8, marginTop: 12, justifyContent: 'center'}}>
        <button
          onClick={startGame}
          data-testid="start-button"
          style={{
            padding: '8px 16px',
            borderRadius: '8px',
            background: '#632CA6',
            color: 'white',
            border: 'none',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          {gameOver ? '다시 시작' : '게임 시작'}
        </button>
        <button
          onClick={() => {
            localStorage.removeItem("best");
            setBest(0);
          }}
          data-testid="reset-best-button"
          style={{
            padding: '8px 16px',
            borderRadius: '8px',
            background: '#f0f0f0',
            color: '#666',
            border: '1px solid #ddd',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          최고점 초기화
        </button>
      </div>

      {/* CSS Animation for ground movement */}
      <style jsx>{`
        @keyframes groundMove {
          from { background-position-x: 0px; }
          to { background-position-x: -20px; }
        }
      `}</style>
    </div>
  );
}
