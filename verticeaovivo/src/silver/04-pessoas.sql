-- silver.colaboradores e silver.apontamentos: as 520 pessoas e quanto cada uma
-- trabalhou em cada projeto, semana a semana (o timesheet diz onde a pessoa está).
--
-- A sujeira: 3 pessoas cadastradas duas vezes no RH (mesmo colaborador_id, nome e
-- papel em CAIXA ALTA). DISTINCT não resolve, porque as linhas são diferentes.
-- Ficamos com o cadastro no padrão do sistema (papel em minúsculas). A unicidade
-- é conferida em src/testes/testes.sql.
--
-- apontamentos: a semana do timesheet começa na segunda; a Torre usa a SEXTA
-- (o mesmo dia do status semanal), então semana = segunda + 4 dias.

CREATE OR REFRESH MATERIALIZED VIEW colaboradores (
  CONSTRAINT custo_hora_positivo EXPECT (custo_hora > 0) ON VIOLATION FAIL UPDATE
)
COMMENT 'Colaboradores da Vértice (uma linha por pessoa): papel (dev, qa, sre, tech_lead...), senioridade, custo/hora, admissão e desligamento. Duplicatas do RH removidas.'
AS WITH ordenado AS (
  SELECT *,
         COUNT(*) OVER (PARTITION BY colaborador_id)                                    AS linhas_no_rh,
         row_number() OVER (PARTITION BY colaborador_id
                            ORDER BY CASE WHEN papel = lower(papel) THEN 0 ELSE 1 END)  AS ordem
  FROM lakehouse_vertice.bronze.colaboradores
)
SELECT colaborador_id,
       initcap(lower(nome))                                AS nome,
       lower(papel)                                        AS papel,
       senioridade,
       CAST(custo_hora AS DECIMAL(10,2))                   AS custo_hora,
       CAST(data_admissao AS DATE)                         AS data_admissao,
       try_to_date(data_desligamento, 'yyyy-MM-dd')        AS data_desligamento,
       data_desligamento IS NULL OR data_desligamento = '' AS ativo,
       linhas_no_rh > 1                                    AS cadastro_duplicado
FROM ordenado
WHERE ordem = 1;

CREATE OR REFRESH MATERIALIZED VIEW apontamentos (
  CONSTRAINT horas_nao_negativas EXPECT (horas_apontadas >= 0 AND horas_disponiveis > 0) ON VIOLATION FAIL UPDATE
)
COMMENT 'Timesheet: horas disponíveis x apontadas por pessoa, projeto e semana (semana = sexta). Apontado acima do disponível é hora extra (legítimo).'
AS SELECT
  colaborador_id,
  projeto_id,
  CAST(semana_inicio AS DATE)                                       AS semana_inicio,
  date_add(CAST(semana_inicio AS DATE), 4)                          AS semana,
  CAST(horas_disponiveis AS DOUBLE)                                 AS horas_disponiveis,
  CAST(horas_apontadas AS DOUBLE)                                   AS horas_apontadas,
  CAST(horas_apontadas AS DOUBLE) > CAST(horas_disponiveis AS DOUBLE) AS hora_extra
FROM lakehouse_vertice.bronze.apontamentos;
