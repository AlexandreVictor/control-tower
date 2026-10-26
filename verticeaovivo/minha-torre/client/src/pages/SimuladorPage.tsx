import { useMemo, useState } from 'react';
import {
  Alert,
  AlertDescription,
  AlertTitle,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
} from '@databricks/appkit-ui/react';
import { useAnalyticsQuery } from '@databricks/appkit-ui/react';
import { paraHoras, paraIndice, paraMoeda, paraNumero } from '../lib/formatters';

const ORDEM_SITUACAO: Record<string, number> = { crítico: 0, atenção: 1 };

const rotuloPapel = (papel: string): string =>
  ({
    sre: 'SRE',
    dev_backend: 'Dev backend',
    dev_frontend: 'Dev frontend',
    dba: 'DBA',
    qa: 'QA',
    pmo: 'PMO',
    arquiteto: 'Arquiteto',
    designer: 'Designer',
  })[papel] ?? papel;

export function SimuladorPage() {
  const pessoas = useAnalyticsQuery('pessoas_ociosas');
  const projetos = useAnalyticsQuery('projetos_risco');

  const [pessoaId, setPessoaId] = useState('');
  const [projetoId, setProjetoId] = useState('');
  const [horasOnboarding, setHorasOnboarding] = useState(40);

  const listaPessoas = pessoas.data ?? [];

  const pessoaEscolhida = listaPessoas.find((p) => String(p.colaborador_id) === pessoaId) ?? listaPessoas[0];

  const projetosRisco = useMemo(() => {
    const lista = (projetos.data ?? []).filter((p) => ['atenção', 'crítico'].includes(String(p.situacao)));
    const isSre = String(pessoaEscolhida?.papel ?? '') === 'sre';
    return [...lista].sort((a, b) => {
      if (isSre) {
        const dif = paraNumero(b.dias_falta_sre) - paraNumero(a.dias_falta_sre);
        if (dif !== 0) return dif;
      }
      const ordem = (ORDEM_SITUACAO[String(a.situacao)] ?? 9) - (ORDEM_SITUACAO[String(b.situacao)] ?? 9);
      if (ordem !== 0) return ordem;
      return paraNumero(a.spi) - paraNumero(b.spi);
    });
  }, [projetos.data, pessoaEscolhida]);

  const projetoEscolhido = projetosRisco.find((p) => String(p.projeto_id) === projetoId) ?? projetosRisco[0];

  const papel = String(pessoaEscolhida?.papel ?? '');
  const custoHora = paraNumero(pessoaEscolhida?.custo_hora);

  const horasOciosasSemana = paraNumero(pessoaEscolhida?.horas_ociosas_media_sem);
  const horasNoMes = horasOciosasSemana * 4;
  const ociosidadeEvitada = horasNoMes * custoHora;

  const diasDeImpacto =
    papel === 'sre' ? paraNumero(projetoEscolhido?.dias_falta_sre) : paraNumero(projetoEscolhido?.dias_rotatividade);
  const diasRecuperados = (diasDeImpacto / 90) * 30;

  const horas = Number.isFinite(horasOnboarding) && horasOnboarding > 0 ? horasOnboarding : 0;
  const mobilizacao = horas * custoHora;
  const saldo = ociosidadeEvitada - mobilizacao;

  if (pessoas.error || projetos.error) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Falha ao carregar os dados do simulador</AlertTitle>
        <AlertDescription>{String(pessoas.error ?? projetos.error)}</AlertDescription>
      </Alert>
    );
  }

  if (pessoas.loading || projetos.loading) {
    return (
      <div className="mx-auto w-full max-w-5xl space-y-4">
        <Skeleton className="h-8 w-64" />
        <div className="grid gap-4 sm:grid-cols-2">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (listaPessoas.length === 0 || projetosRisco.length === 0) {
    return (
      <Alert>
        <AlertTitle>Nada para simular</AlertTitle>
        <AlertDescription>
          Não há pessoas ociosas (&lt; 20% de utilização em 12 semanas) ou projetos em atenção / crítico.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="mx-auto w-full max-w-5xl space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-foreground">Simulador de realocação</h2>
        <p className="text-sm text-muted-foreground">
          Mova quem está parado para destravar quem está travado · corte do dado em 16/10/2026
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card className="shadow-sm">
          <CardHeader>
            <CardTitle>Pessoa ociosa</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-2">
              <Label htmlFor="pessoa">Colaborador</Label>
              <Select value={String(pessoaEscolhida.colaborador_id)} onValueChange={setPessoaId}>
                <SelectTrigger id="pessoa">
                  <SelectValue placeholder="Escolha uma pessoa" />
                </SelectTrigger>
                <SelectContent>
                  {listaPessoas.map((p) => (
                    <SelectItem key={String(p.colaborador_id)} value={String(p.colaborador_id)}>
                      {String(p.nome)} · {rotuloPapel(String(p.papel))} · {String(p.senioridade)} ·{' '}
                      {paraNumero(p.taxa_utilizacao).toLocaleString('pt-BR', {
                        style: 'percent',
                        maximumFractionDigits: 1,
                      })}{' '}
                      de uso
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <dl className="grid grid-cols-2 gap-2 text-sm">
              <div>
                <dt className="text-muted-foreground">Horas ociosas / semana</dt>
                <dd className="tabular-nums">{paraHoras(horasOciosasSemana)}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Custo/hora</dt>
                <dd className="tabular-nums">{paraMoeda(custoHora)}</dd>
              </div>
            </dl>
          </CardContent>
        </Card>

        <Card className="shadow-sm">
          <CardHeader>
            <CardTitle>Projeto destino</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-2">
              <Label htmlFor="projeto">Projeto em atenção ou crítico</Label>
              <Select value={String(projetoEscolhido.projeto_id)} onValueChange={setProjetoId}>
                <SelectTrigger id="projeto">
                  <SelectValue placeholder="Escolha um projeto" />
                </SelectTrigger>
                <SelectContent>
                  {projetosRisco.map((p) => (
                    <SelectItem key={String(p.projeto_id)} value={String(p.projeto_id)}>
                      {String(p.projeto_id)} · {String(p.situacao)} · SPI {paraIndice(p.spi)}
                      {papel === 'sre' && ` · falta SRE ${paraNumero(p.dias_falta_sre)} d`}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <dl className="grid grid-cols-2 gap-2 text-sm">
              <div>
                <dt className="text-muted-foreground">Causa mais frequente (90 d)</dt>
                <dd>{String(projetoEscolhido.causa_mais_frequente ?? '—')}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Atraso projetado</dt>
                <dd className="tabular-nums">{paraNumero(projetoEscolhido.atraso_projetado_dias)} d</dd>
              </div>
            </dl>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Card className="shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Horas no mês</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-semibold tabular-nums">{paraHoras(horasNoMes)}</div>
            <p className="mt-1 text-xs text-muted-foreground">{paraHoras(horasOciosasSemana)} / semana × 4 semanas</p>
          </CardContent>
        </Card>

        <Card className="shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Ociosidade que deixa de ser paga
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-semibold tabular-nums">{paraMoeda(ociosidadeEvitada)}</div>
            <p className="mt-1 text-xs text-muted-foreground">
              {paraHoras(horasNoMes)} × {paraMoeda(custoHora)}
            </p>
          </CardContent>
        </Card>

        <Card className="shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Dias de cronograma recuperados</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-semibold tabular-nums">
              {diasRecuperados.toLocaleString('pt-BR', {
                maximumFractionDigits: 1,
              })}{' '}
              d
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {diasDeImpacto} d de impacto nos últimos 90 d ÷ 90 × 30
            </p>
          </CardContent>
        </Card>

        <Card className="shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Mobilização</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="flex items-center gap-2">
              <Input
                type="number"
                min={0}
                step={1}
                value={String(horasOnboarding)}
                onChange={(e) => setHorasOnboarding(Number(e.target.value))}
                className="w-24"
                aria-label="Horas de onboarding"
              />
              <span className="text-sm text-muted-foreground">horas de onboarding</span>
            </div>
            <div className="text-3xl font-semibold tabular-nums">{paraMoeda(mobilizacao)}</div>
            <p className="text-xs text-muted-foreground">
              {horas} h × {paraMoeda(custoHora)}
            </p>
          </CardContent>
        </Card>

        <Card className="shadow-sm sm:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Saldo financeiro do mês</CardTitle>
          </CardHeader>
          <CardContent>
            <div className={`text-3xl font-semibold tabular-nums ${saldo >= 0 ? 'text-success' : 'text-destructive'}`}>
              {paraMoeda(saldo)}
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              Ociosidade evitada − mobilização ·{' '}
              {saldo >= 0 ? 'a realocação paga o mês' : 'a realocação custa no primeiro mês'}
            </p>
          </CardContent>
        </Card>
      </div>

      <details className="rounded-lg border border-border bg-card p-4 text-sm">
        <summary className="cursor-pointer font-medium text-foreground">Como a conta é feita</summary>
        <div className="mt-3 space-y-2 text-muted-foreground">
          <p>
            <strong className="text-foreground">Horas no mês</strong> = horas ociosas médias por semana (últimas 12
            semanas, taxa de utilização &lt; 20%) × 4 semanas.
          </p>
          <p>
            <strong className="text-foreground">Ociosidade que deixa de ser paga</strong> = horas no mês × custo/hora do
            colaborador. É a folga que sai do caixa quando a pessoa é alocada.
          </p>
          <p>
            <strong className="text-foreground">Dias de cronograma recuperados</strong> = dias de impacto da causa nos
            últimos 90 dias ÷ 90 × 30. SRE destrava o que parou por <em>falta de SRE</em>; os demais papéis cobrem a{' '}
            <em>rotatividade</em>. Os vêm de <code>gold.status_estruturado</code> (classificação da IA), não de
            estimativa humana.
          </p>
          <p>
            <strong className="text-foreground">Mobilização</strong> = horas de onboarding (editável, padrão 40 h) ×
            custo/hora: o custo de pôr a pessoa dentro do projeto.
          </p>
          <p>
            <strong className="text-foreground">Saldo</strong> = ociosidade que deixa de ser paga − mobilização.
            Positivo no primeiro mês significa que a realocação se paga sozinha.
          </p>
          <p>O simulador é uma simulação de alocação: não altera timesheet, contrato nem cronograma.</p>
        </div>
      </details>
    </div>
  );
}
