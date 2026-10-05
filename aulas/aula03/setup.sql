-- =====================================================================
-- AULA 3 — A consulta lenta
-- Cenário: na última sprint, o time do app criou a tela "Pedidos perto
-- de você". Para isso, adicionou a coluna bairro_entrega em pedidos...
-- e não criou nenhum índice.
-- Executado pelo professor antes da aula:  docker compose exec servidor aula 3
-- =====================================================================
USE rangoja;

ALTER TABLE pedidos
  ADD COLUMN bairro_entrega VARCHAR(60) NULL AFTER restaurante_id;

UPDATE pedidos p
  JOIN clientes c ON c.id = p.cliente_id
   SET p.bairro_entrega = c.bairro;

ALTER TABLE pedidos MODIFY bairro_entrega VARCHAR(60) NOT NULL;

ANALYZE TABLE pedidos;
