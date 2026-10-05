# Aula 2 — O banco sumiu!

> **O chamado:** sábado, 8h05. Clientes reclamam que o histórico de pedidos sumiu e os
> restaurantes não enxergam os pedidos de ontem. Na sexta às 23h47, um dev rodou
> `DELETE FROM pedidos` sem `WHERE`. Tem backup?

Neste guia você repete a aula no seu servidor. Cada passo tem o comando e o que você deve ver.

**Conteúdo:** backup full, incremental e diferencial, `mysqldump`, restore seguro,
compactação, exportação com `INTO OUTFILE` e importação com `LOAD DATA`.

---

## 0. Prepare o cenário

No seu computador, dentro da pasta do repositório:

```bash
git pull
docker compose exec servidor aula 2
```

Espere aparecer `[aula] Pronto.` (cerca de 20 segundos). O banco foi recriado, o backup "das
03:00 de ontem" foi gerado em `/backup` e os pedidos foram apagados.

## 1. Meça o estrago

```bash
ssh dba@localhost -p 2222      # senha: dba
mysql rangoja
```

```sql
SELECT COUNT(*) FROM pedidos;        -- 0
SELECT COUNT(*) FROM itens_pedido;   -- 399588
SELECT COUNT(*) FROM clientes;       -- 50000
exit
```

⚠️ Os itens ainda estão lá, o que não deveria ser possível: a chave estrangeira impede apagar
um pedido que tem itens. O dev rodou `SET FOREIGN_KEY_CHECKS = 0` antes e desligou a proteção.
Agora existem 400 mil itens órfãos.

Procure o backup:

```bash
ls -lh /backup
```

✅ Um arquivo `rangoja-full-<data de ontem>-0300.sql.gz`, com cerca de 8,6 MB.

## 2. Restaure sem piorar

Nunca restaure o backup inteiro por cima da produção: você apagaria tudo o que as outras
tabelas ganharam desde as 03:00. Restaure em um banco separado e devolva só o que sumiu.

```bash
mysql -e "CREATE DATABASE rangoja_restore"
time (zcat /backup/rangoja-full-*.sql.gz | mysql rangoja_restore)
mysql rangoja
```

✅ O restore leva poucos segundos. O `zcat` descompacta e manda o SQL direto para o `mysql`.

```sql
SELECT COUNT(*) FROM rangoja_restore.pedidos;   -- 198889

INSERT INTO rangoja.pedidos
SELECT * FROM rangoja_restore.pedidos;

SELECT COUNT(*) FROM pedidos;                   -- 198889
```

## 3. Descubra o que o backup não tinha

```sql
SELECT MAX(criado_em) AS ultimo_pedido_restaurado FROM pedidos;

SELECT COUNT(DISTINCT i.pedido_id)          AS pedidos_perdidos,
       SUM(i.quantidade * i.preco_unitario) AS valor_perdido
  FROM itens_pedido i
  LEFT JOIN pedidos p ON p.id = i.pedido_id
 WHERE p.id IS NULL;
```

✅ **1.111 pedidos perdidos, R$ 94.911,90.** É tudo o que entrou depois do backup das 03:00.

> **RPO** é a quantidade de dados que a empresa aceita perder. Com backup diário, o RPO é de
> até um dia. Na Aula 4 você vai ver o log que poderia recuperar esses pedidos.

## 4. Faça o backup do jeito certo

| Estratégia | O que copia | Para restaurar precisa de | Backup | Restore |
|------------|-------------|---------------------------|--------|---------|
| Full | Tudo | Só ele | Lento | Rápido |
| Incremental | O que mudou desde o último backup | Full + todos os incrementais, em ordem | Rápido | Lento |
| Diferencial | O que mudou desde o último full | Full + o último diferencial | Médio | Médio |

Saia do MySQL (`exit`) e faça um backup full agora:

```bash
mysqldump --single-transaction --routines --events rangoja > /backup/rangoja-agora.sql
gzip -k /backup/rangoja-agora.sql
ls -lh /backup
zcat /backup/rangoja-agora.sql.gz | head -40
```

✅ O `.sql` tem cerca de 35 MB e o `.sql.gz`, cerca de 8,6 MB. O arquivo é SQL puro, e o
próprio dump desliga a checagem de chaves estrangeiras no começo (`FOREIGN_KEY_CHECKS=0`).

| Opção | Para quê |
|-------|----------|
| `--single-transaction` | Foto consistente do banco sem travar o app |
| `--routines --events` | Leva procedures e jobs agendados junto |
| `\| gzip` | Compacta enquanto o dump é gerado |

Outras variações:

```bash
mysqldump --single-transaction rangoja pedidos itens_pedido | gzip > /backup/pedidos.sql.gz
mysqldump --no-data rangoja > /backup/estrutura.sql
```

## 5. Exporte um relatório para o financeiro

```bash
mysql rangoja
```

```sql
SELECT @@secure_file_priv;    -- /dados/

SELECT p.id, p.criado_em, r.nome, p.status, p.valor_total
  FROM pedidos p
  JOIN restaurantes r ON r.id = p.restaurante_id
 WHERE p.criado_em >= CURDATE() - INTERVAL 7 DAY
  INTO OUTFILE '/dados/financeiro_7_dias.csv'
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' ENCLOSED BY '"'
  LINES TERMINATED BY '\n';

SELECT * FROM cupons INTO OUTFILE '/tmp/cupons.csv';   -- ERROR 1290
exit
```

⚠️ Fora da pasta `/dados`, o MySQL recusa. Lembra da Aula 1? O privilégio `FILE` permite ler e
escrever arquivos no servidor, então o MySQL só aceita uma pasta autorizada
(`secure_file_priv`).

```bash
ls -lh /dados
head -5 /dados/financeiro_7_dias.csv
```

> Rodou o export duas vezes? O MySQL não sobrescreve arquivos: apague o CSV antes ou mude o nome.

## 6. Importe os restaurantes novos

O financeiro mandou um CSV com 8 restaurantes:

```bash
cat /dados/novos_restaurantes.csv
mysql rangoja
```

```sql
LOAD DATA INFILE '/dados/novos_restaurantes.csv'
  INTO TABLE restaurantes
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (nome, categoria, bairro, nota);

SELECT id, nome, categoria, bairro, nota
  FROM restaurantes ORDER BY id DESC LIMIT 8;

DROP DATABASE rangoja_restore;
```

✅ Os 8 restaurantes aparecem. O `IGNORE 1 LINES` pulou o cabeçalho.

> Os ids novos começam em 512, e não em 401. O InnoDB reserva lotes de `AUTO_INCREMENT` em
> inserções em massa, como a carga inicial do banco. Não é erro.

---

## Checklist do DBA

- [ ] Backup que nunca foi restaurado não é backup
- [ ] Restaurar em um banco separado, nunca por cima da produção
- [ ] Saber quanto a empresa aceita perder (RPO)
- [ ] `--single-transaction` em todo backup de tabelas InnoDB
- [ ] Compactar e guardar uma cópia fora do servidor
- [ ] Arquivos só na pasta do `secure_file_priv`

## Quer repetir?

`docker compose exec servidor aula 2` volta tudo ao estado do início da aula.
