#!/usr/bin/env bash
# 大量データを生成する（トランザクション系4テーブルを空にしてから作り直す）。
# 使い方: scripts/seed.sh mysql|postgres ROWS [SEED]
#   ROWS = 注文数。customers = ROWS/10、products = max(ROWS/100, 100)、order_items = 平均 2.38/注文
#   同じ ROWS と SEED なら、何度実行しても・どちらのDBでも同じデータになる。
set -euo pipefail

cd "$(dirname "$0")/.."

DB=${1:?DB を指定してください (mysql|postgres)}
ROWS=${2:?ROWS を指定してください}
SEED=${3:-42}
PROJECT=${PROJECT:-practice-db}

MIN_ROWS=100
# データ量が1DBあたり約20〜25GBに収まる上限。目安は README を参照
MAX_ROWS=50000000
# 1回の INSERT で扱う件数（大きすぎると undo/WAL が膨らむ）
CHUNK=1000000

case "$DB" in mysql|postgres) ;; *) echo "DB は mysql か postgres を指定してください" >&2; exit 1;; esac
for v in ROWS SEED; do
  [[ ${!v} =~ ^[0-9]+$ ]] || { echo "$v は0以上の整数で指定してください: ${!v}" >&2; exit 1; }
done
if (( ROWS < MIN_ROWS || ROWS > MAX_ROWS )); then
  echo "ROWS は $MIN_ROWS 〜 $MAX_ROWS の範囲で指定してください: $ROWS" >&2
  exit 1
fi

CUSTOMERS=$(( ROWS / 10 ))
PRODUCTS=$(( ROWS / 100 > 100 ? ROWS / 100 : 100 ))
DIR=db/$DB/seed

# 変数の設定文を出力する（MySQL はユーザー変数、PostgreSQL は psql 変数）
set_vars() {
  local name
  for name in "$@"; do
    if [[ $DB == mysql ]]; then
      echo "SET @$name = ${!name};"
    else
      echo "\\set $name ${!name}"
    fi
  done
}

# 1〜total を CHUNK 件ずつに区切り、チャンク用SQLを範囲を変えて繰り返し出力する
emit_chunks() {
  local file=$1 total=$2 lo hi
  for (( lo = 1; lo <= total; lo += CHUNK )); do
    hi=$(( lo + CHUNK - 1 < total ? lo + CHUNK - 1 : total ))
    set_vars lo hi
    cat "$DIR/$file"
  done
}

# seed.sql 全体を1セッション分の SQL として組み立てる（一時テーブルをセッション内で使うため）
build_sql() {
  local seed=$SEED rows=$ROWS customers=$CUSTOMERS products=$PRODUCTS
  set_vars seed rows customers products
  cat "$DIR/01_prepare.sql"
  emit_chunks 02_customers.sql "$CUSTOMERS"
  emit_chunks 03_products.sql "$PRODUCTS"
  emit_chunks 04_orders.sql "$ROWS"
  emit_chunks 05_order_items.sql "$ROWS"
  cat "$DIR/06_finish.sql"
}

run_sql() {
  if [[ $DB == mysql ]]; then
    docker compose -p "$PROJECT" --profile mysql exec -T mysql sh -c \
      'MYSQL_PWD="$MYSQL_PASSWORD" mysql -N -B -u"$MYSQL_USER" "$MYSQL_DATABASE"'
  else
    docker compose -p "$PROJECT" --profile postgres exec -T postgres sh -c \
      'psql -X -q -A -t -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
  fi
}

echo "==> seed $DB: orders=$ROWS customers=$CUSTOMERS products=$PRODUCTS seed=$SEED"
start=$SECONDS
build_sql | run_sql | grep -v -E '^[^ ]+\.[a-z_]+\s+analyze\s+status\s+OK$'

if [[ $DB == mysql ]]; then
  size_sql="SELECT CONCAT(ROUND(SUM(data_length + index_length) / 1024 / 1024), ' MB')
            FROM information_schema.tables WHERE table_schema = DATABASE();"
else
  size_sql="SELECT pg_size_pretty(pg_database_size(current_database()));"
fi
echo "==> 完了: $(( SECONDS - start ))秒 / DBサイズ $(echo "$size_sql" | run_sql)"
