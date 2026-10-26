import { situacaoTexto } from '../lib/formatters';

type FarolProps = {
  situacao: string;
  rotulo?: string;
  className?: string;
};

export function Farol({ situacao, rotulo, className }: FarolProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={`inline-block h-4 w-4 ${situacaoTexto(situacao)} ${className ?? ''}`}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      role={rotulo ? 'img' : 'presentation'}
      aria-label={rotulo}
      aria-hidden={rotulo ? undefined : true}
      focusable="false"
    >
      {rotulo ? <title>{rotulo}</title> : null}
      <path d="M12 4.2 10.3 6.4h3.4L12 4.2Z" />
      <rect x="10.2" y="6.4" width="3.6" height="3.4" rx="0.4" />
      <path d="M10.4 9.8 8.9 21.2h6.2L13.6 9.8" />
      <path d="M9.7 14.2h4.6" />
      <path d="M9.2 17.8h5.6" />
      <path d="M8.8 21.2h6.4" />
      <path d="M6.4 8.1H3.6" />
      <path d="M20.4 8.1h-2.8" />
    </svg>
  );
}
