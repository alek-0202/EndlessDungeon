# Fluxo de trabalho com IA

Este documento descreve o fluxo operacional pretendido para o desenvolvimento de Endless Dungeon. O fluxo é uma regra de trabalho. As seis Skills centrais, os primeiros scripts de diagnóstico e validação e o adaptador do hook `Stop` estão implementados. Os quatro cenários de integração do adaptador foram verificados; a integração nativa foi adiada e a configuração de projeto está desativada. Pipeline de assets e testes passam a evoluir junto com gameplay; CI/CD fica adiado até oferecer valor concreto.

## Papéis e responsabilidades

- **Responsável pelo projeto:** define direção criativa, regras de design, prioridades, orçamento e aprovações necessárias; revisa as entregas.
- **Agente de desenvolvimento:** descobre contexto, planeja, executa o escopo autorizado, valida resultados, corrige erros de implementação e relata o que foi verificado e o que permanece incerto.
- **Skills especializadas:** as seis Skills centrais orientam tarefas delimitadas e reutilizáveis. Não substituem as fontes de verdade do projeto nem concedem aprovação.
- **Integrações MCP:** executam operações suportadas por serviços externos e pelo editor quando disponíveis. O agente confere cada resultado antes de tratá-lo como concluído.
- **Scripts determinísticos:** quando existirem, executam verificações repetíveis por CLI com entradas e resultados observáveis.
- **Validação automatizada e CI:** quando configuradas, executam verificações pertinentes e fornecem evidência para revisão. Não aprovam decisões de design nem dispensam a inspeção de alterações inesperadas.

## Fontes de verdade

| Fonte | Responsabilidade |
| --- | --- |
| `AGENTS.md` | Instruções operacionais permanentes e restrições para agentes. |
| `docs/GAME_DESIGN.md` | Visão, regras de gameplay estabelecidas, exemplos tentativos e questões em aberto. |
| `docs/ARCHITECTURE.md` | Limites e decisões técnicas do projeto. |
| `docs/ROADMAP.md` | Prioridades e marcos de validação. |
| `docs/DECISIONS.md` | Registro rastreável de decisões e mudanças de status. |
| Futuro `docs/ART_DIRECTION.md` | Padrões visuais aprovados, após sua criação. |

Uma entrada no registro de decisões aponta para a documentação de detalhe; ela não a substitui. Se fontes parecerem inconsistentes, interromper a implementação dependente e registrar a dúvida para resolução.

## Ciclo padrão da tarefa

1. **Descobrir contexto:** verificar branch e working tree, ler instruções e documentos pertinentes, consultar ferramentas e estado remoto quando aplicável.
2. **Classificar escopo:** identificar se a tarefa trata de game design, desenvolvimento de funcionalidade, geração de assets, correção de bug, refatoração, testes, documentação ou infraestrutura. Uma tarefa pode abranger mais de uma categoria.
3. **Planejar:** definir entregáveis, verificações e dependências de decisões ainda abertas. Preferir a menor solução que cumpra o escopo.
4. **Obter aprovações necessárias:** confirmar regras de gameplay novas, geração paga sem orçamento autorizado, novas dependências, mudanças arquiteturais significativas e operações de Git que exijam autorização. Não repetir pedidos quando a autorização já consta da tarefa.
5. **Implementar:** executar apenas o escopo aprovado e preservar alterações locais existentes.
6. **Validar:** rodar verificações pertinentes, conferir códigos de saída e resultados, investigar falhas e alterações inesperadas.
7. **Revisar alterações:** inspecionar diff, segurança, aderência ao escopo e coerência com as fontes de verdade. Uma revisão humana ou automatizada adicional pode ser exigida pela tarefa.
8. **Atualizar documentação:** refletir decisões aprovadas e mudanças relevantes sem transformar hipóteses em regras.
9. **Entregar relatório:** indicar arquivos alterados, validações executadas, resultados verificados, decisões pendentes, riscos e limites.

## Abordagem de desenvolvimento após AI-05

Após concluir AI-05, iniciar gameplay imediatamente pelo menor incremento aprovado e observável. Definir somente a direção de arte essencial antes dos primeiros assets; desenvolver o pipeline de assets e testes automatizados conforme necessidades reais surgirem durante gameplay. Adiar CI/CD até que um risco repetido, colaboração ou preparação de entrega justifique seu custo.

Usar prompts concisos, implementação autônoma dentro do escopo aprovado, validação proporcional ao risco e relatórios curtos. Validar o fluxo de IA por meio da implementação real do jogo. Evitar infraestrutura, abstrações e checkpoints intermediários sem uma necessidade concreta. Esses princípios não reduzem limites de segurança, aprovações, proteção de credenciais, validação `Full` quando exigida nem revisão de alterações inesperadas.

## Autonomia e limites de aprovação

Agentes podem inspecionar, planejar, implementar o escopo aprovado, testar e corrigir erros de implementação. Não podem inventar regras de gameplay nem tratá-las como aprovadas por silêncio. Dúvidas que afetem uma implementação ficam registradas como questões em aberto até decisão do responsável.

Geração paga de assets requer aprovação explícita ou orçamento autorizado. Novas dependências e mudanças arquiteturais significativas requerem aprovação. Commits, pushes e merges requerem autorização explícita. Operações destrutivas devem respeitar os controles de segurança existentes e preservar trabalho não resolvido.

## Arquitetura de Skills

Skills locais ao repositório ficam em `.agents/skills/`, cada uma com responsabilidade específica. As Skills centrais implementadas são `project-context`, `game-design`, `feature-development`, `asset-generation`, `game-validation` e `code-review`. Devem poder ser combinadas sem copiar toda a base de conhecimento do projeto.

A descoberta nativa das seis Skills e sua seleção implícita conjunta em uma solicitação com múltiplas tarefas foram verificadas. Isso demonstra composição orientada pela solicitação nesse cenário; não garante orquestração automática para todos os fluxos. Testes independentes de seleção para tarefas únicas ainda estão pendentes.

Os scripts determinísticos de bootstrap, resolução do Godot, diagnóstico do ambiente, validação de Skills e validação unificada do projeto estão implementados. O adaptador de `Stop` e a configuração preservada foram testados, mas o hook de projeto está desativado até que o disparo nativo seja verificado. Outros hooks permanecem futuros, pipeline de assets e testes evoluem com gameplay, e CI/CD aguarda valor concreto.

## Automação local do ambiente

- `tools/setup/bootstrap.ps1` é a entrada diagnóstica para uma máquina nova ou para investigar prontidão do ambiente. Usa `Quick` por padrão, aceita `-Mode Full`, `-Json` e `-GodotTimeoutSeconds`, delega a validação a `Validate-Project.ps1` e fornece orientações manuais sem instalar ferramentas nem alterar configurações persistentes.
- `tools/setup/Resolve-Godot.ps1` resolve e valida um executável Godot 4 por `GODOT_PATH` do processo, `GODOT_PATH` do ambiente User no Windows e `PATH`, nessa ordem. A execução standalone aceita `-Json`; o uso reutilizável é feito por dot sourcing e pela função `Resolve-Godot`.
- `tools/validation/Validate-Environment.ps1` localiza a raiz do repositório a partir do próprio script e verifica PowerShell, Git, Godot e os arquivos essenciais. Node.js, npm, npx, Python e Codex CLI standalone são opcionais. A execução aceita `-Json` para produzir um único documento JSON.
- `tools/validation/Validate-Skills.ps1` descobre Skills em `.agents/skills/` e valida os seis Skills fundamentais, manifests, referências locais, regras de ignore e padrões conservadores de segurança. Aceita `-Json`; warnings não causam falha. O subconjunto suportado de frontmatter usa delimitadores `---` e metadados `key: value` de linha única. O script é específico deste repositório e não equivale ao validador oficial de Skills da OpenAI.
- `tools/validation/Validate-Project.ps1` compõe os três componentes anteriores, estrutura e referências do projeto, whitespace do Git e detecção de efeitos colaterais por fingerprints. O modo `Full` também executa importação headless do Godot e os testes de combate em `tests/combat/test_combat.gd`, ambos com timeout; o modo `Quick` registra essas etapas como ignoradas. Ambos aceitam `-Json` e preservam findings, durações e códigos nativos disponíveis.

O JSON de `Validate-Project.ps1` usa `SchemaVersion` 1 e contém `Success`, `Mode`, `RepositoryRoot`, `DurationMs`, `Counts`, `Checks`, `Findings`, `SideEffects` e `Limitations`. Cada check informa identificador, descrição, obrigatoriedade, status (`Passed`, `Failed` ou `Skipped`), duração, código nativo quando existe, findings e dados específicos. Código 0 significa que todos os checks obrigatórios foram executados e passaram; código 1 significa falha ou check obrigatório não executado por dependência indisponível. Warnings não causam falha.

Usar `Quick` para feedback local quando não é necessária evidência de importação; usar `Full`, que é o padrão, antes de uma entrega ou quando mudanças podem afetar o carregamento do projeto no Godot. O timeout da importação e dos testes de combate pode ser ajustado por `-GodotTimeoutSeconds`; quando ele expira, somente o processo iniciado pelo validador é encerrado e o check falha. Exemplos:

```powershell
# Full, saída legível para pessoas
powershell -NoProfile -File .\tools\validation\Validate-Project.ps1

# Quick, documento JSON único
powershell -NoProfile -File .\tools\validation\Validate-Project.ps1 -Mode Quick -Json

# Uso reutilizável sem encerrar a sessão chamadora
. .\tools\validation\Validate-Project.ps1
Test-EndlessDungeonProject -Mode Quick
```

Em uma máquina nova: obter um checkout completo; abrir PowerShell sem elevação; executar `powershell -NoProfile -File .\tools\setup\bootstrap.ps1`; seguir apenas as orientações aplicáveis; configurar `GODOT_PATH` manualmente quando o Godot não estiver no `PATH`; e repetir o bootstrap. Para um ajuste apenas no processo atual, usar `$env:GODOT_PATH = '<caminho-do-executável-Godot-4>'`. O JSON do bootstrap usa `SchemaVersion` 1 e contém status geral, modo, capacidades obrigatórias e opcionais, resultado consolidado do projeto, remediações, integrações externas, findings e limitações. Capacidade opcional ausente não causa falha.

```powershell
# Diagnóstico Quick padrão
powershell -NoProfile -File .\tools\setup\bootstrap.ps1

# Diagnóstico Full com documento JSON
powershell -NoProfile -File .\tools\setup\bootstrap.ps1 -Mode Full -Json

# Interface reutilizável
. .\tools\setup\bootstrap.ps1
Invoke-EndlessDungeonBootstrap -Mode Quick
```

Godot MCP, PixelLab MCP e a integração do Codex no VS Code são configurados e verificados separadamente pelos fluxos seguros do ambiente hospedeiro. O bootstrap nunca solicita, lê, armazena ou imprime credenciais e não inspeciona configurações MCP privadas. Godot CLI disponível não comprova conectividade Godot MCP; Codex CLI standalone disponível ou ausente não determina o estado da integração no VS Code. Antes de geração PixelLab aprovada, verificar a integração com uma operação gratuita e somente de leitura quando disponível.

Os cinco scripts retornam código 0 quando seus requisitos obrigatórios passam e código 1 quando falham. Foram testados no Windows PowerShell 5.1.26100.9711. Operações específicas do ambiente User são condicionadas ao Windows; compatibilidade em outras plataformas ainda não foi verificada. A descoberta de executáveis não valida conectividade MCP, integração do Codex no VS Code nem comportamento de gameplay ou runtime. A detecção de efeitos colaterais de `Validate-Project.ps1` cobre arquivos rastreados e arquivos não ignorados pelo Git; caches e artefatos locais ignorados, mudanças apenas no índice, diretórios e arquivos de reparse point que não puderam ser lidos ficam fora dessa comparação.

## Hook nativo Stop

O projeto preserva a configuração testada em `.codex/hooks.json.disabled` e o adaptador em `tools/hooks/Invoke-CodexStopValidation.ps1`. O nome `.disabled` impede que Codex descubra essa configuração como hook ativo. Quando ativada, ela registra um único handler `command` para `Stop`, com timeout externo de 90 segundos. A configuração usa o schema documentado de `hooks.json`, mantém o escopo no repositório e localiza a raiz por Git para funcionar a partir de subdiretórios e caminhos com espaços. No Windows, a invocação usa Windows PowerShell sem perfil e aplica `ExecutionPolicy Bypass` somente ao processo do hook e ao subprocesso do validador; ela não altera políticas persistentes.

`tools/hooks/Invoke-CodexStopValidation.ps1` lê o evento JSON de `stdin` e usa apenas `hook_event_name`, `cwd` e `stop_hook_active`. Ele valida o evento, resolve e identifica o repositório Endless Dungeon, e consulta o Git separadamente para mudanças staged, mudanças tracked unstaged e arquivos untracked não ignorados. Arquivos ignorados não são enumerados nem lidos. Working tree limpo encerra sem executar validação. Quando há mudanças visíveis ao repositório, o adaptador executa `Validate-Project.ps1 -Mode Quick -Json`; não duplica os checks do validador e nunca executa `Full`.

Sucesso, inclusive com warnings, permite a conclusão sem nova rodada. Uma falha obrigatória na primeira execução devolve a decisão documentada `block` com um resumo limitado a código de saída e identificadores seguros de checks, solicitando no máximo uma continuação. Se `stop_hook_active` já for verdadeiro, o adaptador revalida quando aplicável, devolve a falha persistente como `systemMessage` sem novo bloqueio e permite a conclusão. Falhas de infraestrutura também usam `systemMessage`, são identificadas como infraestrutura, não são apresentadas como validação bem-sucedida e não criam continuação automática.

O prazo interno total é 80 segundos e o subprocesso de validação recebe no máximo 70 segundos, deixando margem dentro do timeout nativo de 90 segundos. Processos externos de Git recebem até 5 segundos por chamada, limitados pelo prazo total. Em timeout, o adaptador tenta encerrar a árvore iniciada por ele com `taskkill /T`; se isso não estiver disponível ou falhar, encerra o processo exato que iniciou. Esse fallback não garante o encerramento de descendentes que já tenham se desvinculado do processo pai.

O adaptador não lê `transcript_path`, histórico da conversa, configuração MCP privada ou credenciais; não persiste o evento nem encaminha stdout ou stderr brutos do validador. A resposta usa somente campos documentados do hook e um resumo allowlisted e limitado. O hook não concede permissão para gameplay, arquitetura, dependências, PixelLab, commit, push ou merge, não invoca o Codex recursivamente e não substitui `Full`, testes de gameplay, revisão de código ou CI.

A ativação futura exige renomear `.codex/hooks.json.disabled` para `.codex/hooks.json`, revisar a definição exata no mecanismo nativo do Codex, confiar nela no cliente em uso e observar o disparo de `Stop` antes de declarar a integração concluída. Não usar `--dangerously-bypass-hook-trust`. A desativação atual não altera configuração de usuário ou sistema. Até a ativação ser comprovada, executar `Validate-Project.ps1` explicitamente conforme `AGENTS.md`; o hook não é um controle operacional.

Esta primeira versão aceita redundância: uma árvore suja não comprova que a rodada atual modificou arquivos, pode disparar Quick em uma tarefa somente leitura e pode repetir uma validação já executada. Uma árvore limpa não comprova que não houve alterações anteriores na rodada. O hook não valida snapshot staged isolado nem commit enviado. Bancos de sessão, caches, recibos de validação e inspeção de transcript não são usados para compensar essas limitações.

Em 2026-11-25, um clone local isolado com caminho contendo espaços verificou o adaptador com o Git e o validador reais: árvore limpa ignorou um validador propositalmente inválido e retornou `continue: true` (saída 0); árvore suja sem falha retornou `continue: true` (saída 0); whitespace tracked produziu falha `whitespace-unstaged` e um único `decision: block` (saída 0); com `stop_hook_active: true`, a mesma falha retornou `systemMessage` e `continue: true`, sem novo bloqueio (saída 0). O comando `commandWindows` também retornou `continue: true` (saída 0) com evento realista. Um probe `.txt` produziu falha real em `whitespace-untracked` (`Quick` com saída 1), mas `codex exec --json --ephemeral` concluiu com saída 0 sem bloqueio; o arquivo de probe foi removido. Na investigação final, a CLI interativa descobriu exatamente um hook `Stop` da configuração de projeto, com `Installed: 1`, `Active: 0` e `Review: 1`, exibindo `New hook - review required`. O responsável havia informado confiança manual e reinício do VS Code; essa confiança não estava efetiva nessa sessão da CLI. Não foi concedida nova confiança na CLI nem observado disparo no VS Code. A causa observada do não disparo na CLI foi a barreira de confiança; o comportamento do cliente VS Code permanece sem comprovação. A configuração foi renomeada para `.codex/hooks.json.disabled`, preservando adaptador e definição para ativação futura. Após essa desativação, `Validate-Project.ps1 -Mode Full -Json` passou com saída 0: 11 checks passaram, nenhum falhou, `gameplay-tests` foi ignorado por indisponibilidade, e houve um warning de Python opcional ausente; a importação Godot teve saída nativa 0 e a verificação de efeitos colaterais passou. A integração nativa do hook permanece adiada; a validação explícita segue operacional.

## Regressão incremental

Preservar como cenários candidatos: precedência, compatibilidade, falha e timeout da resolução do Godot; capacidades obrigatórias e opcionais do ambiente; manifests, referências, ignore e heurísticas de segurança das Skills; modos Quick e Full, saída humana e JSON, execução externa, whitespace tracked, staged e untracked, falhas de componentes, códigos nativos, timeout, dependências ignoradas e detecção de criação, remoção e modificação por fingerprints; bootstrap real, repetido e externo, remediações obrigatórias e opcionais, ausência de componentes, JSON de falha e preservação de ambiente e Git. Incluir sentinelas controladas para confirmar que diagnósticos não expõem valores sensíveis. Implementar testes persistentes de forma incremental quando gameplay ou um risco concreto justificar; esta lista não exige um marco de infraestrutura separado nem representa um framework já implementado.

## MCP e validação repetível

- Usar PixelLab para produção e inspeção de assets que ele suporte, respeitando aprovação ou orçamento para geração paga.
- Usar Godot MCP para operações de editor e projeto que a integração suporte.
- Descobrir ferramentas MCP de forma direcionada pelo nome ou pela descrição da operação e consultar a ajuda específica da ferramenta quando disponível. Evitar carregar descrições extensas de capacidades não relacionadas quando uma consulta direcionada for suficiente.
- Preferir scripts CLI determinísticos para validações repetíveis, quando estiverem disponíveis.
- Conferir resposta, código de saída e efeito observado de cada operação MCP ou CLI antes de declarar sucesso.
- Não expor credenciais em código, documentação, logs ou relatórios.

## Portabilidade do ambiente

Resolver o executável Godot nesta ordem: `GODOT_PATH` do processo; no Windows, `GODOT_PATH` do ambiente User; executável disponível no `PATH`. Validar o caminho quando aplicável e executar `--version` antes de usá-lo. Uma tarefa pode definir `GODOT_PATH` somente no processo atual quando necessário. Não registrar caminhos absolutos específicos de uma máquina no repositório. Manter credenciais locais fora do repositório e respeitar as regras de ignore existentes.

## Falhas e definição de concluído

Interromper o trabalho dependente diante de conflitos inesperados, problemas de segurança ou validação obrigatória bloqueada. Não contornar mecanismos de aprovação. Relatar operações incompletas com precisão e separar fatos verificados de suposições.

Uma tarefa está pronta para revisão do responsável quando o escopo aprovado foi implementado, as validações pertinentes passaram, não há mudanças inesperadas, a documentação está coerente e riscos e limites foram relatados. Isso não implica autorização para commit, push ou merge.
