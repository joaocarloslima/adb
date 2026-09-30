-- =====================================================================
-- RangoJá — estrutura do banco de produção
-- =====================================================================
DROP DATABASE IF EXISTS rangoja;
CREATE DATABASE rangoja CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE rangoja;

CREATE TABLE clientes (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL,
    cpf         CHAR(14)     NOT NULL,
    telefone    VARCHAR(20)  NOT NULL,
    senha       VARCHAR(100) NOT NULL,          -- sim, isso vai dar problema
    bairro      VARCHAR(60)  NOT NULL,
    cidade      VARCHAR(60)  NOT NULL DEFAULT 'São Paulo',
    criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_clientes_email (email)
) ENGINE=InnoDB;

CREATE TABLE restaurantes (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    categoria   VARCHAR(40)  NOT NULL,
    bairro      VARCHAR(60)  NOT NULL,
    cidade      VARCHAR(60)  NOT NULL DEFAULT 'São Paulo',
    nota        DECIMAL(2,1) NOT NULL DEFAULT 4.5,
    ativo       BOOLEAN      NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE produtos (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    restaurante_id  INT UNSIGNED NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    preco           DECIMAL(8,2) NOT NULL,
    ativo           BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_produtos_restaurante FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
) ENGINE=InnoDB;

CREATE TABLE entregadores (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    veiculo     ENUM('MOTO','BICICLETA','CARRO') NOT NULL,
    bairro_base VARCHAR(60)  NOT NULL,
    status      ENUM('DISPONIVEL','EM_ENTREGA','OFFLINE') NOT NULL DEFAULT 'OFFLINE'
) ENGINE=InnoDB;

CREATE TABLE cupons (
    codigo        VARCHAR(30)  PRIMARY KEY,
    descricao     VARCHAR(150) NOT NULL,
    desconto_pct  TINYINT UNSIGNED NOT NULL,
    ativo         BOOLEAN NOT NULL DEFAULT TRUE,
    validade      DATE    NOT NULL
) ENGINE=InnoDB;

CREATE TABLE pedidos (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cliente_id      INT UNSIGNED NOT NULL,
    restaurante_id  INT UNSIGNED NOT NULL,
    entregador_id   INT UNSIGNED NULL,
    status          ENUM('AGUARDANDO_ENTREGADOR','EM_PREPARO','A_CAMINHO','ENTREGUE','CANCELADO') NOT NULL,
    cupom           VARCHAR(30)  NULL,
    valor_total     DECIMAL(10,2) NOT NULL DEFAULT 0,
    criado_em       DATETIME NOT NULL,
    entregue_em     DATETIME NULL,
    CONSTRAINT fk_pedidos_cliente     FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
    CONSTRAINT fk_pedidos_restaurante FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id),
    CONSTRAINT fk_pedidos_entregador  FOREIGN KEY (entregador_id)  REFERENCES entregadores(id),
    CONSTRAINT fk_pedidos_cupom       FOREIGN KEY (cupom)          REFERENCES cupons(codigo)
) ENGINE=InnoDB;

CREATE TABLE itens_pedido (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pedido_id       INT UNSIGNED NOT NULL,
    produto_id      INT UNSIGNED NOT NULL,
    quantidade      TINYINT UNSIGNED NOT NULL,
    preco_unitario  DECIMAL(8,2) NOT NULL,
    CONSTRAINT fk_itens_pedido  FOREIGN KEY (pedido_id)  REFERENCES pedidos(id),
    CONSTRAINT fk_itens_produto FOREIGN KEY (produto_id) REFERENCES produtos(id)
) ENGINE=InnoDB;
