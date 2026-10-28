-- orders を id @lo〜@hi の範囲で生成する（MySQL）
-- 生成式は db/postgres/seed/04_orders.sql と揃えること。

SELECT CONCAT('orders ', @lo, '-', @hi);

INSERT INTO orders (id, customer_id, status, ordered_at, created_at, updated_at)
SELECT
  x.n, x.customer_id, x.status, x.ordered_at, x.ordered_at,
  x.ordered_at + INTERVAL x.update_lag SECOND
FROM (
  SELECT
    h.n,
    -- r の2乗で id の小さい顧客ほど注文が多くなる（ヘビーユーザー）
    1 + FLOOR(MOD(MOD(h.t1 * h.t1, 1000000007), @customers) * MOD(MOD(h.t1 * h.t1, 1000000007), @customers) / @customers) AS customer_id,
    CASE
      WHEN MOD(MOD(h.t2 * h.t2, 1000000007), 100) < 75 THEN 'delivered'
      WHEN MOD(MOD(h.t2 * h.t2, 1000000007), 100) < 85 THEN 'shipped'
      WHEN MOD(MOD(h.t2 * h.t2, 1000000007), 100) < 93 THEN 'paid'
      WHEN MOD(MOD(h.t2 * h.t2, 1000000007), 100) < 98 THEN 'cancelled'
      ELSE 'pending'
    END AS status,
    -- 2024-01-01〜2025-12-31 の2年間に id 順で並ぶ（id と日時が相関する実データに近い形）
    TIMESTAMP '2024-01-01 00:00:00' + INTERVAL FLOOR((h.n - 1) * 63158400 / @rows) SECOND AS ordered_at,
    -- 最終更新は注文から0〜7日後
    MOD(MOD(h.t3 * h.t3, 1000000007), 604800) AS update_lag
  FROM (
    SELECT
      s.i + @lo AS n,
      MOD((s.i + @lo) * 374761393 + @seed, 1000000007) AS t1,
      MOD((s.i + @lo) * 2870177453 + @seed, 1000000007) AS t2,
      MOD((s.i + @lo) * 1597334677 + @seed, 1000000007) AS t3
    FROM seq s
    WHERE s.i <= @hi - @lo
  ) h
) x
ORDER BY x.n;
