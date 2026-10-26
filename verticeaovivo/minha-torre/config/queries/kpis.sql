-- KPIs da carteira em andamento (Projeto Farol).
-- Fonte: lakehouse_vertice.gold.projeto_situacao_atual
-- O score de estouro (gold.score_estouro_30d) NÃO entra aqui: ele pode não existir.
SELECT
  COUNT_IF(status = 'em_andamento') AS projetos_em_andamento,
  COUNT_IF(status = 'em_andamento' AND situacao IN ('atenção', 'crítico')) AS projetos_em_risco,
  COUNT_IF(status = 'em_andamento' AND situacao = 'crítico') AS projetos_criticos,
  COUNT_IF(status = 'em_andamento' AND situacao = 'atenção') AS projetos_atencao,
  COALESCE(SUM(CASE WHEN status = 'em_andamento' THEN estouro_previsto ELSE 0 END), 0) AS estouro_previsto_total,
  COALESCE(SUM(CASE WHEN status = 'em_andamento' THEN valor_contrato ELSE 0 END), 0) AS carteira_total
FROM lakehouse_vertice.gold.projeto_situacao_atual;
