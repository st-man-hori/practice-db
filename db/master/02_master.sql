-- マスタデータ（MySQL / PostgreSQL 共通）
-- 両DBで通る標準的な INSERT のみで書くこと。
--
-- 注文ステータスはテーブルではなく orders.status の CHECK 制約で管理している
-- （pending / paid / shipped / delivered / cancelled）。各DBの 01_schema.sql を参照。

-- 親カテゴリ (id 1-5)
INSERT INTO categories (id, parent_id, name, sort_order) VALUES
  (1, NULL, '家電',         1),
  (2, NULL, 'ファッション', 2),
  (3, NULL, '食品',         3),
  (4, NULL, '書籍',         4),
  (5, NULL, 'スポーツ',     5);

-- 子カテゴリ (id 6-20)
INSERT INTO categories (id, parent_id, name, sort_order) VALUES
  ( 6, 1, 'テレビ',         1),
  ( 7, 1, '冷蔵庫',         2),
  ( 8, 1, 'パソコン',       3),
  ( 9, 2, 'メンズ',         1),
  (10, 2, 'レディース',     2),
  (11, 2, 'キッズ',         3),
  (12, 3, '飲料',           1),
  (13, 3, 'お菓子',         2),
  (14, 3, '調味料',         3),
  (15, 4, '小説',           1),
  (16, 4, 'ビジネス書',     2),
  (17, 4, 'コミック',       3),
  (18, 5, 'アウトドア',     1),
  (19, 5, 'フィットネス',   2),
  (20, 5, 'ゴルフ',         3);
