-- seed の後処理（MySQL）

SET SESSION foreign_key_checks = 1;

-- 統計情報を更新する（AUTO_INCREMENT は明示ID挿入後も自動で追従する）
SELECT 'analyze';
ANALYZE TABLE customers, products, orders, order_items;
