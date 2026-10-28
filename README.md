# practice-db

SQL 練習やパフォーマンス確認等をするためのローカルDB環境です。
MySQL と PostgreSQL を切り替えて使え、どちらにも同じ構成のECテーブルを用意しています。

## 必要なもの

- Docker / Docker Compose v2
- GNU Make

DBクライアントはコンテナ内のものを使うので、ホストにインストールする必要はありません。

## 使い方

```sh
make up DB=mysql       # MySQL を起動（初回はDDLとマスタを自動で投入）
make up DB=postgres    # PostgreSQL を起動（両方同時に起動してもよい）

make mysql             # MySQL に接続
make psql              # PostgreSQL に接続

make seed DB=mysql ROWS=1000000   # 大量データを生成（ROWS = 注文数）

make reset DB=mysql    # 指定したDBのデータを消して初期状態に戻す
make down              # 停止（データは残る）

make check             # 両DBで「起動 → テーブル・マスタの確認 → 少量seed → 両DBのデータ一致の確認」を行う
make                   # コマンド一覧を表示
```

- `.env` が無い場合は、`make up` などの実行時に `.env.example` からコピーして作られます。認証情報とポートは `.env` で変更してください（`.env` はコミットしません）。
- ポートの既定値は MySQL が 3306、PostgreSQL が 5432 です。GUIクライアントなどからは `localhost` に、`.env` の `DB_NAME` / `DB_USER` / `DB_PASSWORD` で接続します。
- `make check` は別のプロジェクト（`practice-db-check`）、別ボリューム、空いているポートで起動し、終わったら片付けます。普段使っている環境のデータには触れません。
- 初期化SQLは、ボリュームが空のときの最初の起動でだけ実行されます。DDLやマスタを変更したら `make reset DB=...` で反映してください。

## テーブル構成

```
categories ─┐ (parent_id で自己参照・2階層)
   │1       │
   │N  ◄────┘
products                 customers
   │1                       │1
   │N                       │N
order_items  N ────── 1  orders
```

| テーブル | 主なカラム | 備考 |
|---|---|---|
| categories | id, parent_id, name, sort_order | 親5件・子15件のマスタ |
| customers | id, name, email, prefecture | email は大文字小文字を区別せず一意 |
| products | id, category_id, name, price | 金額は円の整数 |
| orders | id, customer_id, status, ordered_at | status は CHECK 制約で値を限定 |
| order_items | id, order_id, product_id, quantity, unit_price | unit_price は注文時点の単価。(order_id, product_id) で一意 |

全テーブルに `created_at` / `updated_at` があり、`updated_at` は UPDATE のたびに自動で更新されます。

起動直後に入っているのは categories のマスタだけで、それ以外のテーブルは空です。`make seed` で大量データを生成します。

### 注文ステータス

マスタ用のテーブルは作らず、`orders.status` の CHECK 制約（`ck_orders_status`）で値を限定しています。

| 値 | 意味 |
|---|---|
| pending | 注文受付（既定値） |
| paid | 支払い済み |
| shipped | 発送済み |
| delivered | 配達完了 |
| cancelled | キャンセル |

## 大量データ（make seed）

```sh
make seed DB=mysql ROWS=1000000            # 注文100万件
make seed DB=postgres ROWS=1000000 SEED=7  # シードを変えると別のデータになる
```

- 実行するたびに customers / products / orders / order_items を空にしてから作り直します（categories はそのまま）。
- **同じ `ROWS` と `SEED` なら、何度実行しても、MySQL と PostgreSQL のどちらでも1行単位で同じデータになります。** 乱数関数は DB ごとに結果が違うので使っておらず、行番号からの整数演算（ハッシュ）で値を決めています。`make check` で両DBの一致を確認しています。
- 生成後に統計情報を更新します（MySQL は `ANALYZE TABLE`、PostgreSQL は `VACUUM (ANALYZE)`）。
- `ROWS` は 100〜50000000 の範囲で指定できます（既定値は 100000、`SEED` の既定値は 42）。

### 件数

| テーブル | 件数 |
|---|---|
| orders | `ROWS` |
| customers | `ROWS / 10` |
| products | `ROWS / 100`（最低100件） |
| order_items | 1注文あたり1〜5件。平均 約2.38件 |

order_items.id は `(order_id - 1) * 5 + 明細番号` なので欠番があります。

### 分布

インデックスの効き方を試せるように、列ごとに偏りを付けています。

| 列 | 分布 |
|---|---|
| customers.prefecture | 東京都 約21% / 大阪府 約11% / 神奈川県 約9% など都市部に偏る。残り約4割は47都道府県に均等 |
| customers.email | `user00000123@example.com` 形式。約1割は `User00000123@Example.com` のように大文字が混じる |
| customers.created_at | 2023年の1年間に id 順で並ぶ |
| products.category_id | 子カテゴリ（id 6〜20）に均等 |
| products.price | 100〜99,900円（10円単位）。安い商品ほど多い |
| orders.customer_id | id の小さい顧客ほど注文が多い（ヘビーユーザーがいる） |
| orders.status | delivered 75% / shipped 10% / paid 8% / cancelled 5% / pending 2% |
| orders.ordered_at | 2024-01-01〜2025-12-31 に id 順で並ぶ（id と日時が相関する） |
| orders.updated_at | 注文から0〜7日後 |
| order_items.product_id | id の小さい商品ほど売れる（人気商品）。同じ注文の中では重複しない |
| order_items.quantity | 1個 70% / 2個 20% / 3個 7% / 4個 2% / 5個 1% |
| order_items.unit_price | その商品の price |

### 所要時間とディスク使用量の目安

手元の環境（WSL2、メモリ7GB）で測った値です。ディスク使用量はデータディレクトリ全体（PostgreSQL は WAL の約1GBを含む）です。

| ROWS | order_items | MySQL 時間 | PostgreSQL 時間 | MySQL ディスク | PostgreSQL ディスク |
|---|---|---|---|---|---|
| 1,000,000 | 約238万 | 63秒 | 42秒 | 0.8GB | 1.5GB |
| 5,000,000 | 約1,190万 | 約9.5分 | 約3.3分 | 2.6GB | 3.3GB |
| 50,000,000（上限・推定） | 約1.2億 | 数時間 | 30分〜1時間 | 約22GB | 約23GB |

上限の行は実測していない推定値です。データ量は 100万件あたり約0.44GB で、件数にほぼ比例します。

MySQL はキャッシュがバッファプール（既定128MB）だけなので、インデックスがメモリに乗らなくなると件数に比例する以上に遅くなります。PostgreSQL は OS のページキャッシュも使います。少しでも速くするため、my.cnf で `innodb_change_buffering = all`（8.4 で既定値が none になった）と `innodb_redo_log_capacity = 2G` を設定しています。どちらも書き込み性能に関わる設定なので、更新系の性能を測るときは考慮してください。

## ファイル構成

```
compose.yaml              profiles で mysql / postgres を切り替え
Makefile                  操作の入口
db/mysql/01_schema.sql    MySQL用DDL
db/mysql/03_post_master.sql
db/mysql/conf.d/my.cnf    文字コード・タイムゾーンの設定
db/postgres/01_schema.sql PostgreSQL用DDL
db/postgres/03_post_master.sql
db/master/02_master.sql   マスタデータ（両DB共通）
db/mysql/seed/            MySQL用の生成SQL（01_prepare〜06_finish）
db/postgres/seed/         PostgreSQL用の生成SQL（生成式は MySQL 版と揃えている）
scripts/seed.sh           make seed の実体
scripts/fingerprint.sh    生成データの指紋（件数・列の合計）を出力する。両DBの一致確認に使う
scripts/check.sh          make check の実体
```

初期化SQLはファイル名の順に実行されます（`01_schema` → `02_master` → `03_post_master`）。

## MySQL と PostgreSQL の違い（このリポジトリでの扱い）

テーブルとカラムの構成は両DBで揃えています。方言の差は次のように吸収しています。

| 項目 | MySQL | PostgreSQL |
|---|---|---|
| バージョン | 8.4.13 | 17.11 |
| 連番 | `AUTO_INCREMENT` | `GENERATED BY DEFAULT AS IDENTITY`。マスタはIDを明示して入れるので、`03_post_master.sql` で `setval` してシーケンスを合わせる |
| FK列のインデックス | FKを張ると自動で作られる | 自動では作られない。**条件を揃えるため、両DBとも名前付きで明示的に作成している**（`idx_*`） |
| `updated_at` の自動更新 | `ON UPDATE CURRENT_TIMESTAMP(6)` | トリガー（`set_updated_at()`）。MySQLは値が実際に変わったときだけ更新するが、PGはUPDATE文が実行されるたびに更新する |
| 日時型 | `DATETIME(6)` | `timestamp(6)`（タイムゾーンなし） |
| タイムゾーン | `+09:00` | `Asia/Tokyo` |
| email の一意制約 | 照合順序 `utf8mb4_0900_ai_ci` のため大文字小文字を区別しない | `lower(email)` の式インデックス。**インデックスを使うには `WHERE lower(email) = ...` と書く必要がある** |
| 文字列の比較 | 既定で大文字小文字を区別しない | 区別する |
| 主キーとデータの格納 | InnoDB は主キーの順にデータを並べる（クラスタ化インデックス） | 主キーと関係なくヒープに格納する |
| 統計情報の更新 | `ANALYZE TABLE t;` | `ANALYZE t;`（seed では `VACUUM (ANALYZE)` で可視性マップも作る） |
| 連番の生成（seed） | `generate_series` が無いため、再帰CTEで作った一時テーブルを使う | `generate_series` |
| 整数の除算（seed） | `/` の結果は小数になるため `FLOOR(a / b)` | bigint 同士の `/` は切り捨て |
| 投入中のFKチェック停止（seed） | `SET foreign_key_checks = 0` | `SET session_replication_role = replica`（トリガーも止まる） |
| バイナリログ / WAL | 練習用のため `disable-log-bin` で無効化 | WAL は無効化できない（`pg_wal` に最大1GB程度） |
