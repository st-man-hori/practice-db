-- マスタ投入後の後処理（PostgreSQL）
-- IDENTITY 列に明示的にIDを入れても内部シーケンスは進まないため、最大値に合わせる。
-- これをしないと次の INSERT で主キー重複になる（MySQL の AUTO_INCREMENT との差）。

SELECT setval(pg_get_serial_sequence('categories', 'id'), (SELECT MAX(id) FROM categories));

ANALYZE;
