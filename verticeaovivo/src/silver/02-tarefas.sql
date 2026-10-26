-- silver.tarefas: AS TRÊS FERRAMENTAS VIRAM UMA. É o coração da noite.
--
-- Cada ferramenta é traduzida para o mesmo contrato de colunas e as três são
-- empilhadas. O projeto vem do DE-PARA (silver.projetos): é ele que diz que o
-- arquivo "Cronograma PRJ-012.xlsx" e a lista 901200095028 do ClickUp são projetos.
--
-- O que cada ferramenta exige:
--   Excel       data em texto OU número de série do Excel; % em '45%', '10,5%' ou 0.45;
--               horas em 132 ou '40h'; a linha de TOTAL no fim; 7 tarefas acima de 100%
--   ClickUp     datas em milissegundos; % e baseline dentro da lista de campos personalizados;
--               status escrito de 12 jeitos; código vazio no PMO → casa pelo nome da lista
--   MS Project  tarefas-resumo (projeto e fases) que somariam as horas três vezes;
--               a fase não está na tarefa, está na tarefa-resumo de cima; horas em 'PT40H0M0S'
--
-- Os EXPECT são o contrato da integração: toda tarefa achou o seu projeto,
-- todo % está entre 0 e 100, toda tarefa tem horas.

CREATE TEMPORARY VIEW tarefas_excel AS
SELECT coalesce(p.projeto_id, regexp_extract(e.arquivo, 'PRJ-[0-9]{3}', 0))   AS projeto_id,
       'excel'                                                                AS ferramenta,
       e.id                                                                   AS id_na_ferramenta,
       lower(e.fase)                                                          AS fase,
       e.tarefa,
       e.responsavel,
       CASE WHEN e.inicio_previsto LIKE '%/%' THEN to_date(e.inicio_previsto, 'dd/MM/yyyy')
            ELSE date_add(DATE'1899-12-30', CAST(e.inicio_previsto AS INT)) END  AS inicio_baseline,
       CASE WHEN e.termino_previsto LIKE '%/%' THEN to_date(e.termino_previsto, 'dd/MM/yyyy')
            ELSE date_add(DATE'1899-12-30', CAST(e.termino_previsto AS INT)) END AS fim_baseline,
       CASE WHEN e.inicio_real LIKE '%/%' THEN to_date(e.inicio_real, 'dd/MM/yyyy')
            ELSE date_add(DATE'1899-12-30', CAST(e.inicio_real AS INT)) END      AS inicio_real,
       CASE WHEN e.termino_real LIKE '%/%' THEN to_date(e.termino_real, 'dd/MM/yyyy')
            ELSE date_add(DATE'1899-12-30', CAST(e.termino_real AS INT)) END     AS fim_real,
       CASE WHEN e.pct_concluido LIKE '%\%%'
            THEN CAST(replace(replace(e.pct_concluido, '%', ''), ',', '.') AS DOUBLE)
            ELSE CAST(e.pct_concluido AS DOUBLE) * 100 END                    AS pct_como_veio,
       CAST(replace(e.horas_previstas, 'h', '') AS DOUBLE)                    AS horas,
       NULL                                                                   AS status_na_ferramenta
FROM lakehouse_vertice.bronze.excel_tarefas e
LEFT JOIN projetos p ON p.ferramenta = 'excel' AND p.codigo_ferramenta = e.arquivo
WHERE e.tarefa <> 'TOTAL';                                  -- a linha que o gerente deixou no fim

CREATE TEMPORARY VIEW tarefas_clickup AS
SELECT p.projeto_id,
       'clickup'                                                                             AS ferramenta,
       c.id                                                                                  AS id_na_ferramenta,
       lower(filter(c.custom_fields, f -> f.name = 'Fase')[0].value)                         AS fase,
       c.name                                                                                AS tarefa,
       c.assignees[0].username                                                               AS responsavel,
       to_date(timestamp_millis(CAST(filter(c.custom_fields, f -> f.name = 'Início baseline')[0].value AS BIGINT))) AS inicio_baseline,
       to_date(timestamp_millis(CAST(filter(c.custom_fields, f -> f.name = 'Fim baseline')[0].value AS BIGINT)))    AS fim_baseline,
       to_date(timestamp_millis(CAST(c.start_date AS BIGINT)))                               AS inicio_real,
       to_date(timestamp_millis(CAST(c.date_done AS BIGINT)))                                AS fim_real,
       CAST(filter(c.custom_fields, f -> f.name = 'Progresso (%)')[0].value AS DOUBLE)      AS pct_como_veio,
       c.time_estimate / 3600000                                                             AS horas,
       CASE WHEN lower(c.status.status) IN ('done', 'concluído', 'closed')      THEN 'concluida'
            WHEN lower(c.status.status) IN ('to do', 'backlog', 'a fazer')      THEN 'a_fazer'
            ELSE 'em_andamento' END                                                          AS status_na_ferramenta
FROM lakehouse_vertice.bronze.clickup_tarefas c
JOIN projetos p
  ON p.ferramenta = 'clickup'
 AND (p.codigo_ferramenta = c.list_id OR (p.codigo_ferramenta IS NULL AND p.nome_projeto = c.list_name));

CREATE TEMPORARY VIEW tarefas_msproject AS
WITH com_fase AS (
  SELECT m.*,
         -- a fase é a última tarefa-resumo de nível 1 que apareceu antes desta tarefa
         last_value(CASE WHEN m.OutlineLevel = 1 THEN m.Name END, true)
           OVER (PARTITION BY m.arquivo ORDER BY m.UID)                            AS fase_da_tarefa
  FROM lakehouse_vertice.bronze.msproject_tarefas m
)
SELECT p.projeto_id,
       'msproject'                                                AS ferramenta,
       CAST(f.UID AS STRING)                                      AS id_na_ferramenta,
       lower(f.fase_da_tarefa)                                    AS fase,
       f.Name                                                     AS tarefa,
       CAST(NULL AS STRING)                                       AS responsavel,
       to_date(f.Baseline.Start)                                  AS inicio_baseline,
       to_date(f.Baseline.Finish)                                 AS fim_baseline,
       to_date(f.ActualStart)                                     AS inicio_real,
       to_date(f.ActualFinish)                                    AS fim_real,
       CAST(f.PercentComplete AS DOUBLE)                          AS pct_como_veio,
       CAST(regexp_extract(f.Work, 'PT([0-9]+)H', 1) AS DOUBLE)   AS horas,
       NULL                                                       AS status_na_ferramenta
FROM com_fase f
JOIN projetos p ON p.ferramenta = 'msproject' AND p.codigo_ferramenta = f.arquivo
WHERE f.Summary = 0;                                         -- só tarefa de verdade, sem as tarefas-resumo

CREATE OR REFRESH MATERIALIZED VIEW tarefas (
  CONSTRAINT achou_o_projeto EXPECT (projeto_id IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT pct_entre_0_e_100 EXPECT (pct_concluido BETWEEN 0 AND 100) ON VIOLATION FAIL UPDATE,
  CONSTRAINT horas_positivas EXPECT (horas > 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT baseline_coerente EXPECT (fim_baseline >= inicio_baseline)
)
COMMENT 'Tarefas de TODOS os projetos num modelo só, vindas do Excel, do ClickUp e do MS Project: fase, baseline, realizado, % concluído (0 a 100) e horas planejadas. É daqui que sai o SPI.'
AS WITH todas AS (
  SELECT * FROM tarefas_excel
  UNION ALL SELECT * FROM tarefas_clickup
  UNION ALL SELECT * FROM tarefas_msproject
)
SELECT concat(projeto_id, '-', ferramenta, '-', id_na_ferramenta) AS tarefa_id,
       projeto_id,
       ferramenta,
       id_na_ferramenta,
       fase,
       tarefa,
       responsavel,
       inicio_baseline,
       fim_baseline,
       inicio_real,
       fim_real,
       least(pct_como_veio, 100)          AS pct_concluido,            -- 107% não existe: vira 100
       pct_como_veio > 100                AS pct_veio_acima_de_100,
       horas,
       status_na_ferramenta
FROM todas;
