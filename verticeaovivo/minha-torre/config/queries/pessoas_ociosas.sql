-- Pessoas com taxa de utilização abaixo de 20% nas últimas 12 semanas,
-- com médias semanais de horas paradas e de custo ocioso, mais o custo/hora.
-- O "hoje" do dataset é sempre DATE'2026-10-16' (nunca current_date()).
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  custo_hora,
  ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 4) AS taxa_utilizacao,
  ROUND(AVG(horas_ociosas), 2) AS horas_ociosas_media_sem,
  ROUND(AVG(custo_ocioso), 2) AS custo_ocioso_medio_sem
FROM lakehouse_vertice.gold.utilizacao_pessoa_semana
WHERE semana >= DATEADD(week, -12, DATE'2026-10-16')
GROUP BY colaborador_id, nome, papel, senioridade, custo_hora
HAVING (SUM(horas_apontadas) / SUM(horas_disponiveis)) < 0.20
ORDER BY custo_ocioso_medio_sem DESC;
