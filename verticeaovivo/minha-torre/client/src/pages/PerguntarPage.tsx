import { GenieChat } from '@databricks/appkit-ui/react';

// Perguntar: a Genie "Farol · Diretoria" responde as 4 perguntas do dono
// em português e mostra a conta (SQL) de cada resposta.
export function PerguntarPage() {
  return (
    <div className="h-[calc(100vh-140px)] flex flex-col">
      <header className="mb-3">
        <h2 className="text-lg font-semibold text-foreground">Perguntar</h2>
        <p className="text-sm text-muted-foreground">
          Pergunte em português: projetos atrasados, custo do atraso, gente parada
          e o que vai dar errado no próximo mês.
        </p>
      </header>
      <div className="flex-1 overflow-hidden rounded-lg border bg-card">
        <GenieChat alias="default" />
      </div>
    </div>
  );
}
