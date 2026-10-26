-- silver.entregas_fornecedor: o que as consultorias prometem entregar, e quando entregam.
--
-- Sujeiras resolvidas aqui:
--   · a MESMA consultoria digitada de quatro jeitos ('CodeForge Consultoria Ltda',
--     'Codeforge Consultoria', 'CODEFORGE CONSULTORIA LTDA', 'Code Forge Consultoria').
--     Sem normalizar, ela vira quatro fornecedores medianos — e o pior fornecedor
--     da carteira some do ranking.
--   · data_entrega vazia NÃO é sujeira: é entrega ainda em aberto.

CREATE OR REFRESH MATERIALIZED VIEW entregas_fornecedor (
  CONSTRAINT fornecedor_normalizado EXPECT (fornecedor IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT promessa_depois_do_pedido EXPECT (data_prometida >= data_pedido)
)
COMMENT 'Entregas das consultorias por projeto: fornecedor normalizado, valor, prazo prometido x real, em aberto e em atraso (prometida antes de 16/10/2026 e não entregue).'
AS SELECT
  entrega_id,
  projeto_id,
  CASE WHEN replace(lower(fornecedor), ' ', '') LIKE '%codeforge%' THEN 'CodeForge Consultoria Ltda'
       ELSE fornecedor END                                                AS fornecedor,
  fornecedor                                                              AS fornecedor_como_veio,
  item,
  CAST(valor AS DECIMAL(18,2))                                            AS valor,
  CAST(data_pedido AS DATE)                                               AS data_pedido,
  CAST(data_prometida AS DATE)                                            AS data_prometida,
  try_to_date(data_entrega, 'yyyy-MM-dd')                                 AS data_entrega,
  CAST(prazo_contratado_dias AS INT)                                      AS prazo_prometido_dias,
  datediff(try_to_date(data_entrega, 'yyyy-MM-dd'), CAST(data_pedido AS DATE)) AS prazo_real_dias,
  datediff(try_to_date(data_entrega, 'yyyy-MM-dd'), CAST(data_prometida AS DATE)) AS dias_de_atraso_na_entrega,
  status = 'em_aberto'                                                    AS em_aberto,
  status = 'em_aberto' AND CAST(data_prometida AS DATE) < DATE'2026-10-16' AS em_atraso
FROM lakehouse_vertice.bronze.entregas_fornecedor;
