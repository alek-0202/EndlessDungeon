# Instruções para agentes

## Antes de começar

- Confirme a branch atual e o estado do Git antes de qualquer trabalho.
- Trabalhe apenas na branch autorizada para a tarefa. Antes de implementar, atualize a branch com o remoto quando houver uma branch remota correspondente e o working tree estiver limpo. Não descarte nem sobrescreva alterações locais não resolvidas.
- Leia este arquivo e os documentos relevantes em `docs/` antes de modificar o projeto.
- Siga `docs/AI_WORKFLOW.md` para o ciclo de trabalho e consulte `docs/DECISIONS.md` para decisões registradas. Use `docs/GAME_DESIGN.md` para regras de gameplay, `docs/ARCHITECTURE.md` para limites técnicos e `docs/ROADMAP.md` para prioridades.

## Durante o trabalho

- Não tome decisões de gameplay que não tenham sido aprovadas. Registre incertezas como questões em aberto.
- Evite abstrações e complexidade desnecessárias; prefira a menor solução que atenda ao escopo aprovado.
- Use inglês para nomes de arquivos, classes e identificadores no código.
- Não adicione segredos, tokens ou credenciais ao repositório.
- Atualize a documentação quando decisões relevantes forem alteradas.
- Não altere configurações do projeto nem amplie o escopo sem necessidade para a tarefa aprovada.

## Ao concluir

- Use `tools/validation/Validate-Project.ps1` como entrada canônica de validação. Use `Quick` para feedback local sem importação Godot e `Full` quando mudanças afetarem código, cenas, resources ou configurações Godot, ou antes de uma entrega que exija evidência de importação.
- Execute verificações adicionais específicas da mudança quando necessárias. Relate resultados e códigos de saída reais, incluindo checks com falha, ignorados, warnings e limitações; importação bem-sucedida não comprova gameplay.
- Não faça commits ou pushes sem solicitação explícita.
