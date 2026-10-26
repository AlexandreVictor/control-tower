-- gold.status_estruturado: estruturação e enriquecimento do texto livre de status
-- usando funções de IA do Databricks (versão 2.0) e fallbacks por regras/palavras-chave.

-- 1. Criação da tabela acumulativa (NÃO é CREATE OR REPLACE)
CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id STRING COMMENT 'Identificador único do projeto',
  data_status DATE COMMENT 'Data do reporte semanal (geralmente sexta-feira)',
  farol STRING COMMENT 'Farol do status reportado (verde, amarelo, vermelho)',
  causa_bloqueio STRING COMMENT 'Causa categorizada do bloqueio (ex: change_freeze, falta_sre, sem_bloqueio, etc)',
  bloqueio STRING COMMENT 'Descrição suscinta do bloqueio extraída pelo modelo',
  quem_destrava STRING COMMENT 'Área, pessoa ou papel responsável pelo desbloqueio',
  dias_impacto DOUBLE COMMENT 'Estimativa em dias de atraso ou impacto gerado pelo bloqueio',
  metodo STRING COMMENT 'Método utilizado na classificação: regra, ia ou palavra_chave',
  texto_status STRING COMMENT 'Texto original livre informado no reporte de status',
  _classificado_em TIMESTAMP COMMENT 'Timestamp do momento da classificação e carga'
)
COMMENT 'Tabela analítica de status semanal estruturado com extração de bloqueios, impactos e causas via IA e regras.';

-- 2. Carga incremental dos status novos via MERGE INTO
MERGE INTO lakehouse_vertice.gold.status_estruturado AS target
USING (
  WITH novos_status AS (
    SELECT
      s.projeto_id,
      s.data_status,
      s.farol,
      s.texto_status,
      s.status_vazio,
      lower(coalesce(s.texto_status, '')) AS texto_lower
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado g
      ON s.projeto_id = g.projeto_id
     AND s.data_status = g.data_status
  ),
  metodos_definidos AS (
    SELECT
      *,
      CASE
        WHEN status_vazio
          OR texto_lower LIKE '%bloqueios: nenhum%'
          OR texto_lower LIKE '%sem bloqueios%'
          OR texto_lower LIKE '%nada relevante%'
        THEN 'regra'
        WHEN data_status >= DATE'2026-07-18'
        THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo
    FROM novos_status
  ),
  classificacao_ia AS (
    SELECT
      *,
      -- Chamada de IA só para quem tem metodo = 'ia'
      -- ai_classify v2.0 aceita lista de labels como string JSON e retorna VARIANT acessado com :response
      CASE
        WHEN metodo = 'ia' THEN
          coalesce(
            ai_classify(
              texto_status,
              '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
              map('version', '2.0')
            ):response[0]::string,
            ai_classify(
              texto_status,
              '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
              map('version', '2.0')
            ):response::string
          )
        ELSE NULL
      END AS ia_causa,
      CASE
        WHEN metodo = 'ia' THEN
          ai_extract(
            texto_status,
            '{"bloqueio": {"type": "string"}, "quem_destrava": {"type": "string"}, "dias_impacto": {"type": "number", "description": "1 semana = 7"}}',
            map('version', '2.0')
          ):response
        ELSE NULL
      END AS ia_extraido
    FROM metodos_definidos
  )
  SELECT
    projeto_id,
    data_status,
    farol,
    CASE
      WHEN status_vazio THEN 'nao_reportado'
      WHEN metodo = 'regra' THEN 'sem_bloqueio'
      WHEN metodo = 'ia' THEN coalesce(ia_causa, 'sem_bloqueio')
      -- Classificação por palavra-chave com RLIKE
      WHEN texto_lower RLIKE 'freeze|congelamento|janela de deploy' THEN 'change_freeze'
      WHEN texto_lower RLIKE 'sre|infraestrutura|ambiente de homologação' THEN 'falta_sre'
      WHEN texto_lower RLIKE 'forge|consultoria|fornecedor' THEN 'dependencia_fornecedor'
      WHEN texto_lower RLIKE 'saída de|rotatividade|onboarding' THEN 'rotatividade'
      WHEN texto_lower RLIKE 'escopo|change request|regra de negócio' THEN 'mudanca_escopo'
      WHEN texto_lower RLIKE 'bugs|regressão|refazendo' THEN 'bug_retrabalho'
      WHEN texto_lower RLIKE 'aprovação do cliente|homologação do cliente' THEN 'aprovacao_cliente'
      ELSE 'sem_bloqueio'
    END AS causa_bloqueio,
    CASE
      WHEN metodo = 'ia' THEN ia_extraido:bloqueio::string
      ELSE NULL
    END AS bloqueio,
    CASE
      WHEN metodo = 'ia' THEN ia_extraido:quem_destrava::string
      ELSE NULL
    END AS quem_destrava,
    CASE
      WHEN metodo = 'ia' THEN CAST(ia_extraido:dias_impacto AS DOUBLE)
      WHEN texto_lower LIKE '%impacto estimado: 1 semana%' THEN 7.0
      WHEN regexp_extract(texto_lower, 'impacto estimado de ([0-9]+) dias', 1) <> '' THEN
        CAST(regexp_extract(texto_lower, 'impacto estimado de ([0-9]+) dias', 1) AS DOUBLE)
      ELSE NULL
    END AS dias_impacto,
    metodo,
    texto_status,
    current_timestamp() AS _classificado_em
  FROM classificacao_ia
) AS source
ON target.projeto_id = source.projeto_id
AND target.data_status = source.data_status
WHEN NOT MATCHED THEN INSERT (
  projeto_id,
  data_status,
  farol,
  causa_bloqueio,
  bloqueio,
  quem_destrava,
  dias_impacto,
  metodo,
  texto_status,
  _classificado_em
) VALUES (
  source.projeto_id,
  source.data_status,
  source.farol,
  source.causa_bloqueio,
  source.bloqueio,
  source.quem_destrava,
  source.dias_impacto,
  source.metodo,
  source.texto_status,
  source._classificado_em
);

-- 3. Leitura final: contagem de status por metodo e causa
SELECT
  metodo,
  causa_bloqueio,
  COUNT(*) AS total_status
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, total_status DESC;
