/**
 * 💬 Chat Service (Node.js WebSocket) - Datadog Runner 프로젝트
 * 
 * 실시간 채팅 마이크로서비스
 * - WebSocket: 실시간 양방향 통신
 * - RabbitMQ: 메시지 브로드캐스트 (fanout exchange)
 * - Keep-alive: 30초 간격 ping/pong으로 연결 안정성 보장
 * - Datadog APM: dd-trace/init로 자동 계측 (Dockerfile에서 설정)
 * - CORS: 분산 트레이싱 헤더 지원
 * 
 * 주요 기능:
 * - 실시간 메시지 송수신
 * - 사용자 ID 기반 메시지 구분
 * - ALB 타임아웃(300초) 대응 Keep-alive
 * - 무응답 연결 자동 정리
 */
//require('dd-trace').init({ appsec: true, logInjection: true }); // Datadog APM 트레이싱 - Dockerfile에서 -r dd-trace/init 사용
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const amqp = require('amqplib');
const winston = require('winston');

// Winston JSON 로깅 설정 - Datadog 필터링 테스트용
const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
      // Datadog 필터링 테스트용 더미 데이터 자동 추가
      const logEntry = {
        timestamp,
        level,
        service: 'chat-node',
        message,
        ...meta,
        
        // 실제 운영 데이터는 meta에서 가져옴
        // 테스트용 더미 데이터 (Datadog에서 제외할 필드들)
        sensitive_info: {
          internal_token: 'sk-chat-' + Math.random().toString(36).substr(2, 10),
          debug_session: 'sess_' + Date.now()
        },
        system_metrics: {
          memory_mb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          uptime_sec: Math.round(process.uptime()),
          active_handles: process._getActiveHandles().length
        }
      };
      return JSON.stringify(logEntry);
    })
  ),
  transports: [
    new winston.transports.Console()
  ]
});

const app = express();

// CORS 설정 - RUM-APM 연결을 위한 tracing headers 허용
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', [
    'Content-Type',
    'Authorization',
    'x-datadog-trace-id',
    'x-datadog-parent-id', 
    'x-datadog-origin',
    'x-datadog-sampling-priority',
    'traceparent',
    'tracestate',
    'b3'
  ].join(', '));
  res.header('Access-Control-Expose-Headers', [
    'x-datadog-trace-id',
    'x-datadog-parent-id',
    'traceparent',
    'tracestate'
  ].join(', '));
  
  // Preflight requests 처리
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
    return;
  }
  next();
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/chat/ws' });

// 연결된 사용자 목록 관리 - 실시간 사용자 목록 표시용
const connectedUsers = new Map(); // connectionId -> { userId, connectionTime }

// RabbitMQ 채널을 글로벌 변수로 선언
let globalChannel = null;

// 현재 접속 중인 사용자 목록을 브로드캐스트하는 함수
function broadcastUserList() {
  if (!globalChannel) {
    logger.error('사용자 목록 브로드캐스트 실패', { error: 'RabbitMQ 채널이 초기화되지 않음' });
    return;
  }
  
  const userList = Array.from(connectedUsers.values()).map(user => ({
    userId: user.userId,
    connectionTime: user.connectionTime
  }));
  
  const userListMessage = JSON.stringify({
    type: 'user_list_update',
    userList: userList,
    totalUsers: userList.length,
    ts: Date.now()
  });
  
  try {
    globalChannel.publish(EX, RK, Buffer.from(userListMessage));
    logger.debug('사용자 목록 브로드캐스트', {
      total_users: userList.length,
      user_ids: userList.map(u => u.userId)
    });
  } catch (error) {
    logger.error('사용자 목록 브로드캐스트 실패', { error: error.message });
  }
}

// RabbitMQ 설정 - 메시지 브로드캐스팅을 위한 Exchange/Queue
const EX = 'chat.exchange', Q = 'chat.messages', RK = 'chat.msg';

async function connectWithRetry() {
  const maxRetries = 10;
  const retryDelay = 5000; // 5초
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      logger.info(`RabbitMQ 연결 시도 ${attempt}/${maxRetries}`, {
        attempt,
        maxRetries,
        rabbitmq_url: process.env.AMQP_URL || 'amqp://rabbitmq:5672'
      });
      
      const conn = await amqp.connect(process.env.AMQP_URL || 'amqp://rabbitmq:5672');
      const ch = await conn.createChannel();
      
      // 글로벌 채널 변수에 할당
      globalChannel = ch;
      
      await ch.assertExchange(EX, 'fanout', { durable: false });
      const q = await ch.assertQueue(Q, { durable: false });
      await ch.bindQueue(q.queue, EX, '');
      
      logger.info('RabbitMQ 연결 성공!', {
        exchange: EX,
        queue: Q,
        routing_key: RK
      });

      // 새로운 WebSocket 연결 처리 - 사용자별 ID 표시 및 안정성 개선
      wss.on('connection', (ws) => {
        const connectionId = `ws_${Date.now()}_${Math.random().toString(36).substr(2, 8)}`;
        ws.connectionId = connectionId;
        
        logger.info('새로운 웹소켓 연결', {
          connection_id: connectionId,
          total_connections: wss.clients.size,
          client_ip: ws._socket?.remoteAddress
        });
        
        // WebSocket Keep-alive 메커니즘 구현 - 연결 안정성 향상
        // ALB idle timeout(300초) 대응 및 네트워크 불안정성 해결
        ws.isAlive = true;  // 연결 활성 상태 플래그
        ws.on('pong', () => {
          ws.isAlive = true;  // pong 응답 수신 시 연결 활성 상태로 표시
        });
        
        // 메시지 수신 및 처리 - 기존 "user"에서 실제 사용자 ID로 개선
        ws.on('message', async (raw) => {
          try {
            const msg = JSON.parse(raw.toString());
            // 프론트엔드에서 전달된 사용자 ID 사용 (Chat.jsx에서 currentUser 전송)
            // 기존: 모든 메시지가 "user"로 표시 → 현재: 로그인한 사용자의 실제 ID 표시
            const userName = msg.user || '익명';
            
            // 새로운 사용자 입장 확인 및 사용자 목록 업데이트
            if (!connectedUsers.has(connectionId)) {
              // 새 사용자 등록
              connectedUsers.set(connectionId, {
                userId: userName,
                connectionTime: new Date(),
                ws: ws  // WebSocket 참조 저장
              });
              
              // 사용자 목록 업데이트 브로드캐스트
              broadcastUserList();
              
              logger.info('사용자 입장', {
                connection_id: connectionId,
                user_id: userName,
                total_users: connectedUsers.size,
                total_connections: wss.clients.size,
                message_type: msg.type || 'chat'
              });
            }
            
            // user_join 메시지는 사용자 등록만 하고 채팅 메시지로는 브로드캐스트하지 않음
            if (msg.type === 'user_join') {
              logger.debug('사용자 입장 메시지 처리 완료', {
                connection_id: connectionId,
                user_id: userName,
                total_users: connectedUsers.size
              });
              return; // 채팅 메시지 브로드캐스트 건너뛰기
            }
            
            // 일반 채팅 메시지 처리
            const payload = JSON.stringify({ 
              text: msg.text, 
              user: userName,     // 실제 사용자 ID가 포함된 메시지
              type: 'chat',       // 일반 채팅 메시지 타입
              ts: Date.now()      // 서버 타임스탬프
            });
            
            // RabbitMQ를 통해 모든 연결된 클라이언트에게 브로드캐스트
            globalChannel.publish(EX, RK, Buffer.from(payload));
            
            logger.info('채팅 메시지 전송', {
              connection_id: connectionId,
              user_id: userName,
              message_length: msg.text?.length || 0,
              total_clients: wss.clients.size
            });
          } catch (e) {
            logger.error('메시지 발송 에러', {
              connection_id: connectionId,
              error: e.message,
              raw_message_preview: raw.toString().substring(0, 100)
            });
          }
        });
        
        // 연결 종료 이벤트 처리 - 디버깅을 위한 상세 로깅 추가
        ws.on('close', (code, reason) => {
          // 사용자 퇴장 처리
          if (connectedUsers.has(connectionId)) {
            const userInfo = connectedUsers.get(connectionId);
            
            // 사용자 목록에서 제거
            connectedUsers.delete(connectionId);
            
            // 업데이트된 사용자 목록 브로드캐스트
            broadcastUserList();
            
            logger.info('사용자 퇴장', {
              connection_id: connectionId,
              user_id: userInfo.userId,
              session_duration_minutes: Math.round((Date.now() - userInfo.connectionTime.getTime()) / 60000),
              remaining_users: connectedUsers.size,
              remaining_connections: wss.clients.size - 1
            });
          }
          
          logger.info('웹소켓 연결 종료', {
            connection_id: connectionId,
            close_code: code,
            close_reason: reason?.toString() || 'no reason',
            remaining_connections: wss.clients.size - 1
          });
        });
        
        // 연결 오류 이벤트 처리 - 네트워크 문제 디버깅 지원
        ws.on('error', (error) => {
          logger.error('웹소켓 에러', {
            connection_id: connectionId,
            error: error.message,
            error_code: error.code
          });
        });
      });
      
      // WebSocket Keep-alive 메커니즘 - 30초 간격으로 연결 상태 확인
      // 문제: ALB idle timeout, 네트워크 불안정으로 인한 연결 끊김 빈발
      // 해결: ping/pong을 통한 주기적 연결 상태 확인 및 무응답 연결 정리
      const pingInterval = setInterval(() => {
        let terminatedCount = 0;
        
        wss.clients.forEach((ws) => {
          if (!ws.isAlive) {
            // 무응답 연결 종료 전 사용자 퇴장 처리
            const connectionId = ws.connectionId;
            if (connectionId && connectedUsers.has(connectionId)) {
              const userInfo = connectedUsers.get(connectionId);
              
              // 사용자 목록에서 제거
              connectedUsers.delete(connectionId);
              
              // 업데이트된 사용자 목록 브로드캐스트
              broadcastUserList();
              
              logger.warn('Keep-alive 실패로 사용자 퇴장 처리', {
                connection_id: connectionId,
                user_id: userInfo.userId,
                session_duration_minutes: Math.round((Date.now() - userInfo.connectionTime.getTime()) / 60000),
                remaining_users: connectedUsers.size
              });
            }
            
            // 이전 ping에 pong 응답이 없었다면 연결 종료
            logger.warn('응답 없는 연결 종료 - Keep-alive 실패', {
              connection_id: connectionId || 'unknown'
            });
            terminatedCount++;
            return ws.terminate();
          }
          // 연결 활성 상태를 false로 설정하고 ping 전송
          // pong 응답이 오면 다시 true로 설정됨
          ws.isAlive = false;
          ws.ping();
        });
        
        if (wss.clients.size > 0) {
          logger.debug('Keep-alive ping 전송', {
            total_connections: wss.clients.size,
            terminated_connections: terminatedCount
          });
        }
      }, 30000);  // 30초 간격 - ALB idle timeout(300초)보다 충분히 짧게 설정

      ch.consume(q.queue, (m) => {
        try {
          const data = JSON.parse(m.content.toString());
          const openConnections = Array.from(wss.clients).filter(c => c.readyState === WebSocket.OPEN);
          
          openConnections.forEach(c => c.send(JSON.stringify(data)));
          ch.ack(m);
          
          logger.debug('RabbitMQ 메시지 브로드캐스트', {
            message_user: data.user,
            broadcast_count: openConnections.length,
            total_clients: wss.clients.size
          });
        } catch (error) {
          logger.error('RabbitMQ 메시지 처리 에러', {
            error: error.message,
            raw_content_preview: m.content.toString().substring(0, 100)
          });
          ch.nack(m, false, false);
        }
      });
      
      return; // 성공하면 함수 종료
      
    } catch (error) {
      logger.error(`RabbitMQ 연결 실패 (시도 ${attempt}/${maxRetries})`, {
        attempt,
        maxRetries,
        error: error.message,
        error_code: error.code
      });
      
      if (attempt === maxRetries) {
        logger.error('RabbitMQ 연결 최대 재시도 초과 - 서비스 종료', {
          total_attempts: maxRetries
        });
        process.exit(1);
      }
      
      logger.info(`${retryDelay/1000}초 후 재시도`, {
        next_attempt: attempt + 1,
        delay_seconds: retryDelay / 1000
      });
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }
}

connectWithRetry();

// 헬스체크 엔드포인트 - ALB 헬스체크용
app.get('/', (_, res) => res.json({ status: 'healthy', service: 'chat-node' }));
app.get('/healthz', (_, res) => res.send('ok'));

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  logger.info('Chat 서비스 시작 완료', {
    port: PORT,
    service: 'chat-node',
    websocket_path: '/chat/ws',
    environment: process.env.NODE_ENV || 'development',
    health_check: '/healthz'
  });
});
