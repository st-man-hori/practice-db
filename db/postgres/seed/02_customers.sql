-- customers を id :lo〜:hi の範囲で生成する（PostgreSQL）
--
-- 擬似乱数: 乱数関数は DB ごとに結果が違うため使わず、整数演算のハッシュで作る。
--   t = MOD(n * 乗数 + :seed, 1000000007)、h = MOD(t * t, 1000000007)
-- 生成式は db/mysql/seed/ と揃えること（両DBで1行単位で同じデータになる）。
-- bigint 同士の / は切り捨てになるため、MySQL 側の FLOOR(a / b) と同じ値になる。

\echo customers :lo - :hi

INSERT INTO customers (id, name, email, prefecture, created_at, updated_at)
SELECT x.n, x.name, x.email, p.name, x.created_at, x.created_at
FROM (
  SELECT
    h.n,
    CONCAT('顧客', h.n) AS name,
    -- 1割は大文字混じり（大文字小文字を区別しない一意制約の練習用）
    CASE WHEN MOD(MOD(h.t2 * h.t2, 1000000007), 10) = 0
         THEN CONCAT('User', LPAD(h.n::text, 8, '0'), '@Example.com')
         ELSE CONCAT('user', LPAD(h.n::text, 8, '0'), '@example.com')
    END AS email,
    -- 都市部に偏らせる。残り4割は47都道府県に均等
    CASE
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 20 THEN 13  -- 東京都
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 30 THEN 27  -- 大阪府
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 38 THEN 14  -- 神奈川県
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 44 THEN 23  -- 愛知県
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 49 THEN 11  -- 埼玉県
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 53 THEN 12  -- 千葉県
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 57 THEN 40  -- 福岡県
      WHEN MOD(MOD(h.t1 * h.t1, 1000000007), 100) < 60 THEN 1   -- 北海道
      ELSE 1 + MOD(MOD(h.t2 * h.t2, 1000000007), 47)
    END AS pref_id,
    -- 2023年の1年間に id 順で登録
    TIMESTAMP '2023-01-01 00:00:00' + ((h.n - 1) * 31536000 / :customers) * INTERVAL '1 second' AS created_at
  FROM (
    SELECT
      g.n,
      MOD(g.n * 2654435761 + :seed, 1000000007) AS t1,
      MOD(g.n * 2246822519 + :seed, 1000000007) AS t2
    FROM generate_series(:lo::bigint, :hi::bigint) AS g (n)
  ) h
) x
JOIN prefectures p ON p.id = x.pref_id
ORDER BY x.n;
