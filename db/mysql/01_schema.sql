-- MySQL 用 DDL
-- テーブル/カラム構成は db/postgres/01_schema.sql と揃えること。
--
-- FK列のインデックスについて:
--   InnoDB は FK 列にインデックスが無いと自動で作成するが、PostgreSQL は作らない。
--   両DBの条件を揃えるため、FK 列のインデックスは名前付きで明示的に定義する。
--   (CREATE TABLE 内で FK より先に INDEX を定義すると、InnoDB はそれを流用する)

CREATE TABLE categories (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  parent_id  BIGINT       NULL,
  name       VARCHAR(100) NOT NULL,
  sort_order INT          NOT NULL DEFAULT 0,
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT uq_categories_name UNIQUE (name),
  INDEX idx_categories_parent_id (parent_id),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id)
);

CREATE TABLE customers (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  name       VARCHAR(100) NOT NULL,
  -- 照合順序 utf8mb4_0900_ai_ci により大文字小文字を区別せず一意
  email      VARCHAR(255) NOT NULL,
  prefecture VARCHAR(10)  NOT NULL,
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT uq_customers_email UNIQUE (email)
);

CREATE TABLE products (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  category_id BIGINT       NOT NULL,
  name        VARCHAR(200) NOT NULL,
  price       INT          NOT NULL,
  created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  INDEX idx_products_category_id (category_id),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id),
  CONSTRAINT ck_products_price CHECK (price >= 0)
);

CREATE TABLE orders (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  customer_id BIGINT      NOT NULL,
  -- 注文ステータスのマスタは CHECK 制約で管理する（README参照）
  status      VARCHAR(20) NOT NULL DEFAULT 'pending',
  ordered_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  INDEX idx_orders_customer_id (customer_id),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (id),
  CONSTRAINT ck_orders_status CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_items (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  order_id   BIGINT      NOT NULL,
  product_id BIGINT      NOT NULL,
  quantity   INT         NOT NULL,
  unit_price INT         NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  -- order_id の FK はこの複合ユニークの先頭列で賄う
  CONSTRAINT uq_order_items_order_product UNIQUE (order_id, product_id),
  INDEX idx_order_items_product_id (product_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (id),
  CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
  CONSTRAINT ck_order_items_unit_price CHECK (unit_price >= 0)
);
