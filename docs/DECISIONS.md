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
- Consequências: gameplay novo não é aprovado por inferência; geração paga, novas dependências, mudanças arquiteturais significativas e operações de Git respeitam os limites de aprovação documentados. As seis Skills centrais estão implementadas. Scripts, hooks, pipeline de assets, testes automatizados e CI continuam planejados; composição verificada de Skills não equivale a garantia de orquestração automática geral.
- Referências: `AGENTS.md`, `docs/AI_WORKFLOW.md`, tarefa AI-01.

## Evidências de implementação relacionadas

Esta seção registra resultados observados e limitações; não cria nem altera decisões do projeto.

- As seis Skills locais foram descobertas nativamente em uma nova sessão do Codex, e o ambiente confirmou suporte a invocação explícita.
- Uma solicitação combinada selecionou implicitamente as seis Skills e carregou os seis arquivos `SKILL.md`.
- A seleção independente de cada Skill em tarefas únicas ainda não foi validada.
- A validação manual dos frontmatters passou. O `quick_validate.py` não foi executado porque Python não está disponível no ambiente atual.
- A resolução do Godot pelo `GODOT_PATH` do ambiente User do Windows, `--version` e a importação headless passaram com código de saída 0.
- Importação bem-sucedida não comprova comportamento de gameplay ou runtime; esses testes ainda não existem.
