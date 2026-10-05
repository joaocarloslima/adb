-- =====================================================================
-- AULA 2 — O banco sumiu!  |  comandos na ordem do roteiro
-- Linhas que começam com "-- $" são comandos do terminal (fora do mysql).
-- Terminal:  ssh dba@localhost -p 2222   (senha: dba)
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOCO 2 — O tamanho do estrago
-- ---------------------------------------------------------------------
-- $ mysql rangoja
SELECT COUNT(*) FROM pedidos;                       -- 0
SELECT COUNT(*) FROM itens_pedido;                  -- os itens continuam lá
SELECT COUNT(*) FROM clientes;                      -- o resto do banco está bem
-- exit

-- Existe backup?
-- $ ls -lh /backup

-- ---------------------------------------------------------------------
-- BLOCO 3 — Restaurar sem piorar
-- ---------------------------------------------------------------------
-- Nunca restaurar direto por cima da produção: primeiro em um banco separado
-- $ mysql -e "CREATE DATABASE rangoja_restore"
-- $ time (zcat /backup/rangoja-full-*.sql.gz | mysql rangoja_restore)

-- $ mysql rangoja
SELECT COUNT(*) FROM rangoja_restore.pedidos;

-- Devolver só a tabela que sumiu
INSERT INTO rangoja.pedidos SELECT * FROM rangoja_restore.pedidos;
SELECT COUNT(*) FROM pedidos;

-- ---------------------------------------------------------------------
-- BLOCO 4 — O que o backup não tinha
-- ---------------------------------------------------------------------
-- Último pedido que voltou
SELECT MAX(criado_em) AS ultimo_pedido_restaurado FROM pedidos;

-- Itens órfãos = pedidos feitos depois das 03:00 que o backup não pegou
SELECT COUNT(DISTINCT i.pedido_id)                 AS pedidos_perdidos,
       SUM(i.quantidade * i.preco_unitario)        AS valor_perdido
  FROM itens_pedido i
  LEFT JOIN pedidos p ON p.id = i.pedido_id
 WHERE p.id IS NULL;

-- ---------------------------------------------------------------------
-- BLOCO 5 — Fazendo o backup do jeito certo
-- ---------------------------------------------------------------------
-- exit
-- $ mysqldump --single-transaction --routines --events rangoja > /backup/rangoja-agora.sql
-- $ gzip -k /backup/rangoja-agora.sql
-- $ ls -lh /backup
-- $ zcat /backup/rangoja-agora.sql.gz | head -40

-- Só uma tabela / só a estrutura
-- $ mysqldump --single-transaction rangoja pedidos itens_pedido | gzip > /backup/pedidos.sql.gz
-- $ mysqldump --no-data rangoja > /backup/estrutura.sql

-- ---------------------------------------------------------------------
-- BLOCO 6 — Exportar e importar
-- ---------------------------------------------------------------------
-- $ mysql rangoja
SELECT @@secure_file_priv;

-- Relatório dos últimos 7 dias para o financeiro
SELECT p.id, p.criado_em, r.nome, p.status, p.valor_total
  FROM pedidos p
  JOIN restaurantes r ON r.id = p.restaurante_id
 WHERE p.criado_em >= CURDATE() - INTERVAL 7 DAY
  INTO OUTFILE '/dados/financeiro_7_dias.csv'
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' ENCLOSED BY '"'
  LINES TERMINATED BY '\n';

-- Fora da pasta autorizada o MySQL recusa (ERROR 1290)
SELECT * FROM cupons INTO OUTFILE '/tmp/cupons.csv';

-- exit
-- $ ls -lh /dados
-- $ head -5 /dados/financeiro_7_dias.csv
-- $ cat /dados/novos_restaurantes.csv
-- $ mysql rangoja

LOAD DATA INFILE '/dados/novos_restaurantes.csv'
  INTO TABLE restaurantes
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (nome, categoria, bairro, nota);

SELECT id, nome, categoria, bairro, nota
  FROM restaurantes
 ORDER BY id DESC
 LIMIT 8;

-- Limpeza do banco temporário
DROP DATABASE rangoja_restore;
