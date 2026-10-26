-- Projetos em andamento, do pior para o melhor (crítico -> atenção -> ok),
-- cruzados com a causa mais frequente dos últimos 90 dias em status_estruturado
-- e com os dias de impacto por falta de SRE e por rotatividade.
-- O "hoje" do dataset é sempre DATE'2026-10-16' (nunca current_date()).
WITH causa_90d AS (
  SELECT
    projeto_id,
    causa_bloqueio AS causa_mais_frequente,
    ROW_NUMBER() OVER (
      PARTITION BY projeto_id
      ORDER BY COUNT(*) DESC, MAX(data_status) DESC
    ) AS rn
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATEADD(day, -90, DATE'2026-10-16')
    AND causa_bloqueio <> 'sem_bloqueio'
  GROUP BY projeto_id, causa_bloqueio
),
impacto_90d AS (
  SELECT
    projeto_id,
    COALESCE(SUM(CASE WHEN causa_bloqueio = 'falta_sre' THEN dias_impacto ELSE 0 END), 0) AS dias_falta_sre,
    COALESCE(SUM(CASE WHEN causa_bloqueio = 'rotatividade' THEN dias_impacto ELSE 0 END), 0) AS dias_rotatividade
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATEADD(day, -90, DATE'2026-10-16')
  GROUP BY projeto_id
)
SELECT
  p.projeto_id,
  p.nome_projeto,
  p.cliente,
  p.gerente_projeto,
  p.situacao,
  p.spi,
  p.cpi,
  p.estouro_previsto,
  p.atraso_projetado_dias,
  p.farol_do_gerente,
  p.farol_calculado,
  c.causa_mais_frequente,
  COALESCE(i.dias_falta_sre, 0) AS dias_falta_sre,
  COALESCE(i.dias_rotatividade, 0) AS dias_rotatividade
FROM lakehouse_vertice.gold.projeto_situacao_atual p
LEFT JOIN causa_90d c ON p.projeto_id = c.projeto_id AND c.rn = 1
LEFT JOIN impacto_90d i ON p.projeto_id = i.projeto_id
WHERE p.status = 'em_andamento'
ORDER BY
  CASE p.situacao WHEN 'crítico' THEN 1 WHEN 'atenção' THEN 2 ELSE 3 END,
  p.spi ASC;
