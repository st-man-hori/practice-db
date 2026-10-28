# AGENTS.md

## 目的
MySQL / PostgreSQL をローカルで切り替えて使える、SQL練習やパフォーマンス確認用のリポジトリ。
学習用途であり、本番運用は想定しない。

## 構成
- compose.yaml        : profiles で mysql / postgres を切り替え
- db/mysql/           : MySQL用DDL・生成SQL
- db/postgres/        : PostgreSQL用DDL・生成SQL
- db/master/          : マスタデータ（CSV/SQL、両DB共通）
- Makefile            : 操作の入口

## コマンド（必ずこれを使う。docker composeを直接叩かない）
- make up DB=mysql|postgres   : 起動
- make down                   : 停止
- make reset DB=...           : ボリューム削除して再作成
- make seed DB=... ROWS=100000 : 大量データを生成（件数指定。トランザクション系テーブルは作り直す）
- make psql / make mysql      : クライアント接続
- make check                  : 両DBで起動→DDL適用→少量seed→件数確認

## ルール
- テーブル/カラム構成は両DBで揃える。片方だけ変更しない
- スキーマを変えたら両DBのDDLと、関連するseedも更新する
- seedは乱数シード固定。同条件で同じデータになること
- seed後に統計情報更新（ANALYZE）まで行う
- イメージのバージョンは固定し、latestを使わない
- 認証情報は.envで管理し、.env.exampleを用意。.envはコミットしない
- ポートはMySQL 3306 / PostgreSQL 5432 を既定とし、.envで変更可能にする

## 変更時の確認
- make check が両DBで通ること
- 変更内容をREADMEの該当箇所にも反映すること

## やらないこと
- 依頼されていないテーブル追加・既存カラム名の変更
- ORMやアプリケーションコードの追加（SQL練習が目的のため）