import { createApp, analytics, genie, server } from '@databricks/appkit';

const TABELA_SCORE = 'lakehouse_vertice.gold.score_estouro_30d';

type Linha = Record<string, unknown>;

/**
 * `analytics.query()` devolve o `result` da statement (objeto com `data`),
 * mas em alguns caminhos devolve o array direto. Normaliza para sempre
 * termos um array de linhas.
 */
function paraLinhas(resultado: unknown): Linha[] {
  if (Array.isArray(resultado)) return resultado as Linha[];
  if (resultado && typeof resultado === 'object') {
    const data = (resultado as { data?: unknown }).data;
    if (Array.isArray(data)) return data as Linha[];
  }
  return [];
}

await createApp({
  // Sem cache: o Farol precisa mostrar a carteira do jeito que está na gold.
  cache: { enabled: false },
  plugins: [analytics({}), genie(), server()],
  onPluginsReady(appkit) {
    appkit.server.extend((app) => {
      /**
       * Probabilidade de estouro por projeto (gold.score_estouro_30d).
       * A tabela é gerada pelo modelo da Noite 4 e pode ainda não existir:
       * nesse caso respondemos 200 com `disponivel: false` e a tela mostra "—".
       */
      app.get('/api/score-estouro', async (_req, res) => {
        try {
          const descoberta: unknown = await appkit.analytics.query(
            "SHOW TABLES IN lakehouse_vertice.gold LIKE 'score_estouro_30d'"
          );
          if (paraLinhas(descoberta).length === 0) {
            res.json({ disponivel: false, linhas: [] });
            return;
          }

          const linhas: unknown = await appkit.analytics.query(
            `SELECT projeto_id, probabilidade_estouro, faixa_risco
             FROM ${TABELA_SCORE}`
          );
          res.json({ disponivel: true, linhas: paraLinhas(linhas) });
        } catch (erro) {
          console.error('score-estouro indisponível:', erro);
          res.json({ disponivel: false, linhas: [] });
        }
      });
    });
  },
}).catch(console.error);
