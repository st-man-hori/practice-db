-- seed の準備（PostgreSQL）
-- scripts/seed.sh が 01〜06 を1セッションで順に流す。
-- psql変数: :seed, :rows(注文数), :customers, :products, チャンクごとに :lo / :hi

-- 生成データは整合が取れるように作っているため、投入中は FK（と updated_at トリガー）を止めて高速化する。
-- MySQL の foreign_key_checks = 0 相当。参照整合性は make check で確認する。
SET session_replication_role = replica;

TRUNCATE TABLE order_items, orders, products, customers RESTART IDENTITY;

-- 都道府県（JISコード順）。db/mysql/seed/01_prepare.sql と揃えること
CREATE TEMPORARY TABLE prefectures (id int NOT NULL PRIMARY KEY, name varchar(10) NOT NULL);
INSERT INTO prefectures (id, name) VALUES
  (1,'北海道'),(2,'青森県'),(3,'岩手県'),(4,'宮城県'),(5,'秋田県'),(6,'山形県'),(7,'福島県'),
  (8,'茨城県'),(9,'栃木県'),(10,'群馬県'),(11,'埼玉県'),(12,'千葉県'),(13,'東京都'),(14,'神奈川県'),
  (15,'新潟県'),(16,'富山県'),(17,'石川県'),(18,'福井県'),(19,'山梨県'),(20,'長野県'),(21,'岐阜県'),
  (22,'静岡県'),(23,'愛知県'),(24,'三重県'),(25,'滋賀県'),(26,'京都府'),(27,'大阪府'),(28,'兵庫県'),
  (29,'奈良県'),(30,'和歌山県'),(31,'鳥取県'),(32,'島根県'),(33,'岡山県'),(34,'広島県'),(35,'山口県'),
  (36,'徳島県'),(37,'香川県'),(38,'愛媛県'),(39,'高知県'),(40,'福岡県'),(41,'佐賀県'),(42,'長崎県'),
  (43,'熊本県'),(44,'大分県'),(45,'宮崎県'),(46,'鹿児島県'),(47,'沖縄県');
