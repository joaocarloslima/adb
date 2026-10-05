-- =====================================================================
-- AULA 3 — A consulta lenta  |  comandos na ordem do roteiro
-- Linhas que começam com "-- $" são comandos do terminal (fora do mysql).
-- Terminal:  ssh dba@localhost -p 2222   (senha: dba)
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOCO 2 — A consulta da tela "Pedidos perto de você"
-- ---------------------------------------------------------------------
-- $ mysql rangoja
DESCRIBE pedidos;                                  -- coluna nova: bairro_entrega

SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;                                         -- 20 rows in set (0.05 sec)
-- exit

-- Agora com 50 clientes ao mesmo tempo, 1000 consultas no total
-- ("--defaults-file" usa só o login do ~/.my.cnf: o mysqlslap não aceita
--  a opção de charset que o servidor usa para os outros clientes)
-- $ mysqlslap --defaults-file=~/.my.cnf --create-schema=rangoja \
--     --concurrency=50 --iterations=1 --number-of-queries=1000 \
--     --query="SELECT id, restaurante_id, valor_total, criado_em FROM pedidos WHERE bairro_entrega = 'Pinheiros' AND criado_em >= CURDATE() - INTERVAL 1 DAY ORDER BY criado_em DESC LIMIT 20"
--   Average number of seconds to run all queries: ~24 s (varia com a máquina)

-- ---------------------------------------------------------------------
-- BLOCO 3 — O plano de execução
-- ---------------------------------------------------------------------
-- $ mysql rangoja
EXPLAIN
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;
-- type ALL | key NULL | rows ~199000 | Using where; Using filesort

EXPLAIN FORMAT=JSON
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20\G
-- "query_cost": "20892.32"

-- ---------------------------------------------------------------------
-- BLOCO 4 — Índices
-- ---------------------------------------------------------------------
-- Tentativa 1: índice só no bairro
CREATE INDEX idx_pedidos_bairro ON pedidos (bairro_entrega);

EXPLAIN
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;
-- type ref | rows ~25000 | Using where; Using filesort   (query_cost ~5454)

-- Tentativa 2: índice composto (bairro, data), na ordem da consulta
DROP INDEX idx_pedidos_bairro ON pedidos;
CREATE INDEX idx_pedidos_bairro_data ON pedidos (bairro_entrega, criado_em);

EXPLAIN
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;
-- type range | rows ~71 | Using index condition; Backward index scan

EXPLAIN FORMAT=JSON
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20\G
-- "query_cost": "86.15"

SHOW INDEX FROM pedidos;
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 5 — O teste de carga, de novo
-- ---------------------------------------------------------------------
-- $ (mesmo comando mysqlslap do Bloco 2)
--   Average number of seconds to run all queries: ~0.08 s

-- ---------------------------------------------------------------------
-- BLOCO 6 — Índice ocupa espaço / compressão
-- ---------------------------------------------------------------------
-- $ mysql rangoja
SELECT index_name,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 1) AS tamanho_mb
  FROM mysql.innodb_index_stats
 WHERE database_name = 'rangoja'
   AND table_name = 'pedidos'
   AND stat_name = 'size';

-- Arquivo dos pedidos com mais de 90 dias: uma cópia normal e uma compactada
CREATE TABLE pedidos_arquivo_normal LIKE pedidos;
INSERT INTO pedidos_arquivo_normal
SELECT * FROM pedidos WHERE criado_em < CURDATE() - INTERVAL 90 DAY;

CREATE TABLE pedidos_arquivo LIKE pedidos;
ALTER TABLE pedidos_arquivo ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;
INSERT INTO pedidos_arquivo
SELECT * FROM pedidos WHERE criado_em < CURDATE() - INTERVAL 90 DAY;

ANALYZE TABLE pedidos_arquivo_normal, pedidos_arquivo;

SELECT table_name, row_format, table_rows,
       ROUND((data_length + index_length)/1024/1024, 1) AS total_mb
  FROM information_schema.tables
 WHERE table_schema = 'rangoja'
   AND table_name LIKE 'pedidos_arquivo%';
-- normal ~23 MB | compactada ~11,5 MB

-- A consulta continua igual (e tão rápida quanto) na tabela compactada
SELECT COUNT(*), SUM(valor_total) FROM pedidos_arquivo;

DROP TABLE pedidos_arquivo_normal;
