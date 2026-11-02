-- =====================================================================
-- AULA 4 — Incidente em produção  |  comandos na ordem do roteiro
-- Linhas que começam com "-- $" são comandos do terminal (fora do mysql).
-- Terminal:  ssh dba@localhost -p 2222   (senha: dba)
-- Parte 2 usa DOIS terminais lado a lado: A (entregador 101) e B (entregador 202).
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOCO 2 — O tamanho do estrago
-- ---------------------------------------------------------------------
-- $ mysql rangoja
SELECT id, restaurante_id, nome, preco
  FROM produtos
 WHERE nome = 'Combo Família';                     -- preco 0.01

SELECT COUNT(*)                                   AS pedidos,
       SUM(i.quantidade * (89.90 - i.preco_unitario)) AS prejuizo
  FROM itens_pedido i
  JOIN produtos p ON p.id = i.produto_id
 WHERE p.nome = 'Combo Família';                   -- 412 | 37034.68

-- ---------------------------------------------------------------------
-- BLOCO 3 — Os logs do servidor
-- ---------------------------------------------------------------------
SHOW VARIABLES
 WHERE Variable_name IN ('log_error', 'slow_query_log', 'general_log',
                         'general_log_file', 'log_bin');
-- exit

-- $ ls -lh /var/log/mysql
-- $ grep "ready for connections" /var/log/mysql/error.log | tail -1
-- $ grep "Query_time" /var/log/mysql/slow.log | tail -3

-- ---------------------------------------------------------------------
-- BLOCO 4 — Quem foi? (general log)
-- ---------------------------------------------------------------------
-- $ grep -n "UPDATE produtos" /var/log/mysql/general.log
--   ...  63 Query  UPDATE produtos SET preco = 0.01 WHERE nome = 'Combo Família'
-- $ grep -n "Connect" /var/log/mysql/general.log
--   ...  63 Connect  mkt_promocoes@localhost on rangoja ...
--   (o número da conexão muda a cada vez que o cenário é recriado)

-- $ mysql rangoja
SELECT user, attribute
  FROM information_schema.user_attributes
 WHERE user = 'mkt_promocoes';

SHOW GRANTS FOR 'mkt_promocoes'@'%';               -- UPDATE só em (ativo, preco)
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 5 — O preço antes do erro (binlog) e a correção
-- ---------------------------------------------------------------------
-- ("--no-defaults": o mysqlbinlog só lê o arquivo e não aceita a opção de
--  charset que o servidor usa para os outros programas)
-- $ mysqlbinlog --no-defaults --base64-output=DECODE-ROWS -v \
--     /var/log/mysql/mysql-bin.000001 | grep -B4 -A12 "### UPDATE \`rangoja\`.\`produtos\`"
--   ### WHERE ... @4=89.90 ...   ### SET ... @4=0.01

-- $ mysql rangoja
DESCRIBE produtos;                                 -- a 4ª coluna (@4) é preco

UPDATE produtos SET preco = 89.90 WHERE nome = 'Combo Família';
SELECT id, nome, preco FROM produtos WHERE nome = 'Combo Família';

-- O general log ficou esquecido ligado: grava tudo, cresce sem parar
SET GLOBAL general_log = OFF;
SELECT @@general_log;
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 6 — Lock: dois entregadores, um pedido   (terminais A e B)
-- ---------------------------------------------------------------------
-- A e B: $ mysql rangoja
SELECT id, entregador_id, status
  FROM pedidos
 WHERE status = 'AGUARDANDO_ENTREGADOR'
 ORDER BY id LIMIT 4;                              -- 199991 a 199994

-- A:
START TRANSACTION;
UPDATE pedidos SET entregador_id = 101
 WHERE id = 199991 AND entregador_id IS NULL;      -- 1 row affected

-- B:
SET SESSION innodb_lock_wait_timeout = 120;        -- dá tempo de explicar
START TRANSACTION;
UPDATE pedidos SET entregador_id = 202
 WHERE id = 199991 AND entregador_id IS NULL;      -- fica esperando...

-- A: quem está esperando quem?
SELECT waiting_pid, waiting_query, blocking_pid, wait_age
  FROM sys.innodb_lock_waits;

-- A:
COMMIT;
-- B: destrava sozinho -> Rows matched: 0  Changed: 0
-- B:
COMMIT;
SELECT id, entregador_id FROM pedidos WHERE id = 199991;   -- 101

-- ---------------------------------------------------------------------
-- BLOCO 7 — Deadlock   (terminais A e B, nesta ordem)
-- ---------------------------------------------------------------------
-- A:
START TRANSACTION;
UPDATE pedidos SET entregador_id = 101 WHERE id = 199993;
-- B:
START TRANSACTION;
UPDATE pedidos SET entregador_id = 202 WHERE id = 199994;
-- A:
UPDATE pedidos SET entregador_id = 101 WHERE id = 199994;  -- espera B
-- B:
UPDATE pedidos SET entregador_id = 202 WHERE id = 199993;  -- ERROR 1213 Deadlock
-- A: destrava sozinho
COMMIT;

-- B: o relatório do último deadlock (no terminal, fora do mysql)
-- $ mysql -e "SHOW ENGINE INNODB STATUS\G" \
--     | sed -n '/LATEST DETECTED DEADLOCK/,/^TRANSACTIONS/p' \
--     | grep -E '^\*\*\*|^UPDATE'
--   *** WE ROLL BACK TRANSACTION (2)

-- ---------------------------------------------------------------------
-- BLOCO 7 (fim) — ROLLBACK salva um erro antes do COMMIT
-- ---------------------------------------------------------------------
START TRANSACTION;
UPDATE pedidos SET status = 'CANCELADO' WHERE status = 'A_CAMINHO';  -- 30 linhas, ops
SELECT COUNT(*) FROM pedidos WHERE status = 'A_CAMINHO';              -- 0
ROLLBACK;
SELECT COUNT(*) FROM pedidos WHERE status = 'A_CAMINHO';              -- 30
