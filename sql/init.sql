CREATE TABLE IF NOT EXISTS users (
  id       VARCHAR(64) PRIMARY KEY,
  pw_hash  TEXT        NOT NULL
);
INSERT INTO users(id, pw_hash) VALUES ('demo', 'demo') ON CONFLICT DO NOTHING;

-- 🎮 게임 점수 테이블 (PostgreSQL 전용 랭킹 시스템)
CREATE TABLE IF NOT EXISTS scores (
  id         SERIAL PRIMARY KEY,
  user_id    VARCHAR(64) NOT NULL,
  high_score INTEGER     NOT NULL DEFAULT 0,
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성 (PostgreSQL 정확한 문법)
CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_high_score ON scores(high_score DESC);

-- 🎯 200명 만화 캐릭터 샘플 데이터 (Connection Pool 고갈 테스트용)
-- 모든 점수는 0으로 시작 (실제 게임 플레이를 통해 점수 획득)
INSERT INTO scores (user_id, high_score, created_at) VALUES 
  -- 크레용 신짱
  ('test_짱구', 0, NOW() - INTERVAL '1 day'),
  ('test_맹구', 0, NOW() - INTERVAL '2 day'),
  ('test_훈이', 0, NOW() - INTERVAL '3 day'),
  ('test_철수', 0, NOW() - INTERVAL '4 day'),
  ('test_유리', 0, NOW() - INTERVAL '5 day'),
  
  -- 뽀로로
  ('test_뽀로로', 0, NOW() - INTERVAL '6 day'),
  ('test_크롱', 0, NOW() - INTERVAL '7 day'),
  ('test_에디', 0, NOW() - INTERVAL '8 day'),
  ('test_루피', 0, NOW() - INTERVAL '9 day'),
  ('test_포비', 0, NOW() - INTERVAL '10 day'),
  ('test_패티', 0, NOW() - INTERVAL '11 day'),
  ('test_해리', 0, NOW() - INTERVAL '12 day'),
  
  -- 드래곤볼
  ('test_손오공', 0, NOW() - INTERVAL '13 day'),
  ('test_베지터', 0, NOW() - INTERVAL '14 day'),
  ('test_피콜로', 0, NOW() - INTERVAL '15 day'),
  ('test_크리링', 0, NOW() - INTERVAL '16 day'),
  ('test_부르마', 0, NOW() - INTERVAL '17 day'),
  ('test_트랭크스', 0, NOW() - INTERVAL '18 day'),
  ('test_손오반', 0, NOW() - INTERVAL '19 day'),
  ('test_프리더', 0, NOW() - INTERVAL '20 day'),
  
  -- 원피스
  ('test_루피', 0, NOW() - INTERVAL '21 day'),
  ('test_조로', 0, NOW() - INTERVAL '22 day'),
  ('test_나미', 0, NOW() - INTERVAL '23 day'),
  ('test_우솝', 0, NOW() - INTERVAL '24 day'),
  ('test_상디', 0, NOW() - INTERVAL '25 day'),
  ('test_쵸파', 0, NOW() - INTERVAL '26 day'),
  ('test_로빈', 0, NOW() - INTERVAL '27 day'),
  ('test_프랑키', 0, NOW() - INTERVAL '28 day'),
  ('test_브룩', 0, NOW() - INTERVAL '29 day'),
  ('test_징베', 0, NOW() - INTERVAL '30 day'),
  
  -- 나루토
  ('test_나루토', 0, NOW() - INTERVAL '31 day'),
  ('test_사스케', 0, NOW() - INTERVAL '32 day'),
  ('test_사쿠라', 0, NOW() - INTERVAL '33 day'),
  ('test_카카시', 0, NOW() - INTERVAL '34 day'),
  ('test_가이', 0, NOW() - INTERVAL '35 day'),
  ('test_리', 0, NOW() - INTERVAL '36 day'),
  ('test_네지', 0, NOW() - INTERVAL '37 day'),
  ('test_텐텐', 0, NOW() - INTERVAL '38 day'),
  ('test_시카마루', 0, NOW() - INTERVAL '39 day'),
  ('test_이노', 0, NOW() - INTERVAL '40 day'),
  
  -- 포켓몬
  ('test_피카츄', 0, NOW() - INTERVAL '41 day'),
  ('test_이상해씨', 0, NOW() - INTERVAL '42 day'),
  ('test_파이리', 0, NOW() - INTERVAL '43 day'),
  ('test_꼬부기', 0, NOW() - INTERVAL '44 day'),
  ('test_롱스톤', 0, NOW() - INTERVAL '45 day'),
  ('test_피죤투', 0, NOW() - INTERVAL '46 day'),
  ('test_야도란', 0, NOW() - INTERVAL '47 day'),
  ('test_팬텀', 0, NOW() - INTERVAL '48 day'),
  ('test_망나뇽', 0, NOW() - INTERVAL '49 day'),
  ('test_뮤츠', 0, NOW() - INTERVAL '50 day'),
  
  -- 슬램덩크
  ('test_강백호', 0, NOW() - INTERVAL '51 day'),
  ('test_서태웅', 0, NOW() - INTERVAL '52 day'),
  ('test_채치수', 0, NOW() - INTERVAL '53 day'),
  ('test_송태섭', 0, NOW() - INTERVAL '54 day'),
  ('test_정대만', 0, NOW() - INTERVAL '55 day'),
  ('test_윤대협', 0, NOW() - INTERVAL '56 day'),
  ('test_변덕규', 0, NOW() - INTERVAL '57 day'),
  ('test_신현철', 0, NOW() - INTERVAL '58 day'),
  ('test_이정환', 0, NOW() - INTERVAL '59 day'),
  ('test_홍익현', 0, NOW() - INTERVAL '60 day'),
  
  -- 디지몬
  ('test_태일', 0, NOW() - INTERVAL '61 day'),
  ('test_야마토', 0, NOW() - INTERVAL '62 day'),
  ('test_소라', 0, NOW() - INTERVAL '63 day'),
  ('test_미미', 0, NOW() - INTERVAL '64 day'),
  ('test_아구몬', 0, NOW() - INTERVAL '65 day'),
  ('test_가부몬', 0, NOW() - INTERVAL '66 day'),
  ('test_피요몬', 0, NOW() - INTERVAL '67 day'),
  ('test_팔몬', 0, NOW() - INTERVAL '68 day'),
  ('test_고마몬', 0, NOW() - INTERVAL '69 day'),
  ('test_파타몬', 0, NOW() - INTERVAL '70 day'),
  
  -- 세일러문
  ('test_세일러문', 0, NOW() - INTERVAL '71 day'),
  ('test_세일러머큐리', 0, NOW() - INTERVAL '72 day'),
  ('test_세일러마스', 0, NOW() - INTERVAL '73 day'),
  ('test_세일러주피터', 0, NOW() - INTERVAL '74 day'),
  ('test_세일러비너스', 0, NOW() - INTERVAL '75 day'),
  ('test_턱시도가면', 0, NOW() - INTERVAL '76 day'),
  ('test_루나', 0, NOW() - INTERVAL '77 day'),
  ('test_아르테미스', 0, NOW() - INTERVAL '78 day'),
  ('test_치비우사', 0, NOW() - INTERVAL '79 day'),
  ('test_세일러플루토', 0, NOW() - INTERVAL '80 day'),
  
  -- 도라에몽
  ('test_도라에몽', 0, NOW() - INTERVAL '81 day'),
  ('test_노비타', 0, NOW() - INTERVAL '82 day'),
  ('test_시즈카', 0, NOW() - INTERVAL '83 day'),
  ('test_자이안', 0, NOW() - INTERVAL '84 day'),
  ('test_스네오', 0, NOW() - INTERVAL '85 day'),
  ('test_도라미', 0, NOW() - INTERVAL '86 day'),
  ('test_미니도라', 0, NOW() - INTERVAL '87 day'),
  ('test_퍼맨', 0, NOW() - INTERVAL '88 day'),
  ('test_코퍼', 0, NOW() - INTERVAL '89 day'),
  ('test_부비', 0, NOW() - INTERVAL '90 day'),
  
  -- 명탐정 코난
  ('test_코난', 0, NOW() - INTERVAL '91 day'),
  ('test_신이치', 0, NOW() - INTERVAL '92 day'),
  ('test_란', 0, NOW() - INTERVAL '93 day'),
  ('test_소노코', 0, NOW() - INTERVAL '94 day'),
  ('test_고로', 0, NOW() - INTERVAL '95 day'),
  ('test_아가사박사', 0, NOW() - INTERVAL '96 day'),
  ('test_하이바라', 0, NOW() - INTERVAL '97 day'),
  ('test_겐타', 0, NOW() - INTERVAL '98 day'),
  ('test_미츠히코', 0, NOW() - INTERVAL '99 day'),
  ('test_아유미', 0, NOW() - INTERVAL '100 day'),
  
  -- 이누야샤
  ('test_이누야샤', 0, NOW() - INTERVAL '101 day'),
  ('test_카고메', 0, NOW() - INTERVAL '102 day'),
  ('test_미로쿠', 0, NOW() - INTERVAL '103 day'),
  ('test_산고', 0, NOW() - INTERVAL '104 day'),
  ('test_싯포', 0, NOW() - INTERVAL '105 day'),
  ('test_키쿄우', 0, NOW() - INTERVAL '106 day'),
  ('test_나라쿠', 0, NOW() - INTERVAL '107 day'),
  ('test_셋쇼마루', 0, NOW() - INTERVAL '108 day'),
  ('test_린', 0, NOW() - INTERVAL '109 day'),
  ('test_쟈켄', 0, NOW() - INTERVAL '110 day'),
  
  -- 건담
  ('test_아무로', 0, NOW() - INTERVAL '111 day'),
  ('test_샤아', 0, NOW() - INTERVAL '112 day'),
  ('test_카미유', 0, NOW() - INTERVAL '113 day'),
  ('test_쥬도', 0, NOW() - INTERVAL '114 day'),
  ('test_히이로', 0, NOW() - INTERVAL '115 day'),
  ('test_듀오', 0, NOW() - INTERVAL '116 day'),
  ('test_트로와', 0, NOW() - INTERVAL '117 day'),
  ('test_카토르', 0, NOW() - INTERVAL '118 day'),
  ('test_우페이', 0, NOW() - INTERVAL '119 day'),
  ('test_키라', 0, NOW() - INTERVAL '120 day'),
  
  -- 유유백서
  ('test_유스케', 0, NOW() - INTERVAL '121 day'),
  ('test_쿠라마', 0, NOW() - INTERVAL '122 day'),
  ('test_히에이', 0, NOW() - INTERVAL '123 day'),
  ('test_쿠와바라', 0, NOW() - INTERVAL '124 day'),
  ('test_겐카이', 0, NOW() - INTERVAL '125 day'),
  ('test_토구로', 0, NOW() - INTERVAL '126 day'),
  ('test_센스이', 0, NOW() - INTERVAL '127 day'),
  ('test_유키나', 0, NOW() - INTERVAL '128 day'),
  ('test_보탄', 0, NOW() - INTERVAL '129 day'),
  ('test_엔마대왕', 0, NOW() - INTERVAL '130 day'),
  
  -- 헌터X헌터
  ('test_곤', 0, NOW() - INTERVAL '131 day'),
  ('test_키르아', 0, NOW() - INTERVAL '132 day'),
  ('test_쿠라피카', 0, NOW() - INTERVAL '133 day'),
  ('test_레오리오', 0, NOW() - INTERVAL '134 day'),
  ('test_히소카', 0, NOW() - INTERVAL '135 day'),
  ('test_일루미', 0, NOW() - INTERVAL '136 day'),
  ('test_크로로', 0, NOW() - INTERVAL '137 day'),
  ('test_네테로', 0, NOW() - INTERVAL '138 day'),
  ('test_메루엠', 0, NOW() - INTERVAL '139 day'),
  ('test_네페르피토', 0, NOW() - INTERVAL '140 day'),
  
  -- 원펀맨
  ('test_사이타마', 0, NOW() - INTERVAL '141 day'),
  ('test_제노스', 0, NOW() - INTERVAL '142 day'),
  ('test_킹', 0, NOW() - INTERVAL '143 day'),
  ('test_타츠마키', 0, NOW() - INTERVAL '144 day'),
  ('test_후부키', 0, NOW() - INTERVAL '145 day'),
  ('test_가로우', 0, NOW() - INTERVAL '146 day'),
  ('test_보로스', 0, NOW() - INTERVAL '147 day'),
  ('test_무멘라이더', 0, NOW() - INTERVAL '148 day'),
  ('test_좀비맨', 0, NOW() - INTERVAL '149 day'),
  ('test_메탈나이트', 0, NOW() - INTERVAL '150 day'),
  
  -- 진격의 거인
  ('test_에렌', 0, NOW() - INTERVAL '151 day'),
  ('test_미카사', 0, NOW() - INTERVAL '152 day'),
  ('test_아르민', 0, NOW() - INTERVAL '153 day'),
  ('test_리바이', 0, NOW() - INTERVAL '154 day'),
  ('test_에르빈', 0, NOW() - INTERVAL '155 day'),
  ('test_한지', 0, NOW() - INTERVAL '156 day'),
  ('test_아니', 0, NOW() - INTERVAL '157 day'),
  ('test_라이너', 0, NOW() - INTERVAL '158 day'),
  ('test_베르톨트', 0, NOW() - INTERVAL '159 day'),
  ('test_히스토리아', 0, NOW() - INTERVAL '160 day'),
  
  -- 데스노트
  ('test_라이토', 0, NOW() - INTERVAL '161 day'),
  ('test_엘', 0, NOW() - INTERVAL '162 day'),
  ('test_류크', 0, NOW() - INTERVAL '163 day'),
  ('test_미사', 0, NOW() - INTERVAL '164 day'),
  ('test_니어', 0, NOW() - INTERVAL '165 day'),
  ('test_멜로', 0, NOW() - INTERVAL '166 day'),
  ('test_렘', 0, NOW() - INTERVAL '167 day'),
  ('test_와타리', 0, NOW() - INTERVAL '168 day'),
  ('test_마츠다', 0, NOW() - INTERVAL '169 day'),
  ('test_소이치로', 0, NOW() - INTERVAL '170 day'),
  
  -- 바람의 검심
  ('test_켄신', 0, NOW() - INTERVAL '171 day'),
  ('test_카오루', 0, NOW() - INTERVAL '172 day'),
  ('test_사노스케', 0, NOW() - INTERVAL '173 day'),
  ('test_야히코', 0, NOW() - INTERVAL '174 day'),
  ('test_메구미', 0, NOW() - INTERVAL '175 day'),
  ('test_사이토', 0, NOW() - INTERVAL '176 day'),
  ('test_시시오', 0, NOW() - INTERVAL '177 day'),
  ('test_아오시', 0, NOW() - INTERVAL '178 day'),
  ('test_유미', 0, NOW() - INTERVAL '179 day'),
  ('test_소지로', 0, NOW() - INTERVAL '180 day'),
  
  -- 베르세르크
  ('test_가츠', 0, NOW() - INTERVAL '181 day'),
  ('test_그리피스', 0, NOW() - INTERVAL '182 day'),
  ('test_캐스카', 0, NOW() - INTERVAL '183 day'),
  ('test_유다', 0, NOW() - INTERVAL '184 day'),
  ('test_피핀', 0, NOW() - INTERVAL '185 day'),
  ('test_슈케', 0, NOW() - INTERVAL '186 day'),
  ('test_리케르트', 0, NOW() - INTERVAL '187 day'),
  ('test_파크', 0, NOW() - INTERVAL '188 day'),
  ('test_이시도로', 0, NOW() - INTERVAL '189 day'),
  ('test_파르네제', 0, NOW() - INTERVAL '190 day'),
  
  -- 기타 유명 캐릭터들
  ('test_아톰', 0, NOW() - INTERVAL '191 day'),
  ('test_마징가Z', 0, NOW() - INTERVAL '192 day'),
  ('test_캡틴하록', 0, NOW() - INTERVAL '193 day'),
  ('test_은하철도999', 0, NOW() - INTERVAL '194 day'),
  ('test_메텔', 0, NOW() - INTERVAL '195 day'),
  ('test_철이', 0, NOW() - INTERVAL '196 day'),
  ('test_날아라슈퍼보드', 0, NOW() - INTERVAL '197 day'),
  ('test_마루코', 0, NOW() - INTERVAL '198 day'),
  ('test_케로로', 0, NOW() - INTERVAL '199 day'),
  ('test_큐라상', 0, NOW() - INTERVAL '200 day')
ON CONFLICT DO NOTHING;
