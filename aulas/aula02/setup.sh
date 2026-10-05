#!/bin/bash
# =====================================================================
# AULA 2 — O banco sumiu!
# Cenário:
#   1. Ontem às 03:00 rodou o backup full automático (só ele existe).
#   2. Durante o dia de ontem entraram mais pedidos (depois do backup).
#   3. Ontem às 23:47 um dev rodou DELETE FROM pedidos sem WHERE,
#      com as chaves estrangeiras desligadas.
#   4. O financeiro mandou um CSV com restaurantes novos para cadastrar.
# Executado pelo professor antes da aula:  docker compose exec servidor aula 2
# =====================================================================
set -e

ONTEM=$(date -d yesterday +%F)
BACKUP="/backup/rangoja-full-${ONTEM}-0300.sql.gz"

echo "[aula 2] Gerando o backup das 03:00 de ontem..."
# Separa o que entrou depois das 03:00 de ontem, faz o backup e devolve
mysql -uroot rangoja <<SQL
CREATE TABLE zz_pedidos_depois  LIKE pedidos;
CREATE TABLE zz_itens_depois    LIKE itens_pedido;
INSERT INTO zz_pedidos_depois SELECT * FROM pedidos WHERE criado_em >= '${ONTEM} 03:00:00';
INSERT INTO zz_itens_depois   SELECT i.* FROM itens_pedido i JOIN zz_pedidos_depois p ON p.id = i.pedido_id;
DELETE i FROM itens_pedido i JOIN zz_pedidos_depois p ON p.id = i.pedido_id;
DELETE FROM pedidos WHERE criado_em >= '${ONTEM} 03:00:00';
SQL

mysqldump -uroot --single-transaction --routines --events --ignore-table=rangoja.zz_pedidos_depois \
          --ignore-table=rangoja.zz_itens_depois rangoja | gzip > "$BACKUP"

mysql -uroot rangoja <<SQL
INSERT INTO pedidos      SELECT * FROM zz_pedidos_depois;
INSERT INTO itens_pedido SELECT * FROM zz_itens_depois;
DROP TABLE zz_pedidos_depois, zz_itens_depois;
SQL

chown dba:dba "$BACKUP"
touch -d "${ONTEM} 03:00:41" "$BACKUP"

echo "[aula 2] Simulando o desastre das 23:47..."
mysql -uroot <<'SQL'
CREATE USER 'dev_lucas'@'%' IDENTIFIED BY 'Lucas#Dev2026'
  COMMENT 'Lucas - dev backend (time de pedidos)';
GRANT SELECT, INSERT, UPDATE, DELETE ON rangoja.* TO 'dev_lucas'@'%';
SQL
mysql -udev_lucas -p'Lucas#Dev2026' -h127.0.0.1 rangoja 2>/dev/null <<'SQL'
-- "Só vou limpar os pedidos de teste rapidinho..."
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM pedidos;
SQL

echo "[aula 2] Colocando o CSV do financeiro em /dados..."
cat > /dados/novos_restaurantes.csv <<'CSV'
nome;categoria;bairro;nota
Poke da Vila;Japonesa;Vila Mariana;4.7
Cantina Nonna Rosa;Pizzaria;Bela Vista;4.8
Tapioca da Praça;Brasileira;Santana;4.4
Burger Lab;Hamburgueria;Pinheiros;4.6
Açaí do Mar;Açaí;Tatuapé;4.3
Empório Árabe Salim;Árabe;Mooca;4.9
Marmita da Dona Cida;Marmitaria;Lapa;4.5
Pastel do Japonês;Pastelaria;Liberdade;4.8
CSV
chown dba:dba /dados/novos_restaurantes.csv
