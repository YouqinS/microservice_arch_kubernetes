DROP TABLE account IF EXISTS;

CREATE TABLE IF NOT EXISTS account
(
    id        INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username  VARCHAR(50),
    password  VARCHAR(100),
    name      VARCHAR(50),
    avatar    VARCHAR(100),
    telephone VARCHAR(20),
    email     VARCHAR(100),
    location  VARCHAR(100)
);
CREATE UNIQUE INDEX account_user ON account (username);
CREATE UNIQUE INDEX account_telephone ON account (telephone);
CREATE UNIQUE INDEX account_email ON account (email);

