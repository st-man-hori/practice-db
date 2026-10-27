-- マスタ投入後の後処理（MySQL）
-- AUTO_INCREMENT は明示ID挿入後も自動で追従するため、統計情報の更新のみ行う。

ANALYZE TABLE categories, customers, products, orders, order_items;
