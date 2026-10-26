#!/usr/bin/env python3
"""Gera resources/farol.geniespace.json (serialized_space versão 2) do espaço
Genie "Farol · Diretoria".

Uso:
  python3 scripts/gerar_genie.py [--profile DEFAULT]

Escreve o arquivo que o recurso `genie_farol` (resources/genie.genie_space.yml)
publica no deploy. Os ids são de 32 caracteres hex, únicos e gerados em ordem.

gold.score_estouro_30d (o modelo da noite 4) entra SÓ se existir: confira com
  databricks tables exists lakehouse_vertice.gold.score_estouro_30d --profile <perfil>
Sem ela, nada de instrução nem exemplo sobre score.
"""
import argparse
import json
import subprocess
import uuid
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "resources" / "farol.geniespace.json"

TABELAS = [
    "lakehouse_vertice.gold.fato_projeto_semana",
    "lakehouse_vertice.gold.projeto_situacao_atual",
    "lakehouse_vertice.gold.status_estruturado",
    "lakehouse_vertice.gold.utilizacao_pessoa_semana",
    "lakehouse_vertice.silver.entregas_fornecedor",
    "lakehouse_vertice.gold.mv_projetos",
]
TABELA_SCORE = "lakehouse_vertice.gold.score_estouro_30d"

HOJE = "DATE'2026-10-16'"
ULT_90 = "DATE'2026-07-18'"
ULT_12_SEMANAS = "DATE'2026-07-24'"

# As 4 perguntas que o dono fez — cada uma com um exemplo de SQL.
PERGUNTAS_E_SQL = {
    "Quais projetos estão atrasados, e de quais clientes?": """
SELECT
  projeto,
  cliente,
  situacao,
  farol_do_gerente,
  farol_calculado,
  ROUND(spi, 2) AS spi,
  ROUND(cpi, 2) AS cpi,
  atraso_projetado_dias
FROM lakehouse_vertice.gold.projeto_situacao_atual
WHERE status = 'em_andamento'
  AND situacao <> 'ok'
ORDER BY atraso_projetado_dias DESC""",
    "Quanto esse atraso vai me custar?": """
SELECT
  ROUND(MEASURE(estouro_previsto), 0) AS estouro_previsto,
  ROUND(MEASURE(margem_projetada), 4) AS margem_projetada
FROM lakehouse_vertice.gold.mv_projetos""",
    "Tenho gente parada enquanto outro projeto pede gente?": """
SELECT
  colaborador_id,
  nome,
  papel,
  projeto,
  ROUND(SUM(horas_apontadas) / NULLIF(SUM(horas_disponiveis), 0), 4) AS utilizacao_12_semanas,
  SUM(horas_ociosas)                                                AS horas_ociosas,
  SUM(custo_ocioso)                                                 AS custo_ocioso
FROM lakehouse_vertice.gold.utilizacao_pessoa_semana
WHERE semana > DATE'2026-07-24'
GROUP BY colaborador_id, nome, papel, projeto
HAVING utilizacao_12_semanas < 0.2
ORDER BY custo_ocioso DESC""",
    "O que vai dar errado no próximo mês?": """
SELECT
  e.projeto_id,
  p.projeto,
  e.fornecedor,
  e.item,
  e.data_prometida,
  e.dias_de_atraso_na_entrega
FROM lakehouse_vertice.silver.entregas_fornecedor e
JOIN lakehouse_vertice.gold.projeto_situacao_atual p
  ON p.projeto_id = e.projeto_id
WHERE e.em_atraso
ORDER BY e.dias_de_atraso_na_entrega DESC""",
}

# Só entram se o score existir.
PONTO_SCORE = """
* gold.score_estouro_30d é a previsão do modelo: probabilidade (prob_estouro_30d) de o projeto estourar o orçamento no próximo mês, com faixa_risco (alto na >= 0,5, medio na >= 0,2, baixo), ranking, principais_fatores e data_referencia. Para o score "de hoje" use a data_referencia mais recente. No "o que vai dar errado no próximo mês", junte também os projetos com situacao = 'ok' e faixa_risco alto ou medio, mostrando os principais_fatores. Projeto já abaixo de 0,9 hoje tem probabilidade 1,0."""

SQL_SCORE_EXEMPLO = """
SELECT
  projeto_id,
  prob_estouro_30d,
  faixa_risco,
  principais_fatores
FROM lakehouse_vertice.gold.score_estouro_30d
WHERE situacao = 'ok'
  AND faixa_risco IN ('alto', 'medio')
  AND data_referencia = (SELECT MAX(data_referencia)
                         FROM lakehouse_vertice.gold.score_estouro_30d)
ORDER BY prob_estouro_30d DESC"""

PERGUNTA_SCORE = "Qual a chance de o PRJ-024 estourar?"


def bloco(texto: str) -> list:
    """Array no formato do serialized_space: cada linha termina com \\n, menos a última."""
    linhas = texto.strip("\n").split("\n")
    return [l + "\n" for l in linhas[:-1]] + [linhas[-1]]


def score_existe(profile: str) -> bool:
    r = subprocess.run(
        ["databricks", "tables", "exists", TABELA_SCORE, "--profile", profile],
        capture_output=True, text=True)
    try:
        return json.loads(r.stdout).get("table_exists") is True
    except (ValueError, AttributeError):
        return False


def gerar(profile: str) -> dict:
    tabelas = list(TABELAS)
    botoes = ""
    exemplos = list(PERGUNTAS_E_SQL.items())

    if score_existe(profile):
        print(f"score encontrado: {TABELA_SCORE} entra no espaço")
        tabelas.append(TABELA_SCORE)
        botoes = PONTO_SCORE
        exemplos.append((PERGUNTA_SCORE, SQL_SCORE_EXEMPLO))
    else:
        print(f"score não existe: {TABELA_SCORE} fora do espaço (nem instrução, nem exemplo)")

    instrucao = f"""* Quem pergunta é o dono da Vértice Tecnologia e a diretoria: responda em português claro, sem jargão, e mostre a conta por trás dos números quando fizer sentido.
* HOJE é {HOJE} (sexta-feira). Nunca use current_date(): todo número congelou nessa data e tem que bater com a Torre e com o job.
* Janelas de tempo fixas: "últimos 90 dias" = data_status >= {ULT_90}. "Últimas 12 semanas" = semana > {ULT_12_SEMANAS}. "Próximo mês" = da data de hoje até 2026-11-15 (30 dias à frente).
* Fórmula de cada KPI: SPI = EV / PV. CPI = EV / AC. EAC = orçamento / CPI. Estouro previsto = EAC - orçamento, só quando positivo. Margem projetada = (valor do contrato - EAC) / valor do contrato. Atraso projetado em dias = duração do baseline / SPI - duração do baseline.
* Regras de corte: SPI ou CPI < 0,9 = atenção, e < 0,8 = crítico. Farol calculado (manual da Vértice): verde com SPI >= 0,95, amarelo com SPI >= 0,90, vermelho abaixo de 0,90.
* Melancia: farol do gerente verde com SPI < 0,9 (bonita por fora, nada saudável por dentro). Aponte melancias em toda resposta de risco.
* Totais da carteira (quantos, SPI, CPI, estouro, margem, atraso médio) SEMPRE da metric view lakehouse_vertice.gold.mv_projetos com MEASURE(...): é lá que as fórmulas moram. Ranking e detalhe por projeto (contrato, datas, farol, gerente, cliente) vêm de lakehouse_vertice.gold.projeto_situacao_atual.
* Referências a códigos (PRJ-011, COL0102) são IGUALDADE: projeto_id = 'PRJ-011', colaborador_id = 'COL0102'. Nunca use ILIKE/LIKE para buscar um código — ILIKE '%PRJ-011%' traz projetos demais.
* "Código do projeto" na resposta é a coluna projeto, que traz 'PRJ-xxx · nome' (só projeto_id é o código puro).
* Os valores da coluna situacao levam acento: 'ok', 'atenção', 'crítico' (e 'concluído' fora de em_andamento). Use 'atenção' e 'crítico' exatamente assim — sem acento não existe.
* SPI, CPI, EAC, estouro previsto, margem e atraso de UM projeto específico vem da fotografia de hoje (projeto_situacao_atual), não do fato semanal: gold.fato_projeto_semana é só para a evolução por semana.
* Na lakehouse_vertice.gold.fato_projeto_semana, PV, EV e AC são ACUMULADOS até a semana: NUNCA some valores de semanas diferentes (SUM(pv) numa agregação por semana dobraria o PV). Para o estado acumulado de um projeto, pegue a linha da última semana do período. A última semana do dataset é {HOJE}.
* "Por que o projeto X atrasou?" responda com lakehouse_vertice.gold.status_estruturado dos últimos 90 dias, descartando causa_bloqueio 'sem_bloqueio' e 'nao_reportado': agrupe por causa, conte as semanas e some os dias_impacto. Se a causa principal for falta_sre, traga também os SREs com utilização < 20% nas últimas 12 semanas (são eles que destravam).
* "Tenho gente parada?" = pessoa com utilização < 0,2 nas últimas 12 semanas: em gold.utilizacao_pessoa_semana, agrupado por colaborador, SUM(horas_apontadas) / SUM(horas_disponiveis) com HAVING abaixo de 0,2. Mostre papel, projeto, horas ociosas e custo ocioso (custo_ocioso, em reais).
* Fornecedor: índice de atraso = prazo real ÷ prazo prometido, na lakehouse_vertice.silver.entregas_fornecedor (AVG(prazo_real_dias) / AVG(prazo_prometido_dias) por fornecedor). A CodeForge Consultoria Ltda marca 1,41: nenhuma entrega no prazo.
* "O que vai dar errado no próximo mês?" junta dois sinais: (1) as entregas de consultoria em atraso hoje (silver.entregas_fornecedor WHERE em_atraso, com projeto, fornecedor e dias de atraso) e (2) o change freeze do varejo de 01/11/2026 a 10/01/2027 nos projetos de e-commerce em andamento (status = 'em_andamento' e lower(tipo_projeto) com commerce, checkout ou marketplace) — cronograma não avança nessa janela, então o atraso projetado só cresce.
* "Quais clientes ...?" devolve cada cliente UMA vez (SELECT DISTINCT cliente).
* Toda resposta termina com uma ação sugerida ao dono: onde agir primeiro, com números, em reais quando couber.""" + botoes

    ids = iter(uuid.uuid4() for _ in range(40))

    espaco = {
        "version": 2,
        "config": {
            "sample_questions": [
                {"id": ids.__next__().hex, "question": [p]} for p, _ in exemplos
            ]
        },
        "data_sources": {
            "tables": [{"identifier": t} for t in sorted(tabelas)]
        },
        "instructions": {
            "example_question_sqls": [
                {"id": ids.__next__().hex, "question": [p], "sql": bloco(s)}
                for p, s in exemplos
            ],
            "text_instructions": [
                {"id": ids.__next__().hex, "content": bloco(instrucao)}
            ],
        },
    }

    # A API exige cada lista ordenada: data_sources por identifier, demais por id.
    for lista in ("sample_questions",):
        espaco["config"][lista].sort(key=lambda x: x["id"])
    for lista in ("example_question_sqls", "text_instructions"):
        espaco["instructions"][lista].sort(key=lambda x: x["id"])

    SAIDA.write_text(json.dumps(espaco, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"gerado: {SAIDA.relative_to(RAIZ)} ({len(tabelas)} tabelas, {len(exemplos)} perguntas)")
    return espaco


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default="DEFAULT")
    a = ap.parse_args()
    gerar(a.profile)
