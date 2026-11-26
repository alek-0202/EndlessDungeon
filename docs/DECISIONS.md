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
- Consequências: gameplay novo não é aprovado por inferência; geração paga, novas dependências, mudanças arquiteturais significativas e operações de Git respeitam os limites de aprovação documentados. As seis Skills centrais e os scripts de bootstrap, resolução do Godot, diagnóstico do ambiente, validação local de Skills e validação unificada do projeto estão implementados. O adaptador de `Stop` teve quatro cenários de integração verificados, mas o hook de projeto permanece desativado e sua integração nativa foi adiada. Gameplay 01 adicionou testes automatizados de combate; outros hooks, pipeline de assets e CI continuam planejados. Composição verificada de Skills não equivale a garantia de orquestração automática geral.
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

### DEC-006 — Direção inicial de combate e formação

- Data: 2026-11-25 (decisão explicitada em Gameplay 01)
- Status: aceita
- Contexto: o primeiro protótipo precisa tornar observáveis combate automático, posicionamento de build e perigo espacial.
- Decisão: usar combate 2D top-down em pixel art, arena estacionária e formação circular de centro fixo, com inimigos de todas as direções. Cada build pode configurar preferência radial entre 0% e 100%; comportamentos padrão variam por classe e podem ser personalizados. Projéteis são espaciais e colidem com alvos válidos. Ameaça individual futura não garante proteção por tanque; investimento defensivo continua relevante na retaguarda.
- Justificativa: estabelecer o recorte aprovado de gameplay sem fixar regras permanentes de balanceamento ou antecipar sistemas avançados.
- Consequências: Gameplay 01 implementa um herói automático, alvos e movimento automáticos, corpo a corpo, projéteis, atributos básicos, HUD e término/reinício por morte com valores provisórios. Classes completas, ameaça avançada, skills, equipamento, progressão e multiplayer exigem tarefas futuras. Fórmulas finais e prioridades de alvo permanecem abertas.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 01.

### DEC-007 — Kiting automático no combate inicial

- Data: 2026-11-25 (decisão explicitada na tarefa Gameplay 01 — Automatic Kiting)
- Status: aceita
- Contexto: o playtest manual do primeiro protótipo passou, mas o movimento automático ainda encurtava o alcance útil e podia atrasar ataques.
- Decisão: nos ataques corpo a corpo e à distância, preferir o maior alcance efetivo, aproximar-se somente até entrar em alcance, atacar imediatamente quando disponível e parar ao atacar. Durante o cooldown, recuar para recuperar a distância quando necessário. Respeitar sempre a formação circular; tratar a posição radial da build como preferência flexível e evitar oscilação, recuo desnecessário e reinício do cooldown por movimento.
- Justificativa: melhorar a leitura e a resposta do combate automático sem alterar atributos, controles ou sistemas adiados.
- Consequências: o movimento tático pode afastar temporariamente o herói de sua preferência radial; a borda da formação pode impedir alcançar a distância ideal. A tolerância de posicionamento é detalhe provisório do protótipo, não regra permanente de balanceamento.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 01 — Automatic Kiting.

### DEC-008 — Fundação de arena e HUD

- Data: 2026-11-25 (decisão explicitada na tarefa Gameplay 02)
- Status: aceita
- Contexto: o responsável aprovou manualmente o combate inicial e o kiting; a área e o HUD precisam comportar expansão futura sem alterar o combate aprovado.
- Decisão: usar 960×540 como resolução lógica provisória e 1920×1080 como referência desktop, preservar compatibilidade com pixel art e filtragem nearest, separar unidades do mundo, câmera com zoom configurável e layout do HUD. Manter navegação inferior persistente e painéis recolhíveis de aproximadamente 30% da altura para Character, Skills, Inventory, Loot, Tactics e Stats; troca e fechamento não pausam combate. Estado essencial permanece compacto e visível; controles e atributos atuais migram para seus painéis.
- Justificativa: aumentar a área utilizável e criar uma base responsiva para até quatro heróis e hordas futuras sem implementar seus sistemas ainda.
- Consequências: tamanho da arena e apresentação mudam, enquanto raio da formação, atributos e distâncias relativas de spawn permanecem provisoriamente iguais. Os painéis sem mecânicas próprias exibem apenas estrutura inicial; design visual detalhado continua aberto.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 02 — Arena & HUD Foundation.

### DEC-009 — Simulação local de party e ameaça individual

- Data: 2026-11-25 (decisão explicitada em Gameplay 03)
- Status: aceita
- Contexto: após a fundação de combate e HUD, é preciso observar proteção, interceptação e perigo individual em uma party local.
- Decisão: simular quatro heróis independentes com arquétipos provisórios Tank 90%, Assassin 75%, Archer 30% e Mage 15% de preferência radial; cada inimigo mantém ameaça por herói baseada em dano com modificador configurável para o Tank. Tank prioriza interceptação e proteção do grupo; outros comportamentos apropriados mantêm kiting. Inimigos corpo a corpo e à distância coexistem, seus projéteis podem ser interceptados por outro herói, e a run termina quando todos morrerem.
- Justificativa: tornar observável a escolha individual de alvo sem garantir proteção por tanque ou antecipar multiplayer.
- Consequências: cada herói tem stats, vida, cooldown, alvo, movimento e configuração próprios; HUD seleciona herói e mostra vida da party. Arena, formação, densidade, números de build e multiplicadores são provisórios. Classes completas, skills, ressurreição, equipamentos, progressão, rede e fórmulas finais de ameaça continuam fora do escopo.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 03.

### DEC-010 — Refinamento de aquisição e posicionamento da party

- Data: 2026-11-25 (decisão explicitada após playtest manual de Gameplay 03)
- Status: aceita
- Contexto: projéteis podiam chegar após a fonte ser liberada, e heróis não-tanque perseguiam inimigos distantes até a borda da formação.
- Decisão: manter a interceptação do Tank aprovada. Para os demais, separar alcance de ataque, detecção inicial de 110% do alcance efetivo e região radial configurada, com pequena tolerância. Liberar alvos fora do engajamento, retornar ao ponto preferido sem alvo e fazer kiting dentro da região nos dois modos de ataque. Projéteis continuam causando dano após a fonte morrer ou ser liberada, atribuindo a fonte apenas quando ainda válida.
- Consequências: o protótipo usa margem de liberação igual à tolerância radial e interpreta a região como disco limitado pelo raio preferido mais tolerância, sempre dentro da formação. Esses detalhes permanecem configuráveis e provisórios; balanceamento e regras finais de aquisição continuam abertos.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 03 — Combat Behavior Refinement.

### DEC-011 — Fundação de classes e Sandbox de combate

- Data: 2026-11-25 (decisão explicitada em Gameplay 04)
- Status: aceita
- Contexto: o responsável aprovou o comportamento atual da party e pediu classes com vantagens naturais e uma área de experimentação ao vivo.
- Decisão: criar definições reutilizáveis de Tank, Assassin, Archer e Mage, estado runtime independente e as passivas descritas em GAME_DESIGN. Permitir composição local dinâmica e ajustes temporários pelo Sandbox de desenvolvimento, sem restringir builds nem alterar dados permanentes.
- Consequências: os parâmetros não especificados são configuráveis e provisórios. Mage zera ambos os contadores na ativação, lança três fireballs de 100% do dano de skill, repetindo alvo quando necessário; casts ficam preparados por evento, sem sistema completo de skills. Furtividade reduz prioridade de alvo e não impede colisões. O Sandbox não integra progressão ou rede.
- Referências: docs/GAME_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, tarefa Gameplay 04 — Class Foundation & Combat Sandbox.

### DEC-012 — Próximo marco visual após Gameplay 04B

- Data: 2026-11-26 (prioridade aprovada no checkpoint de Gameplay 03/04/04B)
- Status: aceita
- Contexto: o responsável aprovou manualmente Gameplay 03, Gameplay 04 e Gameplay 04B e definiu a próxima prioridade.
- Decisão: priorizar Art Direction e Visual Foundation antes de novos sistemas de gameplay. A direção visual precisa de aprovação própria antes da produção de assets; geração paga continua sujeita a aprovação ou orçamento.
- Consequências: a roadmap registra o marco visual como próximo passo. Este checkpoint não gera assets nem inicia gameplay novo.
- Referências: docs/ROADMAP.md, tarefa de finalização da branch feature/party-aggro.

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
- Gameplay 01 adicionou testes headless de regras provisórias, seleção de alvo, movimento, ataque, mitigação, interceptação por colisão e ciclo de morte/reinício. A validação Full executa esses testes após a importação. Importação e testes headless não comprovam apresentação visual, sensação de jogo nem balanceamento.
- Gameplay 04 acrescentou testes determinísticos de contadores e timers de passivas, bônus do Archer, caça/furtividade e colisão do Assassin, fireballs da Mage, distribuição de cura do Tank, composição dinâmica, isolamento de overrides e controles do Sandbox. A validação Full passou com 12 checks, nenhum falhou ou foi ignorado, e um warning de Python opcional ausente; a execução headless da cena principal por 600 frames terminou com saída 0. Avaliação visual e balanceamento das classes ainda dependem de playtest do responsável.
- Gameplay 04B mantém as regras aprovadas e refina estabilidade e uso: liberação de alvo à distância fora do alcance radial, cooldown contínuo sem alvo, seleção por identidade e edição de atributos ao vivo com preservação da fração do cooldown. Os testes determinísticos de combate e Sandbox passaram (saída 0). Capturas com renderização real em 1920×1080 e 960×540 foram inspecionadas; cartões e controles roláveis ficaram legíveis, sem sobreposição observada nesses dois tamanhos. Uma captura headless com renderer dummy não foi possível, portanto a evidência visual vem apenas da execução gráfica. Perfil headless de 180 frames por cenário, com inimigos de vida elevada para manter a carga: 1 herói/20 inimigos 184,6 µs médios por passo, 4/60 1905,2 µs, 8/100 3980,4 µs com HUD limitado a 5 Hz; em 8/100 com atualização a cada frame, 4833,0 µs. São medidas locais de um único processo, não metas de desempenho nem garantia para outras máquinas.
- A validação Full final de Gameplay 04B passou com saída 0: 12 checks aprovados, nenhum falhou ou foi ignorado, um aviso de Python opcional ausente e nenhum efeito colateral visível no repositório. A importação Godot e os testes de gameplay passaram separadamente. O responsável aprovou o playtest de Gameplay 03, Gameplay 04 e Gameplay 04B em 2026-11-26; o balanceamento definitivo permanece em aberto.
