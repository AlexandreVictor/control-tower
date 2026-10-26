// Formatação pt-BR do Projeto Farol.
// Tudo que vem do warehouse chega como string em runtime (DECIMAL/DOUBLE),
// então a conversão com Number() é obrigatória antes de qualquer operação.

export const paraNumero = (valor: number | string | null | undefined): number => {
  const n = Number(valor);
  return Number.isFinite(n) ? n : 0;
};

export const paraMoeda = (valor: number | string | null | undefined): string =>
  paraNumero(valor).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

export const paraIndice = (valor: number | string | null | undefined): string =>
  paraNumero(valor).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

export const paraHoras = (valor: number | string | null | undefined): string =>
  `${paraNumero(valor).toLocaleString('pt-BR', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })} h`;

export const paraDias = (valor: number | string | null | undefined): string =>
  `${paraNumero(valor).toLocaleString('pt-BR', {
    maximumFractionDigits: 0,
  })} d`;

/**
 * `probabilidade_estouro` pode vir como fração (0,72) ou como percentual
 * (72). Acima de 1 assumimos pontos percentuais.
 */
export const paraPercentual = (valor: number | string | null | undefined): string => {
  if (valor === null || valor === undefined || valor === '') return '—';
  const n = Number(valor);
  if (!Number.isFinite(n)) return '—';
  const pct = n > 1 ? n : n * 100;
  return `${pct.toLocaleString('pt-BR', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })}%`;
};

export const situacaoClasse = (situacao: string): string => {
  if (situacao === 'crítico') return 'bg-destructive/15 text-destructive border-destructive/40';
  if (situacao === 'atenção') return 'bg-warning/20 text-warning border-warning/50';
  return 'bg-success/15 text-success border-success/40';
};

export const situacaoTexto = (situacao: string): string => {
  if (situacao === 'crítico') return 'text-destructive';
  if (situacao === 'atenção') return 'text-warning';
  return 'text-success';
};
