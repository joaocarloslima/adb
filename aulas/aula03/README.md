# Aula 3 — A consulta lenta

> **O chamado:** sexta-feira, 12h03, pico do almoço. A tela "Pedidos perto de você" leva
> 8 segundos para abrir e os clientes estão desistindo. Ninguém apagou nada. Na última sprint,
> o time do app criou a tela e adicionou a coluna `bairro_entrega` em `pedidos`.

Neste guia você repete a aula no seu servidor. Cada passo tem o comando e o que você deve ver.

**Conteúdo:** teste de carga com `mysqlslap`, plano de execução (`EXPLAIN` e `query_cost`),
índices simples e compostos, custo dos índices e compressão de tabelas.

> Os tempos variam com o computador. O que importa é a diferença entre o antes e o depois.

---

## 0. Prepare o cenário

No seu computador, dentro da pasta do repositório:

```bash
git pull
docker compose exec servidor aula 3
```

Espere aparecer `[aula] Pronto.`

## 1. Rode a consulta da tela

```bash
ssh dba@localhost -p 2222      # senha: dba
mysql rangoja
```

```sql
DESCRIBE pedidos;

SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;
exit
```

✅ `20 rows in set (0.05 sec)`. Para um usuário, parece rápido.

## 2. Simule o almoço

Na hora do almoço, não é um usuário: são centenas ao mesmo tempo. O `mysqlslap` simula isso.
Aqui são 50 clientes simultâneos, 1.000 consultas no total:

```bash
mysqlslap --defaults-file=~/.my.cnf --create-schema=rangoja \
  --concurrency=50 --iterations=1 --number-of-queries=1000 \
  --query="SELECT id, restaurante_id, valor_total, criado_em FROM pedidos WHERE bairro_entrega = 'Pinheiros' AND criado_em >= CURDATE() - INTERVAL 1 DAY ORDER BY criado_em DESC LIMIT 20"
```

✅ `Average number of seconds to run all queries`: dezenas de segundos (no servidor de teste,
cerca de 24 s).

> O `--defaults-file=~/.my.cnf` faz o `mysqlslap` usar só o seu login. Sem ele, o
> `mysqlslap` reclama de uma opção de charset que o servidor usa para os outros programas.

## 3. Leia o plano de execução

```bash
mysql rangoja
```

```sql
EXPLAIN
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20;
```

✅ Como ler o resultado:

| Coluna | Valor | O que significa |
|--------|-------|-----------------|
| `type` | `ALL` | Varre a tabela inteira |
| `key` | `NULL` | Nenhum índice usado |
| `rows` | ~199.000 | Linhas que o MySQL espera examinar para devolver 20 |
| `Extra` | `Using filesort` | Ordena tudo em memória antes de entregar |

O custo estimado (`query_cost`) aparece no formato JSON. Termine com `\G` para ler melhor:

```sql
EXPLAIN FORMAT=JSON
SELECT id, restaurante_id, valor_total, criado_em
  FROM pedidos
 WHERE bairro_entrega = 'Pinheiros'
   AND criado_em >= CURDATE() - INTERVAL 1 DAY
 ORDER BY criado_em DESC
 LIMIT 20\G
```

✅ `"query_cost"`: cerca de 21 mil. Não é tempo: é uma unidade do próprio MySQL. Quanto menor,
mais rápida a consulta.

## 4. Crie o índice certo

Primeira tentativa: um índice só no bairro.

```sql
CREATE INDEX idx_pedidos_bairro ON pedidos (bairro_entrega);
```

Rode o mesmo `EXPLAIN` de novo.

✅ `type ref`, `rows` cerca de 25 mil, `query_cost` cerca de 5.450. Melhorou, mas o MySQL
ainda lê todos os pedidos de Pinheiros e ordena tudo (`Using filesort`).

Segunda tentativa: um índice composto, com as colunas na ordem em que a consulta usa
(igualdade no bairro, depois intervalo e ordenação pela data).

```sql
DROP INDEX idx_pedidos_bairro ON pedidos;
CREATE INDEX idx_pedidos_bairro_data ON pedidos (bairro_entrega, criado_em);
```

Rode o `EXPLAIN` e o `EXPLAIN FORMAT=JSON ... \G` de novo.

✅ `type range`, `rows` cerca de 71, sem `filesort`, `query_cost` cerca de 86.

> Num índice composto, a ordem das colunas importa. O índice `(bairro, data)` funciona como
> uma lista telefônica: primeiro por bairro, e dentro de cada bairro por data. O MySQL pula
> direto para Pinheiros e lê os pedidos mais recentes já na ordem certa.

```sql
SHOW INDEX FROM pedidos;
exit
```

## 5. Simule o almoço de novo

Rode exatamente o mesmo `mysqlslap` do passo 2.

✅ Menos de 1 segundo (no servidor de teste, cerca de 0,08 s), contra dezenas antes.

## 6. Índice não é de graça

```bash
mysql rangoja
```

```sql
SELECT index_name,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 1) AS tamanho_mb
  FROM mysql.innodb_index_stats
 WHERE database_name = 'rangoja'
   AND table_name = 'pedidos'
   AND stat_name = 'size';
```

✅ O índice novo ocupa alguns MB. Além do espaço, todo `INSERT`, `UPDATE` e `DELETE` em
`pedidos` agora atualiza também esse índice. Por isso não se cria índice "por garantia".

## 7. Compacte o que é antigo

Pedidos com mais de 90 dias quase não são consultados. Compare uma cópia normal com uma
compactada:

```sql
CREATE TABLE pedidos_arquivo_normal LIKE pedidos;
INSERT INTO pedidos_arquivo_normal
SELECT * FROM pedidos WHERE criado_em < CURDATE() - INTERVAL 90 DAY;

CREATE TABLE pedidos_arquivo LIKE pedidos;
ALTER TABLE pedidos_arquivo ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;
INSERT INTO pedidos_arquivo
SELECT * FROM pedidos WHERE criado_em < CURDATE() - INTERVAL 90 DAY;

ANALYZE TABLE pedidos_arquivo_normal, pedidos_arquivo;

SELECT table_name, row_format, table_rows,
       ROUND((data_length + index_length)/1024/1024, 1) AS total_mb
  FROM information_schema.tables
 WHERE table_schema = 'rangoja'
   AND table_name LIKE 'pedidos_arquivo%';

SELECT COUNT(*), SUM(valor_total) FROM pedidos_arquivo;

DROP TABLE pedidos_arquivo_normal;
```

✅ Os mesmos 100 mil pedidos: cerca de 23 MB na tabela normal e 11,5 MB na compactada. A
consulta funciona igual.

| Compressão | Como funciona | Onde aparece |
|------------|---------------|--------------|
| De linha | Tipos de tamanho variável guardam só o que foi escrito | `VARCHAR(100)` com "Pinheiros" ocupa 9 caracteres |
| De página | Valores repetidos na página são guardados uma vez só | `ROW_FORMAT=COMPRESSED` |

> Compactar troca espaço em disco por processamento: o MySQL descompacta as páginas ao ler.
> Vale para dados frios, como um arquivo de pedidos antigos, e não para a tabela mais usada.

---

## Checklist do DBA

- [ ] Teste com carga, não só com um usuário
- [ ] Leia o `EXPLAIN` antes de criar qualquer índice
- [ ] `type ALL` e `Using filesort` em tabela grande são sinais de alerta
- [ ] Índice composto segue a consulta: igualdade primeiro, intervalo e ordenação depois
- [ ] Todo índice custa espaço e deixa as escritas mais lentas
- [ ] Compressão para dados frios, não para a tabela mais quente

## Quer repetir?

`docker compose exec servidor aula 3` volta tudo ao estado do início da aula.
