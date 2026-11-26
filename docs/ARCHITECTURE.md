# Arquitetura

## Direção

- Engine: Godot 4.
- Linguagem: GDScript.
- O protótipo inicial deve permanecer pequeno e offline-first. A visão de longo prazo inclui partidas de até quatro jogadores; modalidade de rede, backend e momento de introdução do multiplayer continuam sem decisão.
- Manter o protótipo pequeno; adicionar estrutura quando uma necessidade concreta surgir.
- A cena jogável usa arena 2D top-down com centro de formação fixo. Os combatentes recebem listas de alvos do tipo oposto; a arena instancia quatro heróis locais independentes, sem implementar multiplayer.

## Separação de estado

Manter conceitualmente separados:

- **Estado permanente do personagem:** nível, atributos, equipamentos, classe e presets de builds.
- **Estado temporário da run:** progresso e escolhas válidos somente durante aquela run, incluindo níveis, atributos, habilidades e modificadores temporários.

As regras de transição, morte, salvamento e persistência ainda não estão definidas. A arquitetura não deve fixá-las antes de aprovação.

## Conteúdo, lógica e apresentação

- **Definições de conteúdo:** usar `Resource` tipados para dados reutilizáveis de classes, habilidades, itens, inimigos e modificadores, quando esses conteúdos forem introduzidos.
- **Lógica de jogo:** manter regras e alterações de estado fora da camada de apresentação. A lógica de combate deverá poder considerar builds e efeitos de jogador e inimigos, sem exigir sistemas paralelos prematuros.
- **Apresentação:** cenas e scripts de interface exibem o estado do jogo e encaminham entradas; o HUD não deve ser responsável por calcular combate ou progressão.
- **Estado em execução:** manter instâncias mutáveis da run separadas das definições reutilizáveis de `Resource`, evitando que uma run altere dados compartilhados de conteúdo.

Esses são limites de responsabilidade, não uma exigência de criar serviços, autoloads ou frameworks antes de haver uso concreto.

## Recorte técnico do combate inicial

- CombatStats e HeroBuildConfig são definições em Resource; vida atual, cooldowns, alvo e estado da run pertencem às instâncias mutáveis.
- CombatRules concentra a mitigação e o cálculo da posição radial provisórios. HeroCombatant controla movimento, alvo e ataque automáticos; EnemyCombatant persegue e ataca; PhysicalProjectile usa colisão Area2D com alvos válidos do lado oposto ao atacante.
- CombatArena mantém o centro e o raio da formação, cria inimigos de lados diferentes, conecta ataques e encerra/reinicia a run. CombatHud apresenta o estado e envia alterações de configuração, sem calcular combate.
- A resolução interna permanece 960×540; Gameplay 03 amplia a arena lógica para 1280×720 unidades, separada da Camera2D com zoom exportado. O centro da formação fica acima do centro visual para permanecer visível com um painel aberto no zoom padrão. CombatHud usa CanvasLayer e âncoras de viewport para não herdar o zoom; CombatPanel fornece uma base comum para painéis com conteúdo rolável.
- A navegação inferior permanece visível; o painel ativo ocupa até cerca de 30% da altura disponível e recolhe quando selecionado novamente. Colunas de navegação e altura útil se adaptam ao viewport, mantendo status e reinício visíveis. Conteúdo futuro de Skills, Inventory e Loot permanece fora do escopo.
- HeroCombatant reduz o cooldown independentemente do movimento e verifica ataques prontos antes de se reposicionar. Para não-tanques, separa alcance de ataque, detecção de 110% do alcance ativo e região radial permitida; persiste o alvo até ultrapassar a distância de liberação, faz kiting dentro da região e retorna ao ponto preferido sem alvo. O caminho de interceptação do Tank permanece separado e inalterado.
- A configuração radial e o modo de ataque ficam na cópia ativa da build para não alterar o Resource reutilizável. Classes completas, comportamentos padrão completos, persistência e multiplayer ficam para incrementos aprovados posteriores.
- Gameplay 03 instancia quatro HeroCombatant com builds e stats independentes. Cada EnemyCombatant mantém ameaça por herói, calculada a partir do dano recebido e do multiplicador da build. O alvo é o herói vivo de maior ameaça, com proximidade como desempate e fallback. O Tank seleciona o inimigo mais próximo do centro e se move para interceptá-lo. PhysicalProjectile usa a máscara de colisão correspondente ao lado atacante, permitindo interceptação de disparos inimigos por outro herói. A referência à fonte é fraca; se a fonte for liberada antes do impacto, o dano ainda é aplicado sem atribuição inválida. CombatArena controla derrota da party; CombatHud apresenta vida e configuração do herói selecionado.
- Gameplay 04 introduz ClassDefinition como Resource reutilizável por arquétipo. Cada HeroBuildConfig ativo duplica Stats e ClassDefinition; HeroPassiveState é um objeto mutável independente por HeroCombatant para contadores e temporizadores. A arena resolve cura, geração de projéteis e ciclo de vida; CombatSandbox apenas emite comandos, validados e limitados pela arena. Isso separa overrides temporários de definições permanentes e de progressão futura.
- Fireballs usam PhysicalProjectile com etiqueta de elemento `fire`; o evento público `record_skill_cast` prepara integração futura sem antecipar skills ou resistências. Furtividade altera a pontuação de escolha de alvo do inimigo, sem alterar máscaras de colisão. A simulação multiplica o delta de heróis, inimigos e projéteis, enquanto o HUD permanece responsivo quando pausada.
- Gameplay 04B mantém cartões persistentes de herói no CombatHud e seções estáveis no CombatSandbox. Comandos de edição usam o ID da instância selecionada para evitar aplicar mudanças ao herói errado após alterações na lista. A arena é dona da seleção e do ciclo de vida; o HUD apenas apresenta estado e emite ações. Diagnósticos são opcionais e exclusivos do desenvolvimento. A atualização de dados do HUD ocorre a cada 0,2 s, além das alterações imediatas de seleção/painel, para limitar trabalho repetido por frame.
- Para heróis não-tanque, alvos à distância fora do alcance geométrico da região radial são liberados; isso evita ataque pronto permanentemente bloqueado na borda. Cooldowns de inimigos avançam sem alvo, e editar a velocidade de ataque preserva a fração restante do cooldown. O caminho aprovado de interceptação do Tank permanece separado.
- tests/combat/test_combat.gd cobre regras, movimento, alvo, ataque, colisão física, ciclo da run, câmera, painéis, passivas, composições dinâmicas, comandos Sandbox e layout após redimensionamento; a validação Full executa esses testes após importar o projeto. Importação e testes headless não substituem avaliação visual e de balanceamento.

## Responsabilidades previstas

- **Personagem/progressão permanente:** representar o estado duradouro definido pelo design.
- **Run/dungeon:** acompanhar o estado temporário e o avanço da run, respeitando regras de gameplay aprovadas.
- **Combate:** resolver interações entre participantes, atributos, habilidades e modificadores conforme regras aprovadas.
- **Conteúdo:** fornecer definições reutilizáveis para entidades e opções de jogo.
- **HUD:** apresentar informações relevantes do personagem, inimigo e run.

Persistência e salvamento ficam fora do escopo arquitetural inicial até que as regras de continuidade sejam decididas.

## Implicações de design para a arquitetura

Estes pontos registram necessidades conceituais que decorrem do design; não prescrevem soluções técnicas, sincronização ou formato de dados.

- O jogo distingue estado individual (personagem, classe, build, mochila, escolhas de Arcana e drops) de estado compartilhado da party/dungeon (condições geradas, progresso da dungeon, evolução de monstros e recompensas compartilhadas). As fronteiras exatas ainda dependem das regras de grupo e recompensas.
- A preparação de uma run tem uma ordem de design: gerar e revelar condições da dungeon, permitir inspeção, selecionar um preset por jogador e então entrar. A escolha da especialização de equipamento também ocorre antes da entrada; sua ordem em relação às demais escolhas está em aberto.
- Builds inimigas, modificadores de dungeon, evolução de monstros, tabelas de loot, raridades, afixos e intervalos de atributos são conceitos de conteúdo. `Resource` tipados podem descrevê-los quando forem necessários, sem antecipar um esquema completo.
- As restrições aprovadas de equipamento são regras de personagem: Mythic admite até dois itens em slots flexíveis; Divine admite até um item, apenas em Necklace ou Off-hand, independentemente do limite Mythic. O modelo de dados futuro deverá representar essas restrições sem decidir agora os demais slots ou efeitos específicos.
- O fluxo de recompensas precisa preservar drops individuais e a regra estabelecida de que itens salvos e recursos permanentes não são removidos diretamente pela morte. A interface e o momento exato em que uma escolha de mochila se torna final permanecem por definir.
- A morte individual e o fim de uma party têm resultados diferentes na visão multiplayer. Efeitos de prevenção ou respawn dependem de condições próprias; os limites, tempos e custos ainda não estão definidos.
- O limite de até quatro jogadores torna importante manter claros os conceitos de estado individual e compartilhado antes de ampliar o multiplayer. Isso não define transporte, autoridade de rede, formato de sessão ou arquitetura cliente/servidor.

## Decisões técnicas adiadas

- Não escolher backend, modelo de sessão, sincronização, autoridade de simulação, matchmaking ou persistência multiplayer com base apenas na visão de quatro jogadores.
- Não definir serialização ou salvamento de estado da run antes de decidir continuidade, encerramento e seleção final de recompensas.
- Não criar sistemas separados para fase principal e farm pós-chefe, engenharia do HUD, extração de afixos, evolução de monstros ou Arcana antes que o escopo aprovado exija essas implementações.

## Estrutura inicial de pastas

Estrutura recomendada para crescer conforme arquivos reais forem necessários:

```text
AGENTS.md
docs/
  GAME_DESIGN.md
  ARCHITECTURE.md
  ROADMAP.md
assets/
  sprites/
  fonts/
  audio/
data/
  classes/
  skills/
  items/
  enemies/
  modifiers/
scenes/
  main/
  hud/
  combat/
scripts/
  player/
  run/
  combat/
  enemies/
  ui/
```

Criar somente diretórios que recebam conteúdo real. A árvore acima é uma proposta, não uma lista de diretórios que precisam existir agora.

## Configuração do projeto

O `project.godot` atual não deve ser alterado como parte desta proposta. A configuração de física 3D Jolt está registrada para revisão futura, caso o protótipo confirme que o projeto não precisa dessa configuração. Nenhuma mudança é recomendada nesta etapa documental.
