-- =====================================================================
-- AULA 5 — Deixe o banco trabalhar sozinho  |  comandos na ordem do roteiro
-- Linhas que começam com "-- $" são comandos do terminal (fora do mysql).
-- Terminal:  ssh dba@localhost -p 2222   (senha: dba)
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOCO 2 — Uma view para o marketing, sem dados pessoais
-- ---------------------------------------------------------------------
-- $ mysql rangoja
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
SHOW GRANTS FOR 'estagiario_mkt'@'%';
-- exit

-- $ mysql -u estagiario_mkt -p'Mkt#Campanha2026' -h 127.0.0.1 rangoja
SELECT cupom, COUNT(*) AS pedidos, ROUND(AVG(valor_total), 2) AS ticket_medio
  FROM vw_pedidos_marketing
 WHERE cupom IS NOT NULL
 GROUP BY cupom
 ORDER BY pedidos DESC;

SELECT nome, cpf FROM clientes LIMIT 1;            -- ERROR 1142
SHOW TABLES;                                       -- só a view aparece
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 3 — Trigger: registrar toda mudança de preço
-- ---------------------------------------------------------------------
-- $ mysql rangoja
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

SHOW TRIGGERS\G
-- exit

-- O analista de promoções dá um desconto de 10%, do jeito certo desta vez
-- $ mysql -u mkt_promocoes -p'Promo#2026mkt' -h 127.0.0.1 rangoja
UPDATE produtos SET preco = ROUND(preco * 0.9, 2) WHERE nome = 'Combo Família';
-- exit

-- $ mysql rangoja
SELECT * FROM auditoria_precos;
-- 89.90 -> 80.91 | mkt_promocoes@localhost

-- ---------------------------------------------------------------------
-- BLOCO 4 — Trigger: barrar desconto acima de 50%
-- ---------------------------------------------------------------------
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
-- exit

-- O erro da Aula 4, de novo
-- $ mysql -u mkt_promocoes -p'Promo#2026mkt' -h 127.0.0.1 rangoja
UPDATE produtos SET preco = 0.01 WHERE nome = 'Combo Família';
-- ERROR 1644 (45000): Desconto acima de 50%: precisa de aprovação do gerente
SELECT nome, preco FROM produtos WHERE nome = 'Combo Família';   -- 80.91
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 5 — Evento: cancelar pedidos abandonados
-- ---------------------------------------------------------------------
-- $ mysql rangoja
SELECT @@event_scheduler;                          -- ON

SELECT id, criado_em
  FROM pedidos
 WHERE status = 'AGUARDANDO_ENTREGADOR'
 ORDER BY criado_em;                               -- 10 de ontem, 3 de agora há pouco

CREATE EVENT ev_cancela_abandonados
ON SCHEDULE EVERY 1 MINUTE
DO
  UPDATE pedidos
     SET status = 'CANCELADO'
   WHERE status = 'AGUARDANDO_ENTREGADOR'
     AND criado_em < NOW() - INTERVAL 2 HOUR;

SHOW EVENTS\G

-- (espere até 1 minuto)
SELECT event_name, last_executed
  FROM information_schema.events
 WHERE event_schema = 'rangoja';

SELECT status, COUNT(*)
  FROM pedidos
 WHERE id BETWEEN 199991 AND 200000 OR criado_em >= NOW() - INTERVAL 2 HOUR
 GROUP BY status;                                  -- 10 CANCELADO, 3 AGUARDANDO
-- exit

-- ---------------------------------------------------------------------
-- BLOCO 6 — Backup automático com o cron
-- ---------------------------------------------------------------------
-- $ cat ~/scripts/backup.sh
-- $ ~/scripts/backup.sh
-- $ ls -lh /backup
-- $ cat /backup/backup.log

-- Agendar para rodar a cada minuto (só para ver funcionando)
-- $ echo "* * * * * /home/dba/scripts/backup.sh" | crontab -
-- $ crontab -l
-- (espere 1 ou 2 minutos)
-- $ cat /backup/backup.log
-- $ ls -lh /backup

-- Agora, o horário de verdade: todo dia às 3h
-- $ echo "0 3 * * * /home/dba/scripts/backup.sh" | crontab -
-- $ crontab -l
