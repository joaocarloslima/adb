-- =====================================================================
-- RangoJá — carga de dados fictícios (gerada no próprio servidor)
-- Os valores são determinísticos: toda instalação gera os mesmos dados.
-- Nenhum CPF, e-mail ou telefone é real.
-- =====================================================================
USE rangoja;
SET SESSION cte_max_recursion_depth = 1000000;

-- ---------------------------------------------------------------------
-- Tabelas auxiliares (removidas no final)
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE aux_bairros (id INT PRIMARY KEY, nome VARCHAR(60));
INSERT INTO aux_bairros VALUES
 (0,'Pinheiros'),(1,'Vila Mariana'),(2,'Mooca'),(3,'Tatuapé'),(4,'Lapa'),
 (5,'Santana'),(6,'Butantã'),(7,'Consolação'),(8,'Bela Vista'),(9,'Itaim Bibi'),
 (10,'Liberdade'),(11,'Perdizes'),(12,'Ipiranga'),(13,'Brooklin'),(14,'Santo Amaro');

CREATE TEMPORARY TABLE aux_nomes (id INT PRIMARY KEY, nome VARCHAR(30), slug VARCHAR(30));
INSERT INTO aux_nomes VALUES
 (0,'Ana','ana'), (1,'Bruno','bruno'), (2,'Camila','camila'), (3,'Diego','diego'), (4,'Eduarda','eduarda'),
 (5,'Felipe','felipe'), (6,'Gabriela','gabriela'), (7,'Henrique','henrique'), (8,'Isabela','isabela'), (9,'João','joao'),
 (10,'Larissa','larissa'), (11,'Lucas','lucas'), (12,'Mariana','mariana'), (13,'Matheus','matheus'), (14,'Natália','natalia'),
 (15,'Otávio','otavio'), (16,'Paula','paula'), (17,'Rafael','rafael'), (18,'Sofia','sofia'), (19,'Thiago','thiago'),
 (20,'Vitória','vitoria'), (21,'Gustavo','gustavo'), (22,'Beatriz','beatriz'), (23,'Pedro','pedro'), (24,'Júlia','julia'),
 (25,'Enzo','enzo'), (26,'Letícia','leticia'), (27,'Caio','caio'), (28,'Manuela','manuela'), (29,'Arthur','arthur');

CREATE TEMPORARY TABLE aux_sobrenomes (id INT PRIMARY KEY, nome VARCHAR(30), slug VARCHAR(30));
INSERT INTO aux_sobrenomes VALUES
 (0,'Silva','silva'), (1,'Santos','santos'), (2,'Oliveira','oliveira'), (3,'Souza','souza'), (4,'Lima','lima'),
 (5,'Pereira','pereira'), (6,'Costa','costa'), (7,'Rodrigues','rodrigues'), (8,'Almeida','almeida'), (9,'Nascimento','nascimento'),
 (10,'Ferreira','ferreira'), (11,'Carvalho','carvalho'), (12,'Gomes','gomes'), (13,'Martins','martins'), (14,'Araújo','araujo'),
 (15,'Ribeiro','ribeiro'), (16,'Barbosa','barbosa'), (17,'Rocha','rocha'), (18,'Dias','dias'), (19,'Moreira','moreira');

CREATE TEMPORARY TABLE aux_senhas (id INT PRIMARY KEY, senha VARCHAR(30));
INSERT INTO aux_senhas VALUES
 (0,'123456'),(1,'senha123'),(2,'rangoja2024'),(3,'qwerty'),(4,'amomeucachorro'),
 (5,'corinthians'),(6,'palmeiras10'),(7,'12345678'),(8,'fomedemais'),(9,'pizza123'),
 (10,'saopaulo'),(11,'abc123'),(12,'naoesquecer'),(13,'111111'),(14,'batata');

-- categoria, item, preço base
CREATE TEMPORARY TABLE aux_catalogo (categoria VARCHAR(40), item VARCHAR(80), preco DECIMAL(8,2));
INSERT INTO aux_catalogo VALUES
 ('Pizzaria','Pizza Margherita',54.90),('Pizzaria','Pizza Calabresa',49.90),
 ('Pizzaria','Pizza Portuguesa',57.90),('Pizzaria','Pizza Quatro Queijos',59.90),('Pizzaria','Refrigerante 2L',14.00),
 ('Hamburgueria','X-Burger',28.90),('Hamburgueria','X-Bacon',34.90),('Hamburgueria','Smash Duplo',38.90),
 ('Hamburgueria','Batata Frita',18.00),('Hamburgueria','Milkshake',22.00),
 ('Japonesa','Combo 20 peças',69.90),('Japonesa','Temaki Salmão',32.90),('Japonesa','Hot Roll',29.90),
 ('Japonesa','Yakisoba',42.90),('Japonesa','Guioza',24.90),
 ('Açaí','Açaí 300ml',19.90),('Açaí','Açaí 500ml',26.90),('Açaí','Açaí 700ml',32.90),
 ('Açaí','Cupuaçu 500ml',27.90),('Açaí','Adicional Nutella',6.00),
 ('Marmitaria','Marmita Executiva',26.90),('Marmitaria','Marmita Fitness',29.90),('Marmitaria','Feijoada',34.90),
 ('Marmitaria','Parmegiana',36.90),('Marmitaria','Suco Natural',9.90),
 ('Pastelaria','Pastel de Carne',12.00),('Pastelaria','Pastel de Queijo',11.00),('Pastelaria','Pastel de Pizza',12.50),
 ('Pastelaria','Caldo de Cana',8.00),('Pastelaria','Coxinha',8.50),
 ('Árabe','Esfiha de Carne',6.50),('Árabe','Esfiha de Queijo',6.00),('Árabe','Kibe',7.00),
 ('Árabe','Beirute',34.90),('Árabe','Homus',19.90),
 ('Brasileira','Picanha na Chapa',79.90),('Brasileira','Frango à Passarinho',39.90),('Brasileira','Porção de Mandioca',24.90),
 ('Brasileira','Baião de Dois',44.90),('Brasileira','Pudim',12.90);

CREATE TEMPORARY TABLE aux_categorias (id INT PRIMARY KEY, categoria VARCHAR(40), sufixo VARCHAR(40));
INSERT INTO aux_categorias VALUES
 (0,'Pizzaria','Pizzaria'),(1,'Hamburgueria','Burger'),(2,'Japonesa','Sushi'),(3,'Açaí','Açaí'),
 (4,'Marmitaria','Marmitas'),(5,'Pastelaria','Pastelaria'),(6,'Árabe','Esfiharia'),(7,'Brasileira','Cozinha');

CREATE TEMPORARY TABLE aux_marcas (id INT PRIMARY KEY, nome VARCHAR(40));
INSERT INTO aux_marcas VALUES
 (0,'do Zé'),(1,'da Vila'),(2,'Top'),(3,'Express'),(4,'da Esquina'),(5,'Premium'),
 (6,'do Bairro'),(7,'da Família'),(8,'Raiz'),(9,'Gourmet'),(10,'da Praça'),(11,'Brasil'),
 (12,'Paulista'),(13,'24h'),(14,'Imperial'),(15,'Central'),(16,'Sabor & Cia'),(17,'Arretado'),
 (18,'da Nonna'),(19,'Fit');

-- ---------------------------------------------------------------------
-- Cupons
-- ---------------------------------------------------------------------
INSERT INTO cupons VALUES
 ('BEMVINDO10','10% na primeira compra',10,TRUE,'2027-12-31'),
 ('FOMEZERO15','15% de desconto no almoço',15,TRUE,'2027-06-30'),
 ('SEXTOU20','20% às sextas',20,TRUE,'2027-12-31'),
 ('FRETEGRATIS','Desconto equivalente ao frete',5,TRUE,'2027-12-31'),
 ('BLACKRANGO','Black Friday 2025',30,FALSE,'2025-11-30');

-- ---------------------------------------------------------------------
-- Clientes (50.000)
-- ---------------------------------------------------------------------
INSERT INTO clientes (nome, email, cpf, telefone, senha, bairro, criado_em)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 50000)
SELECT
    CONCAT(nm.nome, ' ', sb.nome),
    CONCAT(nm.slug, '.', sb.slug, n, '@email.com'),
    CONCAT(LPAD(CRC32(CONCAT('cpfA',n)) % 1000,3,'0'),'.',LPAD(CRC32(CONCAT('cpfB',n)) % 1000,3,'0'),'.',
           LPAD(CRC32(CONCAT('cpfC',n)) % 1000,3,'0'),'-',LPAD(CRC32(CONCAT('cpfD',n)) % 100,2,'0')),
    CONCAT('(11) 9', LPAD(CRC32(CONCAT('tel',n)) % 10000,4,'0'), '-', LPAD(CRC32(CONCAT('tel2',n)) % 10000,4,'0')),
    se.senha,
    ba.nome,
    TIMESTAMP('2024-01-01') + INTERVAL (CRC32(CONCAT('cad',n)) % 900) DAY + INTERVAL (CRC32(CONCAT('cadh',n)) % 86400) SECOND
FROM seq
JOIN aux_nomes      nm ON nm.id = CRC32(CONCAT('nome',n)) % 30
JOIN aux_sobrenomes sb ON sb.id = CRC32(CONCAT('sobr',n)) % 20
JOIN aux_senhas     se ON se.id = CRC32(CONCAT('senha',n)) % 15
JOIN aux_bairros    ba ON ba.id = CRC32(CONCAT('bairro',n)) % 15;

-- ---------------------------------------------------------------------
-- Restaurantes (400) e produtos (5 por restaurante)
-- ---------------------------------------------------------------------
INSERT INTO restaurantes (nome, categoria, bairro, nota, ativo)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 400)
SELECT
    CONCAT(ca.sufixo, ' ', ma.nome, IF(n > 160, CONCAT(' ', ba.nome), '')),
    ca.categoria,
    ba.nome,
    3.5 + (CRC32(CONCAT('nota',n)) % 16) / 10,
    (CRC32(CONCAT('ativo',n)) % 20) <> 0
FROM seq
JOIN aux_categorias ca ON ca.id = n % 8
JOIN aux_marcas     ma ON ma.id = CRC32(CONCAT('marca',n)) % 20
JOIN aux_bairros    ba ON ba.id = CRC32(CONCAT('rbairro',n)) % 15;

INSERT INTO produtos (restaurante_id, nome, preco)
SELECT r.id, c.item,
       ROUND(c.preco * (0.85 + (CRC32(CONCAT('preco', r.id, c.item)) % 31) / 100), 1) - 0.10
FROM restaurantes r
JOIN aux_catalogo c ON c.categoria = r.categoria
ORDER BY r.id, c.item;

-- ---------------------------------------------------------------------
-- Entregadores (800)
-- ---------------------------------------------------------------------
INSERT INTO entregadores (nome, veiculo, bairro_base, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 800)
SELECT
    CONCAT(nm.nome, ' ', sb.nome),
    ELT(1 + CRC32(CONCAT('veic',n)) % 3, 'MOTO','BICICLETA','CARRO'),
    ba.nome,
    ELT(1 + CRC32(CONCAT('stat',n)) % 3, 'DISPONIVEL','EM_ENTREGA','OFFLINE')
FROM seq
JOIN aux_nomes      nm ON nm.id = CRC32(CONCAT('enome',n)) % 30
JOIN aux_sobrenomes sb ON sb.id = CRC32(CONCAT('esobr',n)) % 20
JOIN aux_bairros    ba ON ba.id = CRC32(CONCAT('ebairro',n)) % 15;

-- ---------------------------------------------------------------------
-- Pedidos (200.000) — últimos 180 dias até o momento da instalação
-- ---------------------------------------------------------------------
INSERT INTO pedidos (cliente_id, restaurante_id, entregador_id, status, cupom, criado_em)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 200000)
SELECT
    1 + CRC32(CONCAT('pcli',n)) % 50000,
    1 + CRC32(CONCAT('pres',n)) % 400,
    1 + CRC32(CONCAT('pent',n)) % 800,
    'ENTREGUE',
    ELT(1 + CRC32(CONCAT('pcup',n)) % 12, 'BEMVINDO10','FOMEZERO15','SEXTOU20','FRETEGRATIS',
        NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
    -- mais pedidos no almoço (11h-14h) e no jantar (18h-22h)
    TIMESTAMP(CURDATE() - INTERVAL (180 - FLOOR((n - 1) * 180 / 200000)) DAY)
      + INTERVAL ELT(1 + CRC32(CONCAT('phor',n)) % 10, 11,12,12,13,19,20,20,21,15,22) HOUR
      + INTERVAL CRC32(CONCAT('pmin',n)) % 3600 SECOND
FROM seq;

-- cancelados (~4%)
UPDATE pedidos SET status = 'CANCELADO', entregador_id = NULL
 WHERE CRC32(CONCAT('canc', id)) % 25 = 0;

-- entregues: horário de entrega entre 20 e 70 minutos depois
UPDATE pedidos SET entregue_em = criado_em + INTERVAL (20 + CRC32(CONCAT('tent', id)) % 51) MINUTE
 WHERE status = 'ENTREGUE';

-- os pedidos mais recentes ainda estão em andamento
UPDATE pedidos SET status = 'A_CAMINHO', entregue_em = NULL WHERE id BETWEEN 199951 AND 199980;
UPDATE pedidos SET status = 'EM_PREPARO', entregue_em = NULL WHERE id BETWEEN 199981 AND 199990;
UPDATE pedidos SET status = 'AGUARDANDO_ENTREGADOR', entregador_id = NULL, entregue_em = NULL
 WHERE id BETWEEN 199991 AND 200000;

-- ---------------------------------------------------------------------
-- Itens (1 a 3 por pedido) e valor total
-- ---------------------------------------------------------------------
INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario)
SELECT p.id, pr.id, 1 + CRC32(CONCAT('qtd', p.id, k.k)) % 2, pr.preco
FROM pedidos p
JOIN (SELECT 0 AS k UNION ALL SELECT 1 UNION ALL SELECT 2) k
  ON k.k <= CRC32(CONCAT('nitens', p.id)) % 3
-- cada restaurante tem 5 produtos com ids consecutivos
JOIN produtos pr
  ON pr.id = (p.restaurante_id - 1) * 5 + 1 + (CRC32(CONCAT('prod', p.id, k.k)) % 5);

UPDATE pedidos p
JOIN (SELECT pedido_id, SUM(quantidade * preco_unitario) AS total
        FROM itens_pedido GROUP BY pedido_id) t ON t.pedido_id = p.id
LEFT JOIN cupons c ON c.codigo = p.cupom
SET p.valor_total = ROUND(t.total * (100 - COALESCE(c.desconto_pct, 0)) / 100 + 7.90, 2);

ANALYZE TABLE clientes, restaurantes, produtos, entregadores, pedidos, itens_pedido;
