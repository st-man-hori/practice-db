-- seed の準備（MySQL）
-- scripts/seed.sh が 01〜06 を1セッションで順に流す。
-- 変数: @seed, @rows(注文数), @customers, @products, チャンクごとに @lo / @hi

-- 生成データは整合が取れるように作っているため、投入中は FK チェックを止めて高速化する。
-- 参照整合性は make check で確認する。
SET SESSION foreign_key_checks = 0;

TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE customers;

-- 連番 0〜999999（1チャンク分）。MySQL には generate_series が無いため再帰CTEで作る
SET SESSION cte_max_recursion_depth = 1000000;
CREATE TEMPORARY TABLE seq (i INT NOT NULL PRIMARY KEY);
INSERT INTO seq (i)
WITH RECURSIVE s (i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM s WHERE i < 999999)
SELECT i FROM s;

-- 都道府県（JISコード順）。db/postgres/seed/01_prepare.sql と揃えること
CREATE TEMPORARY TABLE prefectures (id INT NOT NULL PRIMARY KEY, name VARCHAR(10) NOT NULL);
INSERT INTO prefectures (id, name) VALUES
  (1,'北海道'),(2,'青森県'),(3,'岩手県'),(4,'宮城県'),(5,'秋田県'),(6,'山形県'),(7,'福島県'),
  (8,'茨城県'),(9,'栃木県'),(10,'群馬県'),(11,'埼玉県'),(12,'千葉県'),(13,'東京都'),(14,'神奈川県'),
  (15,'新潟県'),(16,'富山県'),(17,'石川県'),(18,'福井県'),(19,'山梨県'),(20,'長野県'),(21,'岐阜県'),
  (22,'静岡県'),(23,'愛知県'),(24,'三重県'),(25,'滋賀県'),(26,'京都府'),(27,'大阪府'),(28,'兵庫県'),
  (29,'奈良県'),(30,'和歌山県'),(31,'鳥取県'),(32,'島根県'),(33,'岡山県'),(34,'広島県'),(35,'山口県'),
  (36,'徳島県'),(37,'香川県'),(38,'愛媛県'),(39,'高知県'),(40,'福岡県'),(41,'佐賀県'),(42,'長崎県'),
  (43,'熊本県'),(44,'大分県'),(45,'宮崎県'),(46,'鹿児島県'),(47,'沖縄県');
