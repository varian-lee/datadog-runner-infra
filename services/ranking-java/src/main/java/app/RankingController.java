package app;

/**
 * 🏆 Ranking Service (Java Spring Boot) - Datadog Runner 프로젝트
 * 
 * 게임 랭킹 마이크로서비스
 * - Redis ZSET: 게임 점수 랭킹 데이터 저장소
 * - RESTful API: /rankings/top 엔드포인트
 * - Datadog APM: Admission Controller로 자동 계측
 * - CORS: 분산 트레이싱 헤더 지원 (RUM-APM 연결)
 * 
 * 주요 기능:
 * - 상위 랭킹 조회 (기본 10개, limit 파라미터로 조정 가능)
 * - Redis에서 실시간 점수 데이터 조회
 * - 사용자별 최고 점수 및 타임스탬프 메타데이터 포함
 * - 성능 최적화: 캐싱 및 효율적인 쿼리
 */

import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Autowired;
import io.lettuce.core.*;
import io.lettuce.core.api.sync.RedisCommands;
import java.util.*;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
@CrossOrigin(
    origins = "*",
    allowedHeaders = {
        "*",
        "x-datadog-trace-id",
        "x-datadog-parent-id", 
        "x-datadog-origin",
        "x-datadog-sampling-priority",
        "traceparent",
        "tracestate",
        "b3"
    },
    exposedHeaders = {
        "x-datadog-trace-id",
        "x-datadog-parent-id",
        "traceparent",
        "tracestate"
    },
    methods = {RequestMethod.GET, RequestMethod.POST, RequestMethod.PUT, RequestMethod.DELETE, RequestMethod.OPTIONS}
)
public class RankingController {
  private final RedisClient client = RedisClient.create(System.getenv().getOrDefault("REDIS_DSN","redis://redis:6379/0"));
  private final Logger logger = LoggerFactory.getLogger(RankingController.class);
  
  

  // 헬스체크 엔드포인트 - ALB 헬스체크용
  @GetMapping("/")
  public Map<String, Object> healthCheck() {
    Map<String, Object> response = new HashMap<>();
    response.put("status", "healthy");
    response.put("service", "ranking-java");
    return response;
  }

  @GetMapping("/rankings/top")
  public List<Map<String,Object>> top(@RequestParam(value="limit", defaultValue="10") int limit) {
    logger.info("Fetching top rankings with limit: {}", limit);
    
    try (var conn = client.connect()) {
      RedisCommands<String,String> r = conn.sync();
      var arr = r.zrevrangeWithScores("game:scores", 0, limit-1);
      List<Map<String,Object>> out = new ArrayList<>();
      for (var v : arr) {
        String uid = v.getValue();
        Double sc = v.getScore();
        Map<String,String> meta = r.hgetall("game:scores:best:"+uid);
        long ts = meta.containsKey("ts") ? Long.parseLong(meta.get("ts")) : Instant.now().toEpochMilli();
        Map<String,Object> row = new HashMap<>();
        row.put("userId", uid);
        row.put("score", sc.intValue());
        row.put("ts", ts);
        out.add(row);
      }
      logger.info("Successfully fetched {} rankings from Redis", out.size());
      return out;
    } catch (Exception e) {
      logger.error("Error connecting to Redis: {}", e.getMessage());
      throw e;
    }
  }
}
