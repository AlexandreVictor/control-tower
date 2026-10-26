-- silver.projetos: o cadastro do PMO, tipado. É o DE-PARA da integração:
-- diz em qual ferramenta cada projeto vive e com qual código.
--
-- Sujeiras resolvidas aqui:
--   · data_inicio em dois formatos (2025-03-14 e 14/03/2025) → coalesce de dois try_to_date
--   · a ferramenta escrita de 8 jeitos ('Excel', 'excel', 'Planilha', 'click up'...) → 3 valores
--   · código da ferramenta vazio em 2 projetos → fica nulo; a silver.tarefas casa pelo nome
-- O EXPECT é o contrato: se aparecer uma ferramenta nova, o pipeline PARA.

CREATE OR REFRESH MATERIALIZED VIEW projetos (
  CONSTRAINT data_inicio_valida EXPECT (data_inicio IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ferramenta_conhecida EXPECT (ferramenta IN ('excel', 'clickup', 'msproject')) ON VIOLATION FAIL UPDATE,
  CONSTRAINT prazo_depois_do_inicio EXPECT (data_fim_baseline > data_inicio)
)
COMMENT 'Projetos da carteira da Vértice (cadastro do PMO): cliente, segmento, valor, prazo e em qual ferramenta cada projeto é gerenciado (excel, clickup ou msproject).'
AS SELECT
  projeto_id,
  nome_projeto,
  cliente,
  segmento,
  tipo_projeto,
  CASE WHEN lower(ferramenta) LIKE '%excel%' OR lower(ferramenta) LIKE '%planilha%' THEN 'excel'
       WHEN replace(lower(ferramenta), ' ', '') LIKE '%clickup%'                      THEN 'clickup'
       WHEN lower(ferramenta) LIKE '%project%'                                         THEN 'msproject'
  END                                                     AS ferramenta,
  ferramenta                                              AS ferramenta_como_veio,
  nullif(trim(codigo_ferramenta), '')                     AS codigo_ferramenta,
  CAST(valor_contrato  AS DECIMAL(18,2))                  AS valor_contrato,
  CAST(orcamento_custo AS DECIMAL(18,2))                  AS orcamento,
  coalesce(try_to_date(data_inicio, 'yyyy-MM-dd'),
           try_to_date(data_inicio, 'dd/MM/yyyy'))        AS data_inicio,
  CAST(data_fim_baseline AS DATE)                         AS data_fim_baseline,
  status,
  gerente_projeto
FROM lakehouse_vertice.bronze.projetos;
