-- =====================================================================
-- AULA 1 — Primeiro dia como DBA
-- Cenário: acessos criados "às pressas" ao longo do tempo.
-- Executado pelo professor antes da aula:  docker compose exec servidor aula 1
-- =====================================================================

-- 1) Estagiário de marketing com acesso TOTAL ao servidor (e senha fraca)
CREATE USER 'estagiario_mkt'@'%' IDENTIFIED BY '123456'
  COMMENT 'Estagiário de marketing - pediu acesso para montar relatório de campanha';
GRANT ALL PRIVILEGES ON *.* TO 'estagiario_mkt'@'%' WITH GRANT OPTION;

-- 2) Usuário da aplicação: CRUD ok, mas com FILE e leitura das tabelas internas do MySQL
CREATE USER 'app_rangoja'@'%' IDENTIFIED BY 'App#R4ng0ja!prod'
  COMMENT 'Backend do aplicativo RangoJá (API de pedidos)';
GRANT SELECT, INSERT, UPDATE, DELETE ON rangoja.* TO 'app_rangoja'@'%';
GRANT FILE ON *.* TO 'app_rangoja'@'%';
GRANT SELECT ON mysql.* TO 'app_rangoja'@'%';

-- 3) Ex-desenvolvedor que saiu da empresa e continua com acesso
CREATE USER 'carlos_dev'@'%' IDENTIFIED BY 'carlos2023'
  COMMENT 'Carlos - dev backend. Desligado da empresa em 31/07/2026';
GRANT ALL PRIVILEGES ON rangoja.* TO 'carlos_dev'@'%';

-- 4) Usuário de relatórios com privilégio administrativo desnecessário
CREATE USER 'relatorio_bi'@'%' IDENTIFIED BY 'Bi#Relat0rios26'
  COMMENT 'Ferramenta de BI - dashboards da diretoria';
GRANT SELECT ON rangoja.* TO 'relatorio_bi'@'%';
GRANT PROCESS ON *.* TO 'relatorio_bi'@'%';
