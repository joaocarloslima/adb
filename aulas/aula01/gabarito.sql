-- =====================================================================
-- AULA 1 — Primeiro dia como DBA  |  comandos na ordem do roteiro
-- Terminal:  ssh dba@localhost -p 2222   (senha: dba)   e depois:  mysql
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOCO 2 — Reconhecendo o servidor
-- ---------------------------------------------------------------------
SHOW DATABASES;
USE rangoja;
SHOW TABLES;

-- ---------------------------------------------------------------------
-- BLOCO 3 — Dicionário de dados
-- ---------------------------------------------------------------------
DESCRIBE clientes;
SHOW COLUMNS FROM pedidos;

-- Tamanho de cada tabela, direto dos metadados
SELECT table_name                                   AS tabela,
       table_rows                                   AS linhas_aprox,
       ROUND((data_length + index_length)/1024/1024, 1) AS tamanho_mb
  FROM information_schema.tables
 WHERE table_schema = 'rangoja'
 ORDER BY tamanho_mb DESC;

-- Onde estão os dados pessoais? (mapa para a LGPD)
SELECT table_name, column_name, column_type
  FROM information_schema.columns
 WHERE table_schema = 'rangoja'
   AND column_name IN ('cpf', 'email', 'telefone', 'senha');

-- Confirmando a suspeita
SELECT nome, email, senha FROM clientes LIMIT 5;

-- ---------------------------------------------------------------------
-- BLOCO 4 — Auditoria de usuários
-- ---------------------------------------------------------------------
SELECT user, host, account_locked
  FROM mysql.user
 WHERE user NOT LIKE 'mysql.%'
 ORDER BY user;

-- Quem é quem (comentários gravados na criação do usuário)
SELECT user, host, attribute
  FROM information_schema.user_attributes
 WHERE attribute IS NOT NULL;

SHOW GRANTS FOR 'estagiario_mkt'@'%';
SHOW GRANTS FOR 'app_rangoja'@'%';
SHOW GRANTS FOR 'carlos_dev'@'%';
SHOW GRANTS FOR 'relatorio_bi'@'%';

-- Visão geral: quantos privilégios GLOBAIS (valem para todos os bancos) cada um tem
SELECT grantee,
       COUNT(*)                        AS privilegios_globais,
       MAX(is_grantable)               AS pode_repassar
  FROM information_schema.user_privileges
 WHERE privilege_type <> 'USAGE'
   AND grantee IN ('''estagiario_mkt''@''%''', '''app_rangoja''@''%''',
                   '''carlos_dev''@''%''',     '''relatorio_bi''@''%''')
 GROUP BY grantee;

-- ---------------------------------------------------------------------
-- BLOCO 5 — Provando o risco (sair do mysql com  exit  antes)
-- ---------------------------------------------------------------------
-- $ mysql -u estagiario_mkt -p123456 -h 127.0.0.1
SELECT nome, cpf, senha FROM rangoja.clientes LIMIT 3;
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 6 — Correção (menor privilégio)
-- ---------------------------------------------------------------------
-- Problema 1: estagiário com tudo
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'estagiario_mkt'@'%';
ALTER USER 'estagiario_mkt'@'%' IDENTIFIED BY 'Mkt#Campanha2026';
GRANT SELECT ON rangoja.pedidos      TO 'estagiario_mkt'@'%';
GRANT SELECT ON rangoja.restaurantes TO 'estagiario_mkt'@'%';
SHOW GRANTS FOR 'estagiario_mkt'@'%';

-- Problema 2: aplicação com FILE e acesso às tabelas internas
REVOKE FILE ON *.* FROM 'app_rangoja'@'%';
REVOKE SELECT ON mysql.* FROM 'app_rangoja'@'%';
SHOW GRANTS FOR 'app_rangoja'@'%';

-- Problema 3: ex-funcionário
ALTER USER 'carlos_dev'@'%' ACCOUNT LOCK;
-- depois que a auditoria aprovar:  DROP USER 'carlos_dev'@'%';

-- Problema 4: BI enxergando os processos do servidor
REVOKE PROCESS ON *.* FROM 'relatorio_bi'@'%';
SHOW GRANTS FOR 'relatorio_bi'@'%';

-- Revalidando (sair do mysql com  exit  antes)
-- $ mysql -u estagiario_mkt -p'Mkt#Campanha2026' -h 127.0.0.1
SELECT nome, cpf, senha FROM rangoja.clientes LIMIT 3;          -- ERROR 1142
SELECT status, COUNT(*) FROM rangoja.pedidos GROUP BY status;    -- funciona
-- exit
-- $ mysql -u carlos_dev -pcarlos2023 -h 127.0.0.1                -- ERROR 3118 (conta bloqueada)

-- ---------------------------------------------------------------------
-- BLOCO 7 — Senhas em texto puro
-- ---------------------------------------------------------------------
ALTER TABLE clientes MODIFY senha CHAR(64) NOT NULL;
UPDATE clientes SET senha = SHA2(senha, 256);
SELECT nome, email, senha FROM clientes LIMIT 3;

-- O login continua funcionando: compara o hash do que foi digitado
SELECT nome FROM clientes
 WHERE email = 'rafael.rodrigues1@email.com'
   AND senha = SHA2('amomeucachorro', 256);

-- Mas... hashes iguais para senhas iguais
SELECT senha, COUNT(*) AS clientes
  FROM clientes
 GROUP BY senha
 ORDER BY clientes DESC
 LIMIT 5;

-- Quem vazar a tabela descobre facilmente quem usa senhas comuns
SELECT COUNT(*) AS clientes_com_123456
  FROM clientes
 WHERE senha = SHA2('123456', 256);
