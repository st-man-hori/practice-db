-- 注文 id :lo〜:hi の order_items を生成する（PostgreSQL）
-- 生成式は db/mysql/seed/05_order_items.sql と揃えること。
--
-- id は (order_id - 1) * 5 + 明細番号 とする（1注文最大5明細）。
-- 明細数が5未満の注文の分だけ id は欠番になる。

\echo order_items (orders :lo - :hi)

INSERT INTO order_items (id, order_id, product_id, quantity, unit_price, created_at, updated_at)
SELECT
  y.id, y.order_id, y.product_id,
  CASE
    WHEN MOD(MOD(y.t6 * y.t6, 1000000007), 100) < 70 THEN 1
    WHEN MOD(MOD(y.t6 * y.t6, 1000000007), 100) < 90 THEN 2
    WHEN MOD(MOD(y.t6 * y.t6, 1000000007), 100) < 97 THEN 3
    WHEN MOD(MOD(y.t6 * y.t6, 1000000007), 100) < 99 THEN 4
    ELSE 5
  END,
  -- 注文時点の単価として商品価格をそのまま使う
  p.price,
  y.ordered_at, y.ordered_at
FROM (
  SELECT
    (h.order_id - 1) * 5 + ks.k AS id,
    h.order_id,
    -- 1件目は r の2乗で id の小さい商品ほど売れる（人気商品）。2件目以降は23ずつずらして注文内で重複させない
    1 + MOD(MOD(MOD(h.t5 * h.t5, 1000000007), :products) * MOD(MOD(h.t5 * h.t5, 1000000007), :products) / :products + (ks.k - 1) * 23, :products) AS product_id,
    h.ordered_at,
    MOD((h.order_id * 8 + ks.k) * 2166136261 + :seed, 1000000007) AS t6
  FROM (
    SELECT
      o.id AS order_id,
      o.ordered_at,
      MOD(o.id * 3735928559 + :seed, 1000000007) AS t4,
      MOD(o.id * 1103515245 + :seed, 1000000007) AS t5
    FROM orders o
    WHERE o.id BETWEEN :lo AND :hi
  ) h
  -- 明細数: 1件 30% / 2件 30% / 3件 20% / 4件 12% / 5件 8%（平均 2.38件）
  JOIN (SELECT 1 AS k UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) ks
    ON ks.k <= CASE
                 WHEN MOD(MOD(h.t4 * h.t4, 1000000007), 100) < 30 THEN 1
                 WHEN MOD(MOD(h.t4 * h.t4, 1000000007), 100) < 60 THEN 2
                 WHEN MOD(MOD(h.t4 * h.t4, 1000000007), 100) < 80 THEN 3
                 WHEN MOD(MOD(h.t4 * h.t4, 1000000007), 100) < 92 THEN 4
                 ELSE 5
               END
) y
JOIN products p ON p.id = y.product_id
ORDER BY y.id;
