-- Métricas governadas: a fórmula de cada KPI num lugar só.
--
-- A ideação do dono ("qual é o SPI da carteira?") não deve virar SQL — fica aqui,
-- na metric view, e o Genie, o dashboard e o app respondem com MEASURE(...).
-- O SQL com CREATE OR REPLACE VIEW ... WITH METRICS LANGUAGE YAML não sobe no
-- boards do workspace: ele é executado como sql_task ou com scripts/run_sql.py,
-- porque esses caminhos preservam a indentação do YAML.
--
-- ATENÇÃO: a sql_task do job corta este arquivo em todo ';', inclusive dentro
-- do $$ ... $$ do YAML. Nada de ';' aqui dentro (nem em comment).

CREATE OR REPLACE VIEW lakehouse_vertice.gold.mv_projetos WITH METRICS
LANGUAGE YAML
COMMENT 'Fórmulas governadas da Torre de Controle: projetos em andamento com SPI, CPI, EAC, estouro previsto, margem projetada, atraso, farol e melancia. Fonte das respostas do Genie "Farol · Diretoria" e do dashboard.'
AS $$
  version: 1.1
  source: lakehouse_vertice.gold.projeto_situacao_atual
  filter: status = 'em_andamento'

  dimensions:
    - name: projeto_id
      expr: projeto_id
      comment: 'Código do projeto no formato PRJ-xxx'
      synonyms:
        - 'código do projeto'
    - name: projeto
      expr: projeto
      comment: 'Código seguido do nome do projeto (PRJ-xxx · nome)'
      synonyms:
        - 'nome do projeto'
    - name: cliente
      expr: cliente
      comment: 'Cliente que contratou o projeto'
      synonyms:
        - 'clientes'
    - name: segmento
      expr: segmento
      comment: 'Segmento de mercado do cliente: varejo, financeiro, saúde, logística ou indústria'
      synonyms:
        - 'segmento do cliente'
        - 'mercado'
        - 'varejo'
        - 'e-commerce'
    - name: ferramenta
      expr: ferramenta
      comment: 'Ferramenta usada pelo gerente para controlar o projeto: excel, clickup ou msproject'
      synonyms:
        - 'ferramenta de gestão'
        - 'planilha'
    - name: situacao
      expr: situacao
      comment: 'Situação de risco do projeto em andamento: crítico quando SPI ou CPI < 0,8; atenção quando < 0,9; ok no restante'
      synonyms:
        - 'situação'
        - 'em risco'
        - 'em atenção'
        - 'em crítico'
    - name: farol_do_gerente
      expr: farol_do_gerente
      comment: 'Farol (verde, amarelo ou vermelho) reportado pelo gerente na última sexta'
      synonyms:
        - 'farol reportado'
        - 'farol do gerente'
    - name: farol_calculado
      expr: farol_calculado
      comment: 'Farol calculado pela regra do manual da Vértice: verde com SPI >= 0,95; amarelo com SPI >= 0,90; vermelho abaixo de 0,90'
      synonyms:
        - 'farol real'
        - 'farol calculado'
    - name: gerente_projeto
      expr: gerente_projeto
      comment: 'Gerente responsável pelo projeto'

  measures:
    - name: projetos
      expr: COUNT(*)
      comment: 'Quantidade de projetos em andamento'
      synonyms:
        - 'quantidade de projetos'
    - name: carteira
      expr: SUM(valor_contrato)
      comment: 'Valor dos contratos em andamento, em reais'
      synonyms:
        - 'valor da carteira'
        - 'contrato'
    - name: spi
      expr: SUM(ev) / NULLIF(SUM(pv), 0)
      comment: 'SPI da carteira: EV somado dividido por PV somado. Abaixo de 0,9 é atenção; abaixo de 0,8 é crítico'
      synonyms:
        - 'índice de desempenho de cronograma'
        - 'atraso'
    - name: cpi
      expr: SUM(ev) / NULLIF(SUM(ac), 0)
      comment: 'CPI da carteira: EV somado dividido por AC somado. Abaixo de 1 mexe no EAC para cima'
      synonyms:
        - 'índice de desempenho de custo'
        - 'estouro'
    - name: eac
      expr: SUM(eac)
      comment: 'EAC somado: orçamento no prazo total dividido pelo CPI de cada projeto, em reais'
      synonyms:
        - 'estimativa para concluir'
    - name: estouro_previsto
      expr: SUM(estouro_previsto)
      comment: 'Estouro previsto somado: EAC menos orçamento, só quando positivo, em reais'
      synonyms:
        - 'estouro'
        - 'prejuízo previsto'
    - name: margem_projetada
      expr: (SUM(valor_contrato) - SUM(eac)) / NULLIF(SUM(valor_contrato), 0)
      comment: 'Margem projetada da carteira: contrato somado menos EAC somado, dividido pelo contrato somado'
      synonyms:
        - 'margem'
    - name: atraso_projetado_medio_dias
      expr: AVG(atraso_projetado_dias)
      comment: 'Atraso projetado médio em dias: média de (duração do baseline dividido por SPI) menos a duração do baseline'
      synonyms:
        - 'atraso médio'
    - name: projetos_em_risco
      expr: COUNT(*) FILTER (WHERE situacao <> 'ok')
      comment: 'Projetos em andamento com situação de atenção ou crítico'
      synonyms:
        - 'em risco'
    - name: projetos_criticos
      expr: COUNT(*) FILTER (WHERE situacao = 'crítico')
      comment: 'Projetos em andamento com SPI ou CPI abaixo de 0,8'
      synonyms:
        - 'críticos'
    - name: projetos_melancia
      expr: COUNT(*) FILTER (WHERE melancia)
      comment: 'Melancias: farol do gerente verde com SPI abaixo de 0,9 (bonita por fora, nada saudável por dentro)'
      synonyms:
        - 'melancia'
        - 'farol verde atrasado'
$$;
