import { useEffect, useState } from 'react';
import {
  Alert,
  AlertDescription,
  AlertTitle,
  Badge,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';
import { useAnalyticsQuery } from '@databricks/appkit-ui/react';
import { Farol } from '../components/Farol';
import { paraDias, paraIndice, paraMoeda, paraNumero, paraPercentual, situacaoClasse } from '../lib/formatters';

type ScoreLinha = {
  projeto_id: string;
  probabilidade_estouro: number | string;
  faixa_risco: string;
};

type ScoreEstado = {
  carregando: boolean;
  disponivel: boolean;
  linhas: ScoreLinha[];
};

const CAUSAS: Record<string, string> = {
  falta_sre: 'Falta de SRE',
  rotatividade: 'Rotatividade',
  aprovacao_cliente: 'Aprovação do cliente',
  mudanca_escopo: 'Mudança de escopo',
  bug_retrabalho: 'Bug / retrabalho',
  dependencia_fornecedor: 'Dependência de fornecedor',
  change_freeze: 'Change freeze',
  sem_bloqueio: 'Sem bloqueio',
};

const rotuloCausa = (causa: string | null | undefined): string => (causa ? (CAUSAS[causa] ?? causa) : '—');

function KpiCard({
  titulo,
  valor,
  apoio,
  destaque,
}: {
  titulo: string;
  valor: string;
  apoio: string;
  destaque?: boolean;
}) {
  return (
    <Card className="shadow-sm">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{titulo}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className={`text-3xl font-semibold tabular-nums ${destaque ? 'text-destructive' : 'text-foreground'}`}>
          {valor}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">{apoio}</p>
      </CardContent>
    </Card>
  );
}

function CardKpiCarregando() {
  return (
    <Card className="shadow-sm">
      <CardHeader className="pb-2">
        <Skeleton className="h-4 w-32" />
      </CardHeader>
      <CardContent className="space-y-2">
        <Skeleton className="h-8 w-28" />
        <Skeleton className="h-3 w-40" />
      </CardContent>
    </Card>
  );
}

export function ProjetosRiscoPage() {
  const kpis = useAnalyticsQuery('kpis');
  const projetos = useAnalyticsQuery('projetos_risco');

  const [score, setScore] = useState<ScoreEstado>({
    carregando: true,
    disponivel: false,
    linhas: [],
  });

  useEffect(() => {
    let ativo = true;
    fetch('/api/score-estouro')
      .then((res) => (res.ok ? res.json() : { disponivel: false, linhas: [] }))
      .then((payload: { disponivel: boolean; linhas: ScoreLinha[] }) => {
        if (!ativo) return;
        setScore({
          carregando: false,
          disponivel: Boolean(payload?.disponivel),
          linhas: Array.isArray(payload?.linhas) ? payload.linhas : [],
        });
      })
      .catch(() => {
        if (!ativo) return;
        setScore({ carregando: false, disponivel: false, linhas: [] });
      });
    return () => {
      ativo = false;
    };
  }, []);

  const porProjeto = new Map<string, ScoreLinha>();
  for (const linha of score.linhas) {
    porProjeto.set(String(linha.projeto_id), linha);
  }

  const altoRisco = score.disponivel
    ? score.linhas.filter((l) => String(l.faixa_risco).toLowerCase() === 'alto').length
    : null;

  const linhaKpi = kpis.data?.[0];

  return (
    <div className="mx-auto w-full max-w-7xl space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-foreground">Projetos em risco</h2>
        <p className="text-sm text-muted-foreground">
          Carteira em andamento · corte do dado em 16/10/2026 · fonte{' '}
          <code className="rounded bg-muted px-1">lakehouse_vertice.gold</code>
        </p>
      </div>

      {kpis.error && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao carregar os KPIs</AlertTitle>
          <AlertDescription>{String(kpis.error)}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {kpis.loading || !linhaKpi ? (
          <>
            <CardKpiCarregando />
            <CardKpiCarregando />
            <CardKpiCarregando />
            <CardKpiCarregando />
          </>
        ) : (
          <>
            <KpiCard
              titulo="Projetos em risco"
              valor={`${paraNumero(linhaKpi.projetos_em_risco)} / ${paraNumero(linhaKpi.projetos_em_andamento)}`}
              apoio={`${paraNumero(linhaKpi.projetos_criticos)} críticos · ${paraNumero(linhaKpi.projetos_atencao)} em atenção`}
              destaque
            />
            <KpiCard
              titulo="Estouro previsto"
              valor={paraMoeda(linhaKpi.estouro_previsto_total)}
              apoio="EAC − orçamento, somado dos projetos ativos"
            />
            <KpiCard
              titulo="Carteira"
              valor={paraMoeda(linhaKpi.carteira_total)}
              apoio="Valor de contrato dos projetos em andamento"
            />
            <KpiCard
              titulo="Alto risco em 30 dias"
              valor={score.carregando ? '…' : altoRisco === null ? '—' : String(altoRisco)}
              apoio={
                score.disponivel
                  ? 'Modelo score_estouro_30d · faixa_risco = alto'
                  : 'Modelo score_estouro_30d ainda não publicado'
              }
            />
          </>
        )}
      </div>

      <Card className="shadow-sm">
        <CardHeader>
          <CardTitle>Carteira em andamento, do pior para o melhor</CardTitle>
        </CardHeader>
        <CardContent>
          {projetos.error && (
            <Alert variant="destructive" className="mb-4">
              <AlertTitle>Falha ao carregar os projetos</AlertTitle>
              <AlertDescription>{String(projetos.error)}</AlertDescription>
            </Alert>
          )}

          {projetos.loading && (
            <div className="space-y-2">
              {Array.from({ length: 8 }, (_, i) => (
                <Skeleton key={i} className="h-9 w-full" />
              ))}
            </div>
          )}

          {!projetos.loading && projetos.data && projetos.data.length === 0 && (
            <p className="py-6 text-center text-sm text-muted-foreground">Nenhum projeto em andamento.</p>
          )}

          {!projetos.loading && projetos.data && projetos.data.length > 0 && (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Projeto</TableHead>
                    <TableHead>Cliente</TableHead>
                    <TableHead>Situação</TableHead>
                    <TableHead className="text-right">SPI</TableHead>
                    <TableHead className="text-right">CPI</TableHead>
                    <TableHead className="text-right">Estouro previsto</TableHead>
                    <TableHead className="text-right">Atraso</TableHead>
                    <TableHead>Farol do gerente</TableHead>
                    <TableHead className="text-right">P(estouro)</TableHead>
                    <TableHead>Causa mais frequente</TableHead>
                    <TableHead className="text-right">Impactos (90 d)</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {projetos.data.map((p) => {
                    const scoreLinha = porProjeto.get(String(p.projeto_id));
                    return (
                      <TableRow key={String(p.projeto_id)}>
                        <TableCell className="max-w-[16rem]">
                          <div className="font-medium">{String(p.projeto_id)}</div>
                          <div className="truncate text-xs text-muted-foreground">{String(p.nome_projeto)}</div>
                        </TableCell>
                        <TableCell className="max-w-[10rem] truncate">{String(p.cliente)}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={situacaoClasse(String(p.situacao))}>
                            <Farol situacao={String(p.situacao)} className="mr-1 h-3 w-3" />
                            {String(p.situacao)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right tabular-nums">{paraIndice(p.spi)}</TableCell>
                        <TableCell className="text-right tabular-nums">{paraIndice(p.cpi)}</TableCell>
                        <TableCell className="text-right tabular-nums">{paraMoeda(p.estouro_previsto)}</TableCell>
                        <TableCell className="text-right tabular-nums">{paraDias(p.atraso_projetado_dias)}</TableCell>
                        <TableCell>
                          <span className="capitalize">{String(p.farol_do_gerente)}</span>
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {scoreLinha ? paraPercentual(scoreLinha.probabilidade_estouro) : '—'}
                        </TableCell>
                        <TableCell className="max-w-[10rem] truncate">
                          {rotuloCausa(p.causa_mais_frequente as string | null)}
                        </TableCell>
                        <TableCell className="whitespace-nowrap text-right tabular-nums">
                          SRE {paraNumero(p.dias_falta_sre)} d · Rot. {paraNumero(p.dias_rotatividade)} d
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      <p className="text-xs text-muted-foreground">
        Regras de corte: SPI ou CPI &lt; 0,90 = atenção; &lt; 0,80 = crítico. P(estouro){' '}
        {score.disponivel ? 'vem de gold.score_estouro_30d.' : 'indisponível: a tabela ainda não existe.'}
      </p>
    </div>
  );
}
