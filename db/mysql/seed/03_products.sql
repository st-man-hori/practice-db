-- products を id @lo〜@hi の範囲で生成する（MySQL）
-- 生成式は db/postgres/seed/03_products.sql と揃えること。

SELECT CONCAT('products ', @lo, '-', @hi);

INSERT INTO products (id, category_id, name, price, created_at, updated_at)
SELECT
  h.n,
  -- 子カテゴリ (id 6〜20) に均等
  6 + MOD(MOD(h.t1 * h.t1, 1000000007), 15),
  CONCAT('商品', LPAD(h.n, 7, '0')),
  -- 100〜99,900円（10円単位）。r の2乗で安い商品ほど多くなる
  100 + 10 * FLOOR(MOD(MOD(h.t2 * h.t2, 1000000007), 1000) * MOD(MOD(h.t2 * h.t2, 1000000007), 1000) * 9990 / 1000000),
  TIMESTAMP '2023-01-01 00:00:00' + INTERVAL FLOOR((h.n - 1) * 31536000 / @products) SECOND,
  TIMESTAMP '2023-01-01 00:00:00' + INTERVAL FLOOR((h.n - 1) * 31536000 / @products) SECOND
FROM (
  SELECT
    s.i + @lo AS n,
    MOD((s.i + @lo) * 3266489917 + @seed, 1000000007) AS t1,
    MOD((s.i + @lo) * 668265263 + @seed, 1000000007) AS t2
  FROM seq s
  WHERE s.i <= @hi - @lo
) h
ORDER BY h.n;
