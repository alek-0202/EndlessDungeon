# Roadmap

As etapas abaixo são marcos pequenos e verificáveis. Itens além do protótipo são direções possíveis, não compromissos obrigatórios. Regras de gameplay permanecem pendentes até aprovação.

## 1. Protótipo 2D mínimo

**Meta:** um personagem, um inimigo, combate automático, HUD básico e progressão temporária simples.

**Verificação:** iniciar uma sessão de protótipo, observar personagem e inimigo no HUD, acompanhar o combate automático e confirmar que uma mudança temporária de progressão é representada durante a sessão. Os detalhes de vitória, derrota, morte, dano e recompensa precisam ser definidos antes de implementá-los.

## 2. Revisar o loop com base no protótipo

Avaliar se o loop demonstra a direção idle RPG e quais dados de personagem e inimigo são necessários. Registrar decisões aprovadas e manter explícitas as questões ainda abertas.

**Verificação:** design e arquitetura descrevem o comportamento observado e as decisões acordadas sem transformar hipóteses em regras.

## 3. Expandir conteúdo orientado a dados, se necessário

Introduzir definições reutilizáveis para os tipos de conteúdo aprovados, começando apenas pelos que o protótipo necessita. A expansão para classes, equipamentos, presets, habilidades e modificadores adicionais depende de prioridade e design aprovados.

**Verificação:** conteúdo inicial pode ser configurado sem duplicar lógica específica para cada definição.

## 4. Definir persistência e regras de run antes de ampliá-las

Decidir o que persiste, como a morte afeta os estados e como runs interrompidas são tratadas antes de implementar salvamento ou continuidade de run.

**Verificação:** as regras foram aprovadas e documentadas; qualquer implementação posterior corresponde a elas.

## 5. Avaliar progressão de dungeon e balanceamento

Explorar dificuldade, recompensas e variedade de builds de inimigos depois que o loop básico estiver validado. Dungeon infinita é uma direção da visão, mas não exige uma fórmula ou sistema completo no protótipo inicial.

**Verificação:** a abordagem escolhida pode ser observada e ajustada com conteúdo de teste, sem assumir equilíbrio definitivo.
