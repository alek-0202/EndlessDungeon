# Registro de decisões

Este registro oferece rastreabilidade sem repetir as regras detalhadas de `GAME_DESIGN.md` ou os limites de `ARCHITECTURE.md`. Cada decisão recebe um identificador único e conserva seu histórico. `Data` indica a data da decisão quando conhecida; quando não é conhecida, indica explicitamente a data do registro. Os status permitidos são **aceita**, **proposta**, **substituída** e **rejeitada**. Propostas não autorizam implementação. Uma decisão substituída deve apontar para a decisão que a substitui.

## Modelo para novos registros

```text
### DEC-NNN — Título

- Data: AAAA-MM-DD (decisão ou registro; especificar)
- Status: aceita | proposta | substituída | rejeitada
- Contexto: problema ou necessidade.
- Decisão: escolha registrada.
- Justificativa: motivo conhecido para a escolha.
- Consequências: efeitos e limites.
- Referências: documentos ou decisões relacionados.
```

## Decisões registradas

### DEC-001 — Base técnica inicial

- Data: 2026-11-24 (data deste registro; data da decisão original não documentada)
- Status: aceita
- Contexto: o projeto precisa de uma base técnica para o protótipo.
- Decisão: usar Godot 4 e GDScript, com alvo inicial em Windows desktop.
- Justificativa: direção já estabelecida na documentação do projeto; a motivação histórica específica não está registrada.
- Consequências: desenvolvimento e validação iniciais seguem essa base. Mudanças de engine, linguagem ou plataforma exigem nova decisão.
- Referências: `docs/ARCHITECTURE.md`, `docs/GAME_DESIGN.md`.

### DEC-002 — Protótipo pequeno e visão multiplayer

- Data: 2026-11-24 (data deste registro; data da decisão original não documentada)
- Status: aceita
- Contexto: a visão de longo prazo inclui partidas de até quatro jogadores, enquanto o primeiro marco precisa ser verificável.
- Decisão: manter o protótipo inicial pequeno e offline-first; modalidade, arquitetura e momento de introdução do multiplayer permanecem em aberto.
- Justificativa: preservar o escopo do primeiro marco sem antecipar escolhas técnicas não aprovadas.
- Consequências: o primeiro protótipo não pressupõe rede ou backend. O escopo multiplayer exige decisão posterior.
- Referências: `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`.

### DEC-003 — Governança do desenvolvimento com IA

- Data: 2026-11-24 (decisão explicitada na tarefa AI-01)
- Status: aceita
- Contexto: o projeto precisa de um fluxo permanente para trabalho operacional por agentes de IA.
- Decisão: o responsável define direção, prioridades e aprovações; agentes executam o escopo autorizado e validam resultados. `AGENTS.md` contém instruções operacionais, `docs/AI_WORKFLOW.md` detalha o fluxo e este registro preserva decisões rastreáveis. Skills, scripts, integrações e CI são usados conforme forem disponibilizados e validados.
- Justificativa: manter responsabilidades e fontes de verdade explícitas, com resultados verificáveis.
- Consequências: gameplay novo não é aprovado por inferência; geração paga, novas dependências, mudanças arquiteturais significativas e operações de Git respeitam os limites de aprovação documentados. As seis Skills centrais e os scripts de bootstrap, resolução do Godot, diagnóstico do ambiente, validação local de Skills e validação unificada do projeto estão implementados. O adaptador de `Stop` teve quatro cenários de integração verificados, mas o hook de projeto permanece desativado e sua integração nativa foi adiada. Outros hooks, pipeline de assets, testes automatizados e CI continuam planejados. Composição verificada de Skills não equivale a garantia de orquestração automática geral.
- Referências: `AGENTS.md`, `docs/AI_WORKFLOW.md`, tarefa AI-01.

### DEC-004 — Primeiro hook nativo de validação

- Data: 2026-11-24 (decisão explicitada na tarefa AI-05B)
- Status: aceita
- Contexto: o projeto precisa de feedback automático e limitado antes de um agente concluir uma rodada com mudanças locais.
- Decisão: implementar um único hook nativo de projeto para o evento `Stop`; permitir no máximo uma continuação automática quando a validação `Quick` falhar; manter validação `Full` explícita sob as regras existentes; adiar todos os Git hooks.
- Justificativa: reutilizar o validador determinístico existente com um limite contra loops, sem criar outra engine de validação ou ampliar permissões.
- Consequências: o adaptador ignora uma working tree limpa e executa `Quick` quando o Git detecta mudanças staged, tracked unstaged ou untracked não ignorados. A primeira falha obrigatória pode pedir uma continuação; `stop_hook_active` impede outra. A CLI descobriu a definição, mas marcou o hook como não confiável e inativo; o disparo no VS Code não foi observado. A configuração está preservada em `.codex/hooks.json.disabled` para ativação futura, e validação explícita permanece obrigatória. O hook não substitui `Full`, revisão, testes de gameplay ou CI e não autoriza Git hooks, decisões de gameplay, dependências, operações Git ou geração paga.
- Referências: `.codex/hooks.json.disabled`, `tools/hooks/Invoke-CodexStopValidation.ps1`, `docs/AI_WORKFLOW.md`, tarefa AI-05B.

### DEC-005 — Desenvolvimento orientado por gameplay após AI-05

- Data: 2026-11-25 (decisão explicitada na tarefa AI-05D)
- Status: aceita
- Contexto: a fundação de IA precisa ser validada em trabalho real sem prolongar infraestrutura antes de necessidade concreta.
- Decisão: iniciar gameplay imediatamente após AI-05; definir apenas a direção de arte essencial antes de produzir assets; desenvolver pipeline de assets e testes automatizados junto com gameplay; adiar CI/CD até oferecer valor concreto; usar prompts concisos, implementação autônoma dentro do escopo aprovado, validação baseada em risco e relatórios curtos; evitar infraestrutura e checkpoints intermediários desnecessários.
- Justificativa: validar o fluxo de IA pelo desenvolvimento observável do jogo e investir em automação quando seu benefício puder ser demonstrado.
- Consequências: o roadmap deixa de tratar infraestrutura adicional como pré-requisito para gameplay. Aprovações de gameplay, geração paga, dependências, segurança, proteção de credenciais, validação `Full` aplicável e operações Git mantêm seus limites existentes.
- Referências: `docs/AI_WORKFLOW.md`, `docs/ROADMAP.md`, tarefa AI-05D.

## Evidências de implementação relacionadas

Esta seção registra resultados observados e limitações; não cria nem altera decisões do projeto.

- As seis Skills locais foram descobertas nativamente em uma nova sessão do Codex, e o ambiente confirmou suporte a invocação explícita.
- Uma solicitação combinada selecionou implicitamente as seis Skills e carregou os seis arquivos `SKILL.md`.
- A seleção independente de cada Skill em tarefas únicas ainda não foi validada.
- A validação manual dos frontmatters passou. O `quick_validate.py` não foi executado porque Python não está disponível no ambiente atual.
- A resolução do Godot pelo `GODOT_PATH` do ambiente User do Windows, `--version` e a importação headless passaram com código de saída 0.
- `Resolve-Godot.ps1` e `Validate-Environment.ps1` passaram nos cenários positivos e negativos executados no Windows PowerShell 5.1.26100.9711; compatibilidade em outras plataformas não foi validada.
- `Validate-Skills.ps1` aplica convenções específicas deste repositório sem depender do validador oficial em Python; essa validação local não comprova conformidade com o formato oficial de Skills.
- `Validate-Project.ps1` compõe as validações existentes nos modos `Full` e `Quick`, relata checks ignorados sem tratá-los como executados e compara fingerprints de arquivos visíveis ao repositório antes e depois da execução. Essa comparação não cobre caches e artefatos ignorados, mudanças apenas no índice, diretórios nem arquivos de reparse point que não puderam ser lidos.
- `bootstrap.ps1` usa `Quick` por padrão, delega ao validador consolidado e fornece orientações manuais para capacidades ausentes e integrações externas. Não instala ferramentas, altera configurações persistentes nem verifica conectividade MCP.
- O adaptador de `Stop` e sua configuração preservada estão implementados com prazo interno menor que o timeout nativo e continuação limitada por `stop_hook_active`. Em clone local isolado, clean-tree skip, Quick em árvore suja, bloqueio único na falha e prevenção de loop passaram com saída 0 do adaptador; a falha real do validador foi `whitespace-unstaged` com código 1. A invocação configurada em `commandWindows` também passou com saída 0. Um probe produziu falha `whitespace-untracked` em `Quick` (saída 1), mas `codex exec --json --ephemeral` concluiu sem bloqueio. A CLI interativa mostrou exatamente um hook de projeto instalado, nenhum ativo e um pendente de revisão de confiança. O VS Code não forneceu evidência de disparo. A configuração foi desativada por renomeação para `.codex/hooks.json.disabled`; integração nativa adiada. Validação explícita continua operacional.
- Importação bem-sucedida não comprova comportamento de gameplay ou runtime; esses testes ainda não existem.
