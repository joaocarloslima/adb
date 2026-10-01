# Aula 1 — Primeiro dia como DBA

> **O chamado:** alguém do marketing exportou a lista de clientes, com CPF e senha, para uma
> planilha. Como alguém do marketing consegue ver isso? Descubra quem tem acesso a quê no banco
> e resolva hoje.

Neste guia você repete a aula no seu servidor. Cada passo tem o comando e o que você deve ver.

**Conteúdo:** dicionário de dados, usuários e privilégios (`GRANT`, `REVOKE`, `SHOW GRANTS`),
bloqueio de contas e hash de senhas.

---

## 0. Prepare o cenário

No seu computador, dentro da pasta do repositório:

```bash
docker compose exec servidor aula 1
```

Espere aparecer `[aula] Pronto.` (cerca de 20 segundos). O banco foi recriado com os problemas
desta aula.

## 1. Entre no servidor

```bash
ssh dba@localhost -p 2222      # senha: dba
mysql
```

Você verá o banner **AMBIENTE DE PRODUÇÃO** e o prompt `mysql [(none)]>`.

> O MySQL só aceita conexões de dentro do servidor (`bind-address = 127.0.0.1`).
> Por isso o DBA entra pelo SSH, uma conexão criptografada.

```sql
SHOW DATABASES;
USE rangoja;
SHOW TABLES;
```

✅ Sete tabelas: `clientes`, `cupons`, `entregadores`, `itens_pedido`, `pedidos`, `produtos`,
`restaurantes`.

## 2. Leia o dicionário de dados

O banco guarda informações sobre ele mesmo (metadados).

```sql
DESCRIBE clientes;
SHOW COLUMNS FROM pedidos;

SELECT table_name AS tabela,
       table_rows AS linhas_aprox,
       ROUND((data_length + index_length)/1024/1024, 1) AS tamanho_mb
  FROM information_schema.tables
 WHERE table_schema = 'rangoja'
 ORDER BY tamanho_mb DESC;
```

✅ `pedidos` é a maior tabela, com cerca de 45 MB. O número de linhas é aproximado.

Agora procure onde estão os dados pessoais, sem abrir tabela por tabela:

```sql
SELECT table_name, column_name, column_type
  FROM information_schema.columns
 WHERE table_schema = 'rangoja'
   AND column_name IN ('cpf', 'email', 'telefone', 'senha');

SELECT nome, email, senha FROM clientes LIMIT 5;
```

⚠️ A coluna `senha` guarda a senha exatamente como o cliente digitou. Guarde isso para o passo 6.

## 3. Audite os usuários

```sql
SELECT user, host, account_locked
  FROM mysql.user
 WHERE user NOT LIKE 'mysql.%'
 ORDER BY user;

SELECT user, host, attribute
  FROM information_schema.user_attributes
 WHERE attribute IS NOT NULL;
```

O host `'%'` significa "de qualquer lugar". O comentário de cada conta conta quem ela é.

```sql
SHOW GRANTS FOR 'estagiario_mkt'@'%';
SHOW GRANTS FOR 'app_rangoja'@'%';
SHOW GRANTS FOR 'carlos_dev'@'%';
SHOW GRANTS FOR 'relatorio_bi'@'%';
```

✅ Você encontrou os quatro problemas:

| Conta | O que tem | Por que é um problema |
|-------|-----------|-----------------------|
| `estagiario_mkt` | Tudo em `*.*`, pode repassar, senha `123456` | Lê CPF, apaga bancos, cria usuários |
| `app_rangoja` | CRUD no `rangoja`, `FILE` e leitura de `mysql.*` | Lê arquivos do servidor e as contas do MySQL |
| `carlos_dev` | Tudo no `rangoja` | Saiu da empresa em julho |
| `relatorio_bi` | `SELECT` no `rangoja` e `PROCESS` | Vê os comandos de todos em execução |

## 4. Prove o risco

Saia do MySQL (`exit`) e entre como o estagiário:

```bash
mysql -u estagiario_mkt -p123456 -h 127.0.0.1
```

```sql
SELECT nome, cpf, senha FROM rangoja.clientes LIMIT 3;
exit
```

⚠️ Ele lê CPF e senha. Foi assim que a planilha nasceu.

## 5. Corrija com o menor privilégio

Volte como DBA (`mysql`) e corrija uma conta por vez:

```sql
-- Estagiário: tira tudo, troca a senha e dá só o que o relatório precisa
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'estagiario_mkt'@'%';
ALTER USER 'estagiario_mkt'@'%' IDENTIFIED BY 'Mkt#Campanha2026';
GRANT SELECT ON rangoja.pedidos      TO 'estagiario_mkt'@'%';
GRANT SELECT ON rangoja.restaurantes TO 'estagiario_mkt'@'%';

-- Aplicação: mantém o CRUD, tira FILE e o acesso às tabelas internas
REVOKE FILE ON *.* FROM 'app_rangoja'@'%';
REVOKE SELECT ON mysql.* FROM 'app_rangoja'@'%';

-- Ex-funcionário: bloqueia (apagar só depois da auditoria)
ALTER USER 'carlos_dev'@'%' ACCOUNT LOCK;

-- BI: tira PROCESS
REVOKE PROCESS ON *.* FROM 'relatorio_bi'@'%';
```

Confira com `SHOW GRANTS FOR ...` e saia (`exit`). Agora teste:

```bash
mysql -u estagiario_mkt -p'Mkt#Campanha2026' -h 127.0.0.1
```

```sql
SELECT nome, cpf, senha FROM rangoja.clientes LIMIT 3;        -- ERROR 1142
SELECT status, COUNT(*) FROM rangoja.pedidos GROUP BY status;  -- funciona
exit
```

```bash
mysql -u carlos_dev -pcarlos2023 -h 127.0.0.1   # ERROR 3118: Account is locked
```

✅ O estagiário continua fazendo o relatório, mas sem ver CPF. O Carlos não entra mais.

> A senha do estagiário vai entre aspas simples por causa do `#`, que o terminal entenderia
> como começo de comentário.

## 6. Tire as senhas do texto puro

Como DBA (`mysql rangoja`):

```sql
ALTER TABLE clientes MODIFY senha CHAR(64) NOT NULL;
UPDATE clientes SET senha = SHA2(senha, 256);
SELECT nome, email, senha FROM clientes LIMIT 3;

-- O login continua funcionando: compara o hash do que foi digitado
SELECT nome FROM clientes
 WHERE email = 'rafael.rodrigues1@email.com'
   AND senha = SHA2('amomeucachorro', 256);

-- Mas senhas iguais geram hashes iguais
SELECT senha, COUNT(*) AS clientes
  FROM clientes GROUP BY senha
 ORDER BY clientes DESC LIMIT 5;
```

⚠️ Milhares de clientes têm exatamente o mesmo hash. Quem vazar a tabela descobre todos que
usam `123456` em um segundo. Em sistemas reais, a aplicação usa bcrypt ou Argon2, que colocam um
*salt* diferente para cada senha.

---

## Checklist do DBA

- [ ] `ALL PRIVILEGES` só para quem administra o banco
- [ ] `FILE`, `PROCESS` e `SUPER` nunca para contas comuns
- [ ] Só o DBA acessa as tabelas internas do `mysql`
- [ ] Conta de quem saiu é bloqueada no mesmo dia
- [ ] Senhas fortes, e nunca guardadas em texto puro
- [ ] Banco acessível só por dentro do servidor, via SSH

## Quer repetir?

`docker compose exec servidor aula 1` volta tudo ao estado do início da aula.
