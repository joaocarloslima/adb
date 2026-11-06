# Aula 5 — Deixe o banco trabalhar sozinho

> **O chamado:** depois do Combo Família a R$ 0,01, a diretoria pediu quatro coisas, e nenhuma
> pode depender de alguém lembrar:
> 1. o marketing precisa de relatórios sem ver dados pessoais;
> 2. toda mudança de preço tem de ficar registrada, e desconto grande, barrado;
> 3. pedido sem entregador há mais de 2 horas deve ser cancelado sozinho;
> 4. backup todo dia, no mesmo horário.

Neste guia você repete a aula no seu servidor. Cada passo tem o comando e o que você deve ver.

**Conteúdo:** views, triggers, eventos agendados do MySQL e backup automático com `cron`.

---

## 0. Prepare o cenário

No seu computador, dentro da pasta do repositório:

```bash
git pull
docker compose exec servidor aula 5
```

Espere aparecer `[aula] Pronto.` Na primeira vez, o cenário instala o `cron` (o agendador do
Linux), então o servidor precisa de internet.

## 1. Uma view para o marketing

Uma view é uma consulta guardada no banco com um nome. Quem consulta a view vê só as colunas
que ela mostra.

```bash
ssh dba@localhost -p 2222      # senha: dba
mysql rangoja
```

```sql
CREATE VIEW vw_pedidos_marketing AS
SELECT p.id          AS pedido,
       p.criado_em,
       c.bairro,
       r.nome        AS restaurante,
       r.categoria,
       p.cupom,
       p.valor_total
  FROM pedidos p
  JOIN clientes c     ON c.id = p.cliente_id
  JOIN restaurantes r ON r.id = p.restaurante_id
 WHERE p.status = 'ENTREGUE';

GRANT SELECT ON rangoja.vw_pedidos_marketing TO 'estagiario_mkt'@'%';
exit
```

Entre como o estagiário (o mesmo da Aula 1):

```bash
mysql -u estagiario_mkt -p'Mkt#Campanha2026' -h 127.0.0.1 rangoja
```

```sql
SELECT cupom, COUNT(*) AS pedidos, ROUND(AVG(valor_total), 2) AS ticket_medio
  FROM vw_pedidos_marketing
 WHERE cupom IS NOT NULL
 GROUP BY cupom
 ORDER BY pedidos DESC;

SELECT nome, cpf FROM clientes LIMIT 1;     -- ERROR 1142
SHOW TABLES;
exit
```

✅ O relatório de cupons funciona, a tabela `clientes` é negada e o `SHOW TABLES` mostra só a
view. O estagiário usa o bairro do cliente sem nunca ver nome, CPF ou senha.

## 2. Trigger: registrar toda mudança de preço

Um trigger é um bloco de SQL que o banco executa sozinho quando algo acontece numa tabela.

```bash
mysql rangoja
```

```sql
CREATE TABLE auditoria_precos (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    produto_id    INT UNSIGNED  NOT NULL,
    preco_antigo  DECIMAL(8,2)  NOT NULL,
    preco_novo    DECIMAL(8,2)  NOT NULL,
    usuario       VARCHAR(100)  NOT NULL,
    alterado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //
CREATE TRIGGER trg_produtos_auditoria
AFTER UPDATE ON produtos
FOR EACH ROW
BEGIN
    IF NEW.preco <> OLD.preco THEN
        INSERT INTO auditoria_precos (produto_id, preco_antigo, preco_novo, usuario)
        VALUES (OLD.id, OLD.preco, NEW.preco, USER());
    END IF;
END//
DELIMITER ;
exit
```

> `DELIMITER //` troca o fim de comando de `;` para `//`, porque o corpo do trigger tem `;` dentro.
> `OLD` é a linha antes da alteração e `NEW`, a linha depois.

O analista de promoções dá 10% de desconto, do jeito certo desta vez:

```bash
mysql -u mkt_promocoes -p'Promo#2026mkt' -h 127.0.0.1 rangoja \
  -e "UPDATE produtos SET preco = ROUND(preco * 0.9, 2) WHERE nome = 'Combo Família'"
mysql rangoja -e "SELECT * FROM auditoria_precos"
```

✅ Uma linha: 89,90 → 80,91, por `mkt_promocoes@localhost`. Ele não tem permissão de `INSERT`
em `auditoria_precos`, mas o trigger roda com as permissões de quem o criou.

## 3. Trigger: barrar desconto acima de 50%

```bash
mysql rangoja
```

```sql
DELIMITER //
CREATE TRIGGER trg_produtos_trava_desconto
BEFORE UPDATE ON produtos
FOR EACH ROW
BEGIN
    IF NEW.preco < OLD.preco * 0.5 THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Desconto acima de 50%: precisa de aprovação do gerente';
    END IF;
END//
DELIMITER ;
exit
```

Agora o erro da Aula 4, de novo:

```bash
mysql -u mkt_promocoes -p'Promo#2026mkt' -h 127.0.0.1 rangoja \
  -e "UPDATE produtos SET preco = 0.01 WHERE nome = 'Combo Família'"
mysql rangoja -e "SELECT nome, preco FROM produtos WHERE nome = 'Combo Família'"
```

✅ `ERROR 1644 (45000): Desconto acima de 50%: precisa de aprovação do gerente`, e o preço
continua 80,91.

> `BEFORE` roda antes de gravar e pode impedir a alteração. `AFTER` roda depois e serve para
> registrar o que já aconteceu.

## 4. Evento: cancelar pedidos abandonados

Um evento é uma tarefa agendada dentro do próprio MySQL.

```bash
mysql rangoja
```

```sql
SELECT @@event_scheduler;          -- ON

SELECT id, criado_em
  FROM pedidos
 WHERE status = 'AGUARDANDO_ENTREGADOR'
 ORDER BY criado_em;
```

✅ 13 pedidos: 10 de ontem (abandonados) e 3 de poucos minutos atrás.

```sql
CREATE EVENT ev_cancela_abandonados
ON SCHEDULE EVERY 1 MINUTE
DO
  UPDATE pedidos
     SET status = 'CANCELADO'
   WHERE status = 'AGUARDANDO_ENTREGADOR'
     AND criado_em < NOW() - INTERVAL 2 HOUR;

SHOW EVENTS\G
```

Espere até um minuto e confira:

```sql
SELECT event_name, last_executed
  FROM information_schema.events
 WHERE event_schema = 'rangoja';

SELECT status, COUNT(*)
  FROM pedidos
 WHERE id BETWEEN 199991 AND 200000 OR criado_em >= NOW() - INTERVAL 2 HOUR
 GROUP BY status;
exit
```

✅ 10 `CANCELADO` e 3 `AGUARDANDO_ENTREGADOR`. Ninguém rodou o `UPDATE`: o agendador do MySQL
rodou sozinho.

## 5. Backup automático com o cron

O MySQL não roda programas do sistema, como o `mysqldump`. Para o backup, quem agenda é o
sistema operacional. No Linux, o agendador é o `cron` (no Windows, o Agendador de Tarefas,
como mostra o livro).

O script já está no servidor:

```bash
cat ~/scripts/backup.sh
~/scripts/backup.sh
ls -lh /backup
cat /backup/backup.log
```

✅ Um arquivo `rangoja-<data>-<hora>.sql.gz` com cerca de 8,6 MB e uma linha no `backup.log`.
O script guarda só os 7 backups mais recentes e apaga os mais antigos.

Agende para rodar a cada minuto, só para ver funcionando:

```bash
echo "* * * * * /home/dba/scripts/backup.sh" | crontab -
crontab -l
```

Espere um ou dois minutos:

```bash
cat /backup/backup.log
ls -lh /backup
```

✅ Linhas novas no log, sem ninguém rodar nada. Agora, o horário de verdade, todo dia às 3h:

```bash
echo "0 3 * * * /home/dba/scripts/backup.sh" | crontab -
crontab -l
```

| Campo | `0 3 * * *` | Significa |
|-------|-------------|-----------|
| minuto | `0` | no minuto 0 |
| hora | `3` | das 3h |
| dia do mês | `*` | todo dia |
| mês | `*` | todo mês |
| dia da semana | `*` | qualquer dia da semana |

> Num servidor de verdade, o script também copiaria o arquivo para fora do servidor (outro
> disco, outra máquina ou a nuvem), como vimos na Aula 2.

---

## Checklist do DBA

- [ ] Quem não precisa de dado pessoal recebe uma view, não a tabela
- [ ] Mudança em dado crítico deixa rastro numa tabela de auditoria
- [ ] Regra de negócio que não pode ser furada vira trigger `BEFORE`
- [ ] Limpeza repetitiva vira evento agendado, não tarefa de alguém
- [ ] Backup agendado no sistema operacional, com retenção e log
- [ ] Toda automação é conferida: `SHOW EVENTS`, `crontab -l`, o log do backup

## Quer repetir?

`docker compose exec servidor aula 5` volta tudo ao estado do início da aula.
