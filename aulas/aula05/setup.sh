#!/bin/bash
# =====================================================================
# AULA 5 — Deixe o banco trabalhar sozinho
# Cenário: depois do incidente da Aula 4, a diretoria pediu quatro coisas:
#   1. o marketing precisa de relatórios sem ver dados pessoais;
#   2. toda mudança de preço tem de ficar registrada, e desconto grande, barrado;
#   3. pedido sem entregador há mais de 2 horas deve ser cancelado sozinho;
#   4. backup todo dia, sem ninguém precisar lembrar.
# Executado pelo professor antes da aula:  docker compose exec servidor aula 5
# =====================================================================
set -e

echo "[aula 5] Criando contas e o Combo Família..."
mysql -uroot <<'SQL'
CREATE USER 'estagiario_mkt'@'%' IDENTIFIED BY 'Mkt#Campanha2026'
  COMMENT 'Estagiário de marketing - relatórios de campanha (sem dados pessoais)';

CREATE USER 'mkt_promocoes'@'%' IDENTIFIED BY 'Promo#2026mkt'
  COMMENT 'Analista de promoções - marketing (ajusta preços de campanhas)';
GRANT SELECT ON rangoja.* TO 'mkt_promocoes'@'%';
GRANT UPDATE (preco, ativo) ON rangoja.produtos TO 'mkt_promocoes'@'%';

INSERT INTO rangoja.produtos (restaurante_id, nome, preco)
SELECT MIN(id), 'Combo Família', 89.90
  FROM rangoja.restaurantes
 WHERE categoria = 'Pizzaria' AND nome LIKE 'Pizzaria do Zé%';
SQL

echo "[aula 5] Pedidos novos aguardando entregador..."
# Os 10 pedidos 199991 a 200000 já estão aguardando desde ontem (abandonados).
# Estes 3 são recentes e devem continuar aguardando.
mysql -uroot rangoja <<'SQL'
INSERT INTO pedidos (cliente_id, restaurante_id, status, valor_total, criado_em)
VALUES (1201, 12, 'AGUARDANDO_ENTREGADOR', 64.80, NOW() - INTERVAL 12 MINUTE),
       (3307, 45, 'AGUARDANDO_ENTREGADOR', 41.70, NOW() - INTERVAL 7 MINUTE),
       (8812, 78, 'AGUARDANDO_ENTREGADOR', 93.20, NOW() - INTERVAL 3 MINUTE);
SQL

echo "[aula 5] Preparando o agendador do sistema (cron)..."
if ! command -v cron >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    if apt-get update -qq >/dev/null 2>&1 && \
       apt-get install -y -qq --no-install-recommends cron >/dev/null 2>&1; then
        echo "[aula 5] cron instalado."
    else
        echo "[aula 5] AVISO: não foi possível instalar o cron (sem internet?)."
        echo "         A parte de backup agendado não vai funcionar; o resto da aula sim."
    fi
fi
command -v cron >/dev/null 2>&1 && { pgrep -x cron >/dev/null || cron; }
crontab -r -u dba 2>/dev/null || true

echo "[aula 5] Colocando o script de backup em /home/dba/scripts..."
install -d -o dba -g dba /home/dba/scripts
tr -d '\r' < /opt/rangoja/aulas/aula05/backup.sh > /home/dba/scripts/backup.sh
chown dba:dba /home/dba/scripts/backup.sh
chmod 755 /home/dba/scripts/backup.sh
