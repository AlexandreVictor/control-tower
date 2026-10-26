-- silver.status_semanal e silver.custos.
--
-- status_semanal: o boletim do PMO. Toda sexta, cada gerente publica avanço, farol
-- e bloqueios. É o ÚNICO lugar com o histórico do avanço (as ferramentas só guardam
-- o % de hoje), então a gold usa este % para desenhar a evolução de cada projeto.
--   · farol escrito de 3 jeitos ('Verde', 'VERDE', 'verde') → minúsculas
--   · status não preenchido ('', 'N/A', 'ver ata da reunião') → fica, com a flag status_vazio
--
-- custos: cada lançamento de custo real, em número.
--   · 671 valores com vírgula decimal ('12345,67') → replace antes do CAST.
--     Com try_cast eles virariam NULL e sumiriam do total em silêncio (R$ 5,4 mi).
--   · estorno vem como valor negativo. NÃO é erro: é o lançamento revertido.

CREATE OR REFRESH MATERIALIZED VIEW status_semanal (
  CONSTRAINT farol_conhecido EXPECT (farol IN ('verde', 'amarelo', 'vermelho')) ON VIOLATION FAIL UPDATE,
  CONSTRAINT pct_entre_0_e_100 EXPECT (pct_concluido BETWEEN 0 AND 100) ON VIOLATION FAIL UPDATE
)
COMMENT 'Status semanal de cada projeto (toda sexta): % concluído reportado, farol do gerente (verde, amarelo, vermelho) e o texto livre com os bloqueios. status_vazio marca a semana sem relatório.'
AS SELECT
  projeto_id,
  CAST(data_status AS DATE)                                                  AS data_status,
  gerente,
  lower(trim(farol))                                                         AS farol,
  CAST(pct_concluido AS INT)                                                 AS pct_concluido,
  texto_status,
  coalesce(trim(texto_status), '') IN ('', 'N/A', 'ver ata da reunião')      AS status_vazio
FROM lakehouse_vertice.bronze.status_semanal;

CREATE OR REFRESH MATERIALIZED VIEW custos (
  CONSTRAINT valor_convertido EXPECT (valor IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT data_valida EXPECT (data IS NOT NULL) ON VIOLATION FAIL UPDATE
)
COMMENT 'Lançamentos de custo real por projeto (pessoal, consultoria, cloud, licenças, despesas). Valor em DECIMAL, vírgula decimal corrigida; estornos mantidos e sinalizados.'
AS SELECT
  lancamento_id,
  projeto_id,
  CAST(data AS DATE)                                         AS data,
  date_add(date_trunc('WEEK', CAST(data AS DATE)), 4)        AS semana,          -- sexta da semana
  categoria,
  descricao,
  CAST(replace(valor, ',', '.') AS DECIMAL(18,2))           AS valor,
  CAST(replace(valor, ',', '.') AS DECIMAL(18,2)) < 0       AS estorno,
  valor LIKE '%,%'                                           AS valor_veio_com_virgula,
  centro_custo
FROM lakehouse_vertice.bronze.custos;
