-- seed の後処理（PostgreSQL）

SET session_replication_role = origin;

-- IDENTITY のシーケンスは明示ID挿入では進まないため、最大値に合わせる
\o /dev/null
SELECT setval(pg_get_serial_sequence('customers', 'id'), :customers);
SELECT setval(pg_get_serial_sequence('products', 'id'), :products);
SELECT setval(pg_get_serial_sequence('orders', 'id'), :rows);
SELECT setval(pg_get_serial_sequence('order_items', 'id'), (SELECT MAX(id) FROM order_items));
\o

-- 統計情報を更新する。VACUUM も行い、Index Only Scan に必要な可視性マップを作っておく
\echo analyze
VACUUM (ANALYZE) customers, products, orders, order_items;
