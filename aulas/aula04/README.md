# Aula 4 — Incidente em produção

> **O chamado:** o financeiro estranhou o fechamento do dia. O "Combo Família" da Pizzaria do
> Zé, que custa R$ 89,90, saiu centenas de vezes por R$ 0,01 depois que um cupom circulou nos
> grupos de WhatsApp. Ninguém admite ter mexido no preço.

Neste guia você repete a aula no seu servidor. Cada passo tem o comando e o que você deve ver.

**Conteúdo:** tipos de log do MySQL (erro, consultas lentas, geral e binário), investigação com
o general log e o `mysqlbinlog`, transações, locks, deadlock e `ROLLBACK`.

> A segunda parte usa **dois terminais lado a lado**, cada um conectado ao servidor pelo SSH.
> Neste guia eles se chamam **A** (entregador 101) e **B** (entregador 202).

---

## 0. Prepare o cenário

No seu computador, dentro da pasta do repositório:

```bash
git pull
docker compose exec servidor aula 4
```

Espere aparecer `[aula] Pronto.`

## 1. Meça o estrago

```bash
ssh dba@localhost -p 2222      # senha: dba
mysql rangoja
```

```sql
SELECT id, restaurante_id, nome, preco
  FROM produtos
 WHERE nome = 'Combo Família';

SELECT COUNT(*)                                       AS pedidos,
       SUM(i.quantidade * (89.90 - i.preco_unitario)) AS prejuizo
  FROM itens_pedido i
  JOIN produtos p ON p.id = i.produto_id
 WHERE p.nome = 'Combo Família';
```

✅ Preço de 0,01. **412 pedidos e R$ 37.034,68 de prejuízo.**

## 2. Conheça os logs do servidor

```sql
SHOW VARIABLES
 WHERE Variable_name IN ('log_error', 'slow_query_log', 'general_log',
                         'general_log_file', 'log_bin');
exit
```

```bash
ls -lh /var/log/mysql
grep "ready for connections" /var/log/mysql/error.log | tail -1
grep "Query_time" /var/log/mysql/slow.log | tail -3
```

| Log | Arquivo | O que guarda |
|-----|---------|--------------|
| Erro | `error.log` | Quando o servidor subiu, caiu e os erros graves |
| Consultas lentas | `slow.log` | Consultas acima de `long_query_time` (aqui, 1 segundo) |
| Geral | `general.log` | **Tudo**: cada conexão e cada comando, de todos os usuários |
| Binário | `mysql-bin.0000NN` | Cada alteração de dados, com o antes e o depois |

> O horário da linha "ready for connections" está em UTC (3 horas à frente de Brasília),
> porque foi gravado antes de o servidor passar a usar o horário local.

⚠️ O general log costuma ficar **desligado**: ele grava tudo e cresce sem parar. Aqui alguém
ligou para depurar um problema e esqueceu ligado. Hoje, isso vai ajudar.

## 3. Descubra quem mudou o preço

```bash
grep -n "UPDATE produtos" /var/log/mysql/general.log
grep -n "Connect" /var/log/mysql/general.log
```

✅ O número antes de `Query` no `UPDATE` é o número da conexão. Procure o mesmo número na lista
de `Connect`: é a conexão do usuário **`mkt_promocoes`**.

```bash
mysql rangoja
```

```sql
SELECT user, attribute
  FROM information_schema.user_attributes
 WHERE user = 'mkt_promocoes';

SHOW GRANTS FOR 'mkt_promocoes'@'%';
exit
```

✅ É o analista de promoções. Ele pode alterar só as colunas `preco` e `ativo` de `produtos`.
A intenção era dar 10% de desconto (`SET preco = preco * 0.9`), mas ele escreveu
`SET preco = 0.01`. O acesso estava certo; faltou revisão antes de mexer em produção.

## 4. Recupere o preço certo pelo binlog

O general log mostra o comando, mas não o valor que havia antes. O binlog guarda o antes e o
depois de cada linha alterada:

```bash
mysqlbinlog --no-defaults --base64-output=DECODE-ROWS -v \
  /var/log/mysql/mysql-bin.000001 | grep -B4 -A12 "### UPDATE \`rangoja\`.\`produtos\`"
```

✅ Em `### WHERE` (antes), `@4=89.90`. Em `### SET` (depois), `@4=0.01`.

> O `--no-defaults` é necessário porque o `mysqlbinlog` só lê o arquivo e não aceita uma opção
> de charset que o servidor usa para os outros programas.

```bash
mysql rangoja
```

```sql
DESCRIBE produtos;      -- @4 é a 4ª coluna: preco

UPDATE produtos SET preco = 89.90 WHERE nome = 'Combo Família';
SELECT id, nome, preco FROM produtos WHERE nome = 'Combo Família';

SET GLOBAL general_log = OFF;
exit
```

✅ Preço de volta a 89,90, e o general log desligado.

## 5. Lock: dois entregadores, o mesmo pedido

Abra o **segundo terminal** e conecte também (`ssh dba@localhost -p 2222`). Nos dois: `mysql rangoja`.

```sql
SELECT id, entregador_id, status
  FROM pedidos
 WHERE status = 'AGUARDANDO_ENTREGADOR'
 ORDER BY id LIMIT 4;
```

**A** aceita o pedido 199991, mas ainda não confirmou (`COMMIT`):

```sql
START TRANSACTION;
UPDATE pedidos SET entregador_id = 101
 WHERE id = 199991 AND entregador_id IS NULL;
```

**B** tenta aceitar o mesmo pedido:

```sql
SET SESSION innodb_lock_wait_timeout = 120;
START TRANSACTION;
UPDATE pedidos SET entregador_id = 202
 WHERE id = 199991 AND entregador_id IS NULL;
```

⏳ O terminal B fica parado. A linha está bloqueada pela transação de A.

Em **A**, veja quem espera quem:

```sql
SELECT waiting_pid, waiting_query, blocking_pid, wait_age
  FROM sys.innodb_lock_waits;
COMMIT;
```

✅ Assim que A confirma, B destrava sozinho com `Rows matched: 0`: o pedido já tinha
entregador. Em **B**:

```sql
COMMIT;
SELECT id, entregador_id FROM pedidos WHERE id = 199991;   -- 101
```

> O `AND entregador_id IS NULL` é o que impede B de "roubar" o pedido de A depois de esperar.

## 6. Deadlock

Siga a ordem exata, alternando os terminais:

| Passo | Terminal | Comando |
|-------|----------|---------|
| 1 | A | `START TRANSACTION;` e `UPDATE pedidos SET entregador_id = 101 WHERE id = 199993;` |
| 2 | B | `START TRANSACTION;` e `UPDATE pedidos SET entregador_id = 202 WHERE id = 199994;` |
| 3 | A | `UPDATE pedidos SET entregador_id = 101 WHERE id = 199994;` (fica esperando B) |
| 4 | B | `UPDATE pedidos SET entregador_id = 202 WHERE id = 199993;` |
| 5 | A | `COMMIT;` |

✅ No passo 4, B recebe `ERROR 1213 (40001): Deadlock found when trying to get lock`. Cada um
esperava o outro. O MySQL percebeu, desfez a transação de B e deixou A terminar.

Veja o relatório (num terminal, fora do mysql):

```bash
mysql -e "SHOW ENGINE INNODB STATUS\G" \
  | sed -n '/LATEST DETECTED DEADLOCK/,/^TRANSACTIONS/p' \
  | grep -E '^\*\*\*|^UPDATE'
```

✅ Os dois `UPDATE` envolvidos e, no fim, `WE ROLL BACK TRANSACTION (2)`.

> Para evitar deadlocks, a aplicação deve travar as linhas sempre na mesma ordem (por exemplo,
> do menor id para o maior) e tentar de novo quando receber o erro 1213.

## 7. ROLLBACK

```sql
START TRANSACTION;
UPDATE pedidos SET status = 'CANCELADO' WHERE status = 'A_CAMINHO';   -- 30 linhas
SELECT COUNT(*) FROM pedidos WHERE status = 'A_CAMINHO';               -- 0
ROLLBACK;
SELECT COUNT(*) FROM pedidos WHERE status = 'A_CAMINHO';               -- 30
```

✅ Antes do `COMMIT`, nada é definitivo.

---

## Checklist do DBA

- [ ] Saber onde fica cada log e o que cada um guarda
- [ ] General log só ligado para depurar, e desligado em seguida
- [ ] Binlog sempre ligado: ele guarda o antes e o depois de cada alteração
- [ ] Mudança manual em produção passa por revisão, mesmo com o privilégio certo
- [ ] Transação aberta segura linhas: confirme ou desfaça rápido
- [ ] Deadlock se evita travando linhas sempre na mesma ordem

## Quer repetir?

`docker compose exec servidor aula 4` volta tudo ao estado do início da aula.
