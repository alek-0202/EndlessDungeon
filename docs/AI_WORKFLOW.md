# Fluxo de trabalho com IA

Este documento descreve o fluxo operacional pretendido para o desenvolvimento de Endless Dungeon. O fluxo é uma regra de trabalho. As seis Skills centrais estão implementadas; scripts, hooks, pipeline de assets, testes automatizados e CI só passam a operar quando forem criados e validados.

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

## Autonomia e limites de aprovação

Agentes podem inspecionar, planejar, implementar o escopo aprovado, testar e corrigir erros de implementação. Não podem inventar regras de gameplay nem tratá-las como aprovadas por silêncio. Dúvidas que afetem uma implementação ficam registradas como questões em aberto até decisão do responsável.

Geração paga de assets requer aprovação explícita ou orçamento autorizado. Novas dependências e mudanças arquiteturais significativas requerem aprovação. Commits, pushes e merges requerem autorização explícita. Operações destrutivas devem respeitar os controles de segurança existentes e preservar trabalho não resolvido.

## Arquitetura de Skills

Skills locais ao repositório ficam em `.agents/skills/`, cada uma com responsabilidade específica. As Skills centrais implementadas são `project-context`, `game-design`, `feature-development`, `asset-generation`, `game-validation` e `code-review`. Devem poder ser combinadas sem copiar toda a base de conhecimento do projeto.

A descoberta nativa das seis Skills e sua seleção implícita conjunta em uma solicitação com múltiplas tarefas foram verificadas. Isso demonstra composição orientada pela solicitação nesse cenário; não garante orquestração automática para todos os fluxos. Testes independentes de seleção para tarefas únicas ainda estão pendentes.

Scripts determinísticos, hooks, pipeline de assets, testes automatizados e CI ainda não foram implementados. Sua criação, ativação e validação pertencem a etapas futuras.

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
