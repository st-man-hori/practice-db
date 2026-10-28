#!/usr/bin/env bash
# 生成データの指紋（各テーブルの件数・列の合計など）を出力する。
# 両DBで同じ出力になれば、同じデータが入っているとみなせる。
# 使い方: scripts/fingerprint.sh mysql|postgres  （PROJECT で compose project を指定可能）
set -euo pipefail

cd "$(dirname "$0")/.."

DB=${1:?DB を指定してください (mysql|postgres)}
PROJECT=${PROJECT:-practice-db}

# 両DBで同じ結果になる書き方にする:
#  - 日時は基準日時からの秒数にする
#  - 大文字の判定は ASCII() で行う（MySQL の = や LIKE は大文字小文字を区別しないため）
#  - 先頭のラベル列は数値で ORDER BY する（MySQL ではラベルの別名と列名が衝突するため）
if [[ $DB == mysql ]]; then
  secs() { echo "TIMESTAMPDIFF(SECOND, TIMESTAMP '2023-01-01 00:00:00', $1)"; }
else
  secs() { echo "EXTRACT(EPOCH FROM ($1 - TIMESTAMP '2023-01-01 00:00:00'))::bigint"; }
fi

sql="
SELECT 'customers', COUNT(*), SUM(id), SUM(CHAR_LENGTH(name)), SUM(CHAR_LENGTH(email)),
       SUM(CASE WHEN ASCII(email) = 85 THEN 1 ELSE 0 END), SUM(CHAR_LENGTH(prefecture)),
       SUM($(secs created_at)), SUM($(secs updated_at))
FROM customers;
SELECT 'prefecture', COUNT(*), MIN(id), MAX(id) FROM customers GROUP BY prefecture ORDER BY 2 DESC, 3;
SELECT 'products', COUNT(*), SUM(category_id), SUM(price), SUM(CHAR_LENGTH(name)),
       SUM($(secs created_at)), SUM($(secs updated_at))
FROM products;
SELECT 'orders', COUNT(*), SUM(customer_id), SUM($(secs ordered_at)),
       SUM($(secs created_at)), SUM($(secs updated_at))
FROM orders;
SELECT 'status', status, COUNT(*), SUM(id) FROM orders GROUP BY status ORDER BY 2;
SELECT 'order_items', COUNT(*), SUM(id), SUM(order_id), SUM(product_id), SUM(quantity),
       SUM(unit_price * quantity), SUM($(secs created_at)), SUM($(secs updated_at))
FROM order_items;
"

if [[ $DB == mysql ]]; then
  echo "$sql" | docker compose -p "$PROJECT" --profile mysql exec -T mysql sh -c \
    'MYSQL_PWD="$MYSQL_PASSWORD" mysql -N -B -u"$MYSQL_USER" "$MYSQL_DATABASE"'
else
  echo "$sql" | docker compose -p "$PROJECT" --profile postgres exec -T postgres sh -c \
    'psql -X -q -A -t -F "	" -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
fi
