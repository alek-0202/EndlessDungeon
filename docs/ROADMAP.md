# Roadmap

As etapas são marcos de validação, não compromissos de calendário. A visão inclui partidas de até quatro jogadores, mas o escopo e o momento de cada funcionalidade multiplayer dependem de decisões futuras. Nenhuma etapa presume uma implementação específica de rede ou backend.

## Abordagem de desenvolvimento

Gameplay começa imediatamente após AI-05 e serve como validação prática do fluxo de IA. Cada incremento deve usar um prompt conciso, escopo aprovado, implementação autônoma, validação proporcional ao risco e relatório curto. Infraestrutura e checkpoints intermediários só entram quando resolvem uma necessidade concreta.

Antes dos primeiros assets, definir somente a direção de arte essencial para manter coerência. Pipeline de assets e testes automatizados evoluem junto com gameplay. CI/CD permanece adiado até colaboração, regressões repetidas ou preparação de entrega demonstrarem valor concreto. Aprovações de design, geração paga, dependências, segurança, credenciais, validação `Full` aplicável e operações Git continuam seguindo `AGENTS.md` e `docs/AI_WORKFLOW.md`.

## 1. Protótipo 2D de combate e progressão

**Meta Gameplay 01:** arena 2D top-down estacionária, um herói automático, inimigos vindos de lados diferentes, preferência radial configurável, ataques corpo a corpo e projéteis físicos, atributos básicos de combate, HUD e término/reinício da run por morte. Usar placeholders visuais e valores provisórios; não incluir progressão ainda.

O desenvolvimento inicial permanece offline-first. Este marco não exige todos os recursos multiplayer da visão final. A inclusão de qualquer capacidade multiplayer no protótipo ainda precisa de definição de escopo.

**Verificação Gameplay 01:** iniciar a cena principal, observar spawn de vários lados e ações automáticas, alterar o raio de 0% a 100%, alternar ataques, observar colisão de projéteis e dano, confirmar encerramento por morte e reinício. Rodar os testes focados e a validação Full. Progressão temporária e regras de recompensa entram em incremento posterior após aprovação.

**Incremento de kiting:** após playtest manual inicial aprovado, verificar nos dois modos aproximação até o alcance máximo, ataque imediato quando disponível, recuo durante cooldown, preferência radial flexível e respeito à borda da formação, sem oscilação ou reinício do cooldown por movimento.

**Gameplay 02 — arena e HUD:** ampliar a área lógica para 960×540, usar 1920×1080 como referência desktop, manter filtragem nearest e números de combate, separar câmera com zoom configurável e HUD ancorado ao viewport. Acrescentar navegação inferior persistente e bases de seis painéis recolhíveis, com estado de combate compacto e controles atuais nos painéis adequados. Verificar troca e fechamento sem pausa, redimensionamento sem sobreposição e regressões de combate; conteúdo de skills, inventário, loot e grupo de quatro heróis continua futuro.

## 2. Validar preparação de build e estrutura da run

Depois do protótipo, avaliar a sequência de gerar modificadores da dungeon, inspecioná-los, escolher um preset e entrar. Validar a progressão até o chefe final e planejar o escopo de implementação e validação do farm opcional pós-chefe previsto no design.

**Verificação:** a sequência e as escolhas que afetam a run estão descritas e podem ser observadas no protótipo expandido; qualquer regra ainda incerta está registrada como aberta.

## 3. Expandir conteúdo e recompensas orientados a dados, conforme prioridade

Introduzir somente os dados necessários para classes, habilidades, itens, inimigos, modificadores, raridades, afixos e loot aprovados. Ao abordar equipamento, respeitar as seis raridades e os limites independentes de Mythic e Divine, incluindo os slots exclusivos de Divine, sem definir efeitos ou taxas de drop ainda em aberto. A implementação de mochila, seleção final de recompensa e ferreiro depende de definir os fluxos e detalhes que ainda estão em aberto.

**Verificação:** o conteúdo inicial pode ser configurado sem duplicar lógica específica para cada definição, e regras de drop e retenção correspondem às decisões aprovadas.

## 4. Definir persistência e regras de continuidade

Decidir como o progresso permanente é salvo, como runs interrompidas são tratadas e como escolhas de manter/descartar feitas durante a run se relacionam à seleção final, antes de implementar salvamento ou retomada de sessão.

**Verificação:** as regras aprovadas estão documentadas e uma implementação posterior consegue respeitá-las sem presumir resultados de morte ou desconexão.

## 5. Explorar multiplayer e sistemas compartilhados, após decidir o modelo

A visão contempla até quatro jogadores, personagens e builds individuais, drops individuais e partes compartilhadas da dungeon e das recompensas. Um marco multiplayer só deve ser planejado após decidir modalidade de sessão, regras de grupo, distribuição de recompensas e escopo técnico. Não é requisito do primeiro protótipo.

**Verificação:** um escopo multiplayer concreto pode ser validado com regras claras para estado individual, estado compartilhado, morte, recompensas e evolução de monstros. A tecnologia e as etapas dependem dessas decisões.

## 6. Avaliar endgame e balanceamento

Explorar progressão potencialmente infinita, teto de raridade por nível de dungeon, recompensas, builds de inimigos, Arcana, evolução de monstros e sistemas de endgame conforme prioridade. Valores de exemplo não são balanceamento final.

**Verificação:** os sistemas selecionados podem ser observados e ajustados com conteúdo de teste, sem presumir equilíbrio definitivo nem exigir a implementação de todas as ideias da visão.
