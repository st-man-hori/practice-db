#!/usr/bin/env bash
# 両DBを別プロジェクト（別ボリューム・ランダムポート）で新規に起動し、
# DDLとマスタの適用、少量seed、両DBのデータ一致を確認して後片付けする。
# 普段使いの環境（project: practice-db）には影響しない。
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=practice-db-check
# ホストポート 0 = 空きポートを自動割り当て（普段のDBが起動中でも衝突しない）
export MYSQL_PORT=0 POSTGRES_PORT=0
COMPOSE=(docker compose -p "$PROJECT" --profile mysql --profile postgres)

cleanup() { "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

cleanup
echo "==> 起動中（初期化完了まで待機）"
"${COMPOSE[@]}" up -d --wait

# 標準入力のSQLを実行し、結果を区切りなしで返す
q_mysql() {
  "${COMPOSE[@]}" exec -T mysql sh -c \
    'MYSQL_PWD="$MYSQL_PASSWORD" mysql -N -B -u"$MYSQL_USER" "$MYSQL_DATABASE"'
}
q_postgres() {
  "${COMPOSE[@]}" exec -T postgres sh -c \
    'psql -X -A -t -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
}

failed=0

expect() { # db, 説明, 期待値, SQL
  local db=$1 label=$2 want=$3 sql=$4 got
  got=$(echo "$sql" | "q_$db" | tr -d '[:space:]')
  if [[ "$got" == "$want" ]]; then
    printf '  ok  %-6s %s\n' "$got" "$label"
  else
    printf '  NG  got=%s want=%s  %s\n' "$got" "$want" "$label"
    failed=1
  fi
}

for db in mysql postgres; do
  if [[ $db == mysql ]]; then schema='DATABASE()'; else schema="'public'"; fi
  echo "==> $db"
  expect "$db" "テーブル数" 5 "
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = $schema
      AND table_name IN ('customers', 'products', 'categories', 'orders', 'order_items');"
  expect "$db" "categories 件数" 20 "SELECT COUNT(*) FROM categories;"
  expect "$db" "親カテゴリ件数" 5 "SELECT COUNT(*) FROM categories WHERE parent_id IS NULL;"
  expect "$db" "子カテゴリ（親あり）件数" 15 "
    SELECT COUNT(*) FROM categories c JOIN categories p ON p.id = c.parent_id
    WHERE p.parent_id IS NULL;"
  expect "$db" "注文ステータスCHECK制約" 1 "
    SELECT COUNT(*) FROM information_schema.check_constraints
    WHERE constraint_name = 'ck_orders_status';"
  expect "$db" "トランザクション系は空" 0 "
    SELECT (SELECT COUNT(*) FROM customers) + (SELECT COUNT(*) FROM products)
         + (SELECT COUNT(*) FROM orders)    + (SELECT COUNT(*) FROM order_items);"
done

SEED_ROWS=1000
fp_dir=$(mktemp -d)
trap 'rm -rf "$fp_dir"; cleanup' EXIT

for db in mysql postgres; do
  echo "==> $db: seed ROWS=$SEED_ROWS"
  PROJECT=$PROJECT ./scripts/seed.sh "$db" "$SEED_ROWS" >/dev/null
  expect "$db" "orders 件数" "$SEED_ROWS" "SELECT COUNT(*) FROM orders;"
  expect "$db" "customers 件数" $(( SEED_ROWS / 10 )) "SELECT COUNT(*) FROM customers;"
  expect "$db" "products 件数" 100 "SELECT COUNT(*) FROM products;"
  # seed 中は FK チェックを止めているため、参照先が存在することをここで確かめる
  expect "$db" "参照先の無い行" 0 "
    SELECT (SELECT COUNT(*) FROM orders o LEFT JOIN customers c ON c.id = o.customer_id WHERE c.id IS NULL)
         + (SELECT COUNT(*) FROM order_items i LEFT JOIN orders o ON o.id = i.order_id WHERE o.id IS NULL)
         + (SELECT COUNT(*) FROM order_items i LEFT JOIN products p ON p.id = i.product_id WHERE p.id IS NULL)
         + (SELECT COUNT(*) FROM products p LEFT JOIN categories c ON c.id = p.category_id WHERE c.id IS NULL);"
  PROJECT=$PROJECT ./scripts/fingerprint.sh "$db" > "$fp_dir/$db.1"
done

echo "==> 再現性"
PROJECT=$PROJECT ./scripts/seed.sh mysql "$SEED_ROWS" >/dev/null
PROJECT=$PROJECT ./scripts/fingerprint.sh mysql > "$fp_dir/mysql.2"
compare() { # 説明, ファイル1, ファイル2
  if diff -u "$2" "$3"; then
    printf '  ok  %-6s %s\n' same "$1"
  else
    printf '  NG  %s\n' "$1"
    failed=1
  fi
}
compare "MySQL と PostgreSQL のデータが一致" "$fp_dir/mysql.1" "$fp_dir/postgres.1"
compare "seed を再実行しても同じデータ" "$fp_dir/mysql.1" "$fp_dir/mysql.2"

if [[ $failed -ne 0 ]]; then
  echo "check: NG" >&2
  exit 1
fi
echo "check: OK"
