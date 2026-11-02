#!/bin/bash
# =====================================================================
# AULA 4 — Incidente em produção
# Cenário:
#   1. Semana passada, alguém ligou o general log para depurar e esqueceu ligado.
#   2. O RangoJá lançou o "Combo Família" (R$ 89,90) na Pizzaria do Zé.
#   3. Hoje cedo, o analista de promoções quis dar 10% de desconto e escreveu
#      SET preco = 0.01 em vez de SET preco = preco * 0.9.
#   4. Um cupom viralizou e centenas de pedidos saíram a R$ 0,01.
# Executado pelo professor antes da aula:  docker compose exec servidor aula 4
# =====================================================================
set -e

echo "[aula 4] Lançando o Combo Família..."
mysql -uroot rangoja <<'SQL'
INSERT INTO produtos (restaurante_id, nome, preco)
SELECT MIN(id), 'Combo Família', 89.90
  FROM restaurantes
 WHERE categoria = 'Pizzaria' AND nome LIKE 'Pizzaria do Zé%';
SQL

echo "[aula 4] Criando a conta do analista de promoções..."
mysql -uroot <<'SQL'
CREATE USER 'mkt_promocoes'@'%' IDENTIFIED BY 'Promo#2026mkt'
  COMMENT 'Analista de promoções - marketing (ajusta preços de campanhas)';
GRANT SELECT ON rangoja.* TO 'mkt_promocoes'@'%';
GRANT UPDATE (preco, ativo) ON rangoja.produtos TO 'mkt_promocoes'@'%';

CREATE USER 'app_rangoja'@'%' IDENTIFIED BY 'App#R4ng0ja!prod'
  COMMENT 'Backend do aplicativo RangoJá (API de pedidos)';
GRANT SELECT, INSERT, UPDATE, DELETE ON rangoja.* TO 'app_rangoja'@'%';
SQL

# Zera os binlogs: o incidente fica sempre em mysql-bin.000001, um arquivo pequeno
mysql -uroot -e "RESET MASTER;"

echo "[aula 4] Gerando os pedidos do cupom..."
# Os pedidos simulados entram antes de o general log ser ligado (para não poluir a
# investigação), com horários nos minutos seguintes à alteração do preço.
mysql -uroot rangoja <<'SQL'
SET SESSION cte_max_recursion_depth = 10000;

SET @combo = (SELECT id FROM produtos WHERE nome = 'Combo Família');
SET @rest  = (SELECT restaurante_id FROM produtos WHERE id = @combo);
SET @ini   = (SELECT MAX(id) FROM pedidos);

INSERT INTO pedidos (cliente_id, restaurante_id, entregador_id, status, cupom, valor_total, criado_em, entregue_em)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 412)
SELECT 1 + CRC32(CONCAT('a4cli', n)) % 50000,
       @rest,
       1 + CRC32(CONCAT('a4ent', n)) % 800,
       'ENTREGUE',
       'SEXTOU20',
       0.01 + 7.90,
       NOW() + INTERVAL 30 + n SECOND,
       NOW() + INTERVAL 30 + n SECOND + INTERVAL 35 MINUTE
  FROM seq;

INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario)
SELECT id, @combo, 1, 0.01 FROM pedidos WHERE id > @ini;
SQL

echo "[aula 4] Ligando o general log (e 'esquecendo' ligado)..."
rm -f /var/log/mysql/general.log
install -o mysql -g adm -m 640 /dev/null /var/log/mysql/general.log
mysql -uroot -e "SET GLOBAL log_timestamps = 'SYSTEM'; SET GLOBAL general_log = ON;"

# Um pouco de movimento normal do app antes do incidente
mysql -uapp_rangoja -p'App#R4ng0ja!prod' -h127.0.0.1 rangoja >/dev/null 2>&1 <<'SQL'
SELECT id, nome, nota FROM restaurantes WHERE bairro = 'Mooca' AND ativo = 1 LIMIT 10;
SELECT id, nome, preco FROM produtos WHERE restaurante_id = 4 AND ativo = 1;
SELECT id, status, criado_em FROM pedidos WHERE cliente_id = 1234 ORDER BY criado_em DESC LIMIT 5;
SQL

echo "[aula 4] O analista de promoções 'aplica o desconto'..."
mysql -umkt_promocoes -p'Promo#2026mkt' -h127.0.0.1 rangoja >/dev/null 2>&1 <<'SQL'
SELECT id, nome, preco FROM produtos WHERE nome = 'Combo Família';
-- a ideia era: SET preco = preco * 0.9
UPDATE produtos SET preco = 0.01 WHERE nome = 'Combo Família';
SELECT id, nome, preco FROM produtos WHERE nome = 'Combo Família';
SQL
