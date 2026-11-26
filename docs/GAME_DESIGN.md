# Game Design

## Como ler este documento

- **Decisões estabelecidas** registram a visão e as regras explicitamente definidas até agora.
- **Valores tentativos e exemplos** são referências iniciais, exemplos ou propostas de balanceamento; não devem ser tratados como valores finais.
- **Questões em aberto** exigem decisão antes de qualquer implementação que dependa delas.

Uma regra estabelecida pode ainda precisar de detalhes operacionais. Esse detalhe não deve ser inventado silenciosamente.

## Visão do jogo

Endless Dungeon é um RPG idle inspirado em MMO e roguelike, centrado em runs de dungeon, progressão de longo prazo e personalização profunda de builds. O combate é automático: o jogador não controla diretamente cada ação do personagem. A estratégia vem da progressão, seleção de build, equipamentos, escolhas de habilidades e interação com sistemas da dungeon.

A visão inclui partidas multiplayer de até quatro jogadores, cada qual com personagem e build próprios. A modalidade de rede e o momento em que funcionalidades multiplayer entram no desenvolvimento ainda não estão definidos. O primeiro protótipo não precisa incluir todos os recursos multiplayer.

O protótipo inicial mantém a direção offline-first já estabelecida; isso não elimina o multiplayer da visão de longo prazo nem decide que capacidades multiplayer entram em cada versão.

A direção visual inicial é pixel art. O alvo inicial de desenvolvimento é Windows desktop, usando Godot 4 e GDScript. O jogo deve incentivar experimentação, runs repetidas, builds viáveis diferentes e adaptação às condições aleatórias da dungeon.

## Decisões estabelecidas

### Personagens, classes e builds

- Cada personagem pode progredir independentemente em classes diferentes.
- A visão prevê classes com funções distintas, incluindo tanque, dano à distância, maga de controle de grupo, curandeiro e suporte. Essa lista descreve funções desejadas, não um elenco final de classes.
- A progressão permanente inclui níveis de classe, atributos, equipamentos, especializações e presets de build salvos.
- O jogador pode salvar vários presets. Cada preset define quais habilidades estão disponíveis para aquela build; não é possível usar todas as habilidades simultaneamente.
- Depois de conhecer os modificadores da dungeon, o jogador escolhe um preset salvo antes de entrar.
- Durante a run, o personagem desbloqueia e aprimora as habilidades disponíveis pelo preset escolhido.
- Ao subir de nível, o jogador recebe escolhas de atributos e pontos de habilidade.
- Builds especializadas em ganho de experiência podem progredir mais rápido, mas devem envolver contrapartidas significativas.

### Runs e dungeons

- Runs podem continuar potencialmente sem limite.
- Cada dungeon tem nível e sua própria tabela de loot; dungeons diferentes podem ter itens exclusivos.
- O nível da dungeon limita a maior raridade de item que pode cair. Ficar mais tempo em uma dungeon pode gerar mais recursos e itens, mas não ultrapassa esse limite de raridade.
- Uma run tem duas fases:
  1. **Progressão e chefe final:** combate a monstros e elites, ganho de experiência, ouro, moeda de monstros e itens, desenvolvimento da build temporária e investimento na evolução dos monstros até o chefe final. Derrotar o chefe conclui o objetivo principal da dungeon.
  2. **Farm opcional após o chefe:** depois de derrotá-lo, o jogador pode continuar indefinidamente para obter itens e recursos temporários que melhoram as recompensas finais. A contribuição desses recursos tem um limite máximo; as regras desse limite ainda serão definidas.
- Morrer encerra a run e seu progresso temporário, tanto antes quanto depois do chefe. A run pode conceder recompensas permanentes mesmo se durar apenas um minuto; morte não apaga todas as recompensas.
- Morte não remove diretamente recursos permanentes nem itens previamente salvos.
- Cada dungeon gera atributos e modificadores aleatórios no início; eles afetam a dungeon e seus inimigos, levando os jogadores a adaptar a estratégia. Os jogadores inspecionam essas condições e escolhem seus presets antes de entrar, nesta ordem: gerar modificadores, inspecioná-los, escolher preset e entrar.
- Os modificadores devem incentivar adaptação sem tornar classes ou estilos de jogo inteiramente inviáveis.
- O jogador escolhe uma especialização de equipamento antes de entrar — por exemplo, arma principal, armadura ou anéis. A run só gera itens de equipamento elegíveis para a especialização escolhida.
- Dungeons especiais podem oferecer recompensas extremamente raras.

### Equipamentos, raridade e builds

As seis categorias de raridade estabelecidas são Common, Rare, Legendary, Special, Mythic e Divine. Raridade não é uma escala linear simples de poder; Legendary e Special podem ter poder semelhante, mas propósitos de design diferentes.

- **Common:** equipamento básico com atributos-base.
- **Rare:** equipamento com combinações de atributos-base.
- **Legendary:** atributos-base e afixos Legendary. A partir de Legendary, afixos podem melhorar passivas ou mecânicas existentes, introduzir efeitos passivos ou criar sinergias. Um mesmo afixo Legendary pode aparecer em categorias de equipamento diferentes.
- **Special:** segue o conceito de item Unique de Diablo IV: identidade predefinida, efeito próprio, atributos e possíveis intervalos de valores específicos, podendo ter efeitos próprios de classe. Não é um Legendary comum com afixos intercambiáveis.
- **Mythic:** categoria inspirada no conceito de tier Mythic, mas com identidade e mecânicas originais. São equipamentos únicos e mais poderosos. Um personagem pode equipar no máximo dois Mythics simultaneamente. O jogador escolhe livremente quais categorias de equipamento podem conter Mythics; essa seleção pode ser alterada e não fica permanentemente vinculada ao personagem.
- **Divine:** exclusivo dos slots de equipamento Necklace e Off-hand. Um personagem pode equipar no máximo um Divine simultaneamente. Esse limite é independente do limite de dois Mythics: dois Mythics e um Divine podem estar equipados ao mesmo tempo. Divine tem efeitos distintos e, em geral, é ligeiramente mais forte devido à sua exclusividade. A flexibilidade dos slots elegíveis para Mythic permanece.

Os atributos dos itens rolam dentro de intervalos mínimo e máximo explícitos. A variação deve dar motivo para buscar versões melhores do mesmo item. Itens de alta raridade devem priorizar atributos e mecânicas fundamentais, sem obrigar o jogador a usar uma habilidade específica nem convergir para uma build predeterminada. A direção também admite sinergias entre itens e passivas e, em alguns casos, interações específicas de classe.

### Ferreiro, afixos e itens Perfect

- O ferreiro é um ponto importante da progressão permanente. Suas responsabilidades de design incluem extrair e transferir afixos Legendary, manipular equipamento, oferecer o sistema de aprimoramento Perfect e abrigar outros sistemas de equipamento que possam ser aprovados futuramente.
- Inspirado no sistema de extração e transferência de afixos Legendary de Diablo IV, o jogador poderá extrair um afixo de um item e transferi-lo para outro item elegível, por exemplo para conservar bons atributos-base e substituir um afixo indesejado. Custos, restrições e regras para transferências repetidas permanecem abertos.
- O sistema Perfect permite gastar um recurso raro obtido em dungeons para tentar transformar um item. A tentativa custa duas unidades, tem 5% de chance de sucesso, consome os recursos independentemente do resultado e não destrói nem altera o item em caso de falha.
- Em caso de sucesso, todos os atributos-base passam a 150% do máximo possível após a escala do nível do item:

  `Atributo Perfect = máximo do atributo após escala de nível × 1,5`

- O sistema Perfect é um objetivo de longo prazo de endgame. Nenhuma proteção adicional, sistema de garantia ou método alternativo de aprimoramento foi estabelecido.

### Mochila, drops e seleção de recompensas

- Cada jogador tem uma mochila individual de capacidade limitada durante a run.
- Drops de itens são atribuídos individualmente. O jogador decide quais manter e quais descartar, durante a run ou ao final, sem temporizador de decisão.
- Ao terminar a run, cada jogador recebe uma interface individual para escolher quais itens salvar, respeitando a capacidade da mochila. Itens escolhidos e salvos ficam permanentemente retidos e não são perdidos por morte ou por não derrotar o chefe final.
- Se a quantidade total de itens obtidos for menor que a capacidade disponível, a tela de seleção é ignorada e todos os itens são salvos.

### Multiplayer e recompensas compartilhadas

- A visão multiplayer comporta até quatro jogadores; cada jogador possui personagem e build individuais.
- Personagens de nível alto ou presets avançados podem ajudar personagens de nível baixo em dungeons avançadas.
- Recompensas são compartilhadas, exceto drops individuais de itens. Ouro é compartilhado.
- Atributos de build e outros efeitos podem contribuir para bônus de recompensa compartilhados; investimento de mais de um jogador no mesmo bônus pode aumentar o benefício do grupo.
- A dungeon tem uma árvore compartilhada de evolução dos monstros. Durante uma run, jogadores investem moeda de monstros para modificar e fortalecer inimigos, podendo escolher melhorias com trade-offs de risco e recompensa.
- Se todos os jogadores morrerem, um efeito elegível de item, passiva ou outra fonte pode permitir o respawn de um jogador, de acordo com sua condição. Se nenhum efeito permitir respawn, a run termina imediatamente. Não há sistema genérico de vidas compartilhadas por padrão.

### Combate, perigo e progressão da run

- O combate é automático, mas deve conter interações significativas entre causar e receber dano e expor o jogador a perigo real.
- A apresentação de combate aprovada é 2D top-down em pixel art. A formação dos heróis é circular, estacionária e tem centro fixo; inimigos se aproximam de todas as direções.
- Movimento, seleção de alvo e ataques são automáticos. Cada build configura a posição radial preferida do personagem entre 0% (centro) e 100% (borda da formação). Classes terão comportamentos padrão próprios, personalizáveis pela build; classes completas e seus padrões ainda não foram definidos.
- Heróis com comportamento de kiting preferem atacar no maior alcance efetivo do modo ativo: aproximam-se apenas até entrar em alcance, atacam assim que estiverem prontos e interrompem o movimento ao atacar. Durante o cooldown, afastam-se quando o inimigo encurta a distância; nunca saem da formação circular. O Tank prioriza interceptação conforme Gameplay 03. Para os demais, o alcance radial configurado limita a região de movimento, com pequena tolerância provisória.
- Cada inimigo pode escolher heróis individualmente por ameaça; a presença de um tanque não garante proteção dos demais. Personagens na retaguarda ainda precisam considerar investimento defensivo.
- Projéteis são entidades espaciais e podem ser interceptados por colisão com alvos válidos. Regras finais de prioridade de alvo, trajetória, bloqueio e efeitos permanecem abertas.
- A evolução dos monstros deve ir além de aumentar vida e dano. A visão contempla habilidades, passivas, atributos, resistências, imunidades e modificadores com características de build.
- Itens, passivas e efeitos podem prevenir a morte ou fortalecer o personagem quando está perto da morte ou depois de morrer.
- Cada jogador recebe duas Arcana aleatórias por run: uma no nível 15 da run e outra no nível 30. Arcana são atribuídas individualmente, diferem das cartas comuns de atributos e podem alterar significativamente uma build, interagindo com classe, equipamento, atributos e mecânicas existentes.

### Apresentação e interação

- O HUD deve oferecer interação significativa além de observação passiva e gestão básica de recursos.
- O mapa deve ser mais interessante que uma plataforma plana onde monstros apenas caminham até o jogador, sem exigir ambientes desnecessariamente complexos.
- Pixel art 2D top-down é a direção visual do combate. Detalhes de câmera, estrutura do mapa e navegação fora da arena inicial ainda não foram finalizados.
- Para o protótipo de arena, a resolução lógica provisória é 960×540, com 1920×1080 como referência desktop. Manter filtragem nearest para futuros sprites em pixel art; o zoom da câmera é configurável sem alterar as unidades de combate.
- O HUD usa uma faixa compacta de estado de combate e navegação inferior persistente. Painéis recolhíveis de Character, Skills, Inventory, Loot, Tactics e Stats ocupam aproximadamente 30% da altura quando abertos; trocar ou fechar um painel não pausa o combate. Estatísticas detalhadas ficam em Character/Stats e controles de posicionamento e ataque em Tactics. Os demais painéis são bases de interface, sem sistemas de gameplay associados neste incremento.

### Recorte jogável de Gameplay 01

O primeiro protótipo apresenta uma arena estacionária, um herói controlado automaticamente, inimigos que surgem de lados diferentes, movimento e seleção automática de alvo, ataques corpo a corpo e projéteis físicos, colisão com alvos válidos, vida, dano, armadura, alcance, frequência de ataque e velocidade de movimento. O HUD mostra o estado de combate, permite ajustar o raio preferido e alternar o ataque demonstrativo; a morte do herói encerra a run local e há reinício. O protótipo usa formas simples no lugar de assets finais.

Após o playtest manual inicial aprovado pelo responsável, Gameplay 01 passou a incluir kiting automático nos dois modos de ataque. A distância preferida é o alcance máximo efetivo, limitada pela borda da formação; a pequena tolerância de posicionamento evita ajustes repetidos e não impede ataques disponíveis.

O responsável aprovou manualmente o combate inicial e o kiting antes de Gameplay 02. A arena lógica foi ampliada para comportar crescimento futuro de grupo e hordas; a formação, os atributos e as distâncias relativas de spawn do protótipo permanecem iguais. O layout do HUD se adapta ao tamanho da janela sem sobrepor controles.

Os valores em data/combat/ e a mitigação de armadura, a escolha do alvo mais próximo, a preferência radial, a tolerância de posicionamento e o ritmo de spawn são provisórios para demonstração e testes. Eles não estabelecem fórmulas nem balanceamento permanente. Não há classes completas, skills, equipamento, progressão, sistema avançado de ameaça ou multiplayer neste recorte.

### Recorte jogável de Gameplay 03

A simulação local passa a usar quatro heróis independentes com arquétipos provisórios: Tank (90% de raio preferido), Assassin (75%), Archer (30%) e Mage (15%). Cada build conserva atributos, vida, cooldown, movimento, alvo e configuração próprios. Cada inimigo mantém sua tabela de ameaça: dano efetivamente recebido gera ameaça, multiplicada por um modificador configurável da build; sem ameaça, escolhe o herói vivo mais próximo. O Tank busca interceptar o inimigo mais próximo do centro da formação e proteger o grupo, em vez de recuar genericamente. Os demais preservam o kiting automático.

Inimigos corpo a corpo e à distância coexistem. Projéteis inimigos colidem com o primeiro herói válido no caminho, inclusive quando não era o alvo escolhido. Heróis podem morrer separadamente; a run termina quando todos morrem. O HUD permite selecionar e configurar cada herói e mostra a vida compacta da party. A arena, a formação e a densidade de inimigos foram ampliadas com valores provisórios em recursos e propriedades exportadas. A simulação não representa multiplayer, classes completas, skills, ressurreição, equipamentos, progressão ou rede. Fórmulas finais de ameaça, proteção e balanceamento permanecem abertas.

Após playtest manual, o Tank conserva seu movimento de interceptação aprovado. Os outros heróis se mantêm dentro de uma região circular cujo raio máximo é o percentual preferido da formação mais uma pequena tolerância configurável, limitado pela borda da formação. Sem alvo, retornam ao ponto radial preferido. O alcance inicial de detecção é 110% do alcance efetivo de ataque; alvos além do alcance de engajamento são liberados, com margem igual à tolerância radial para evitar troca repetida. Enquanto houver alvo, os heróis se aproximam somente até o alcance de ataque e fazem kiting até o limite da região. São regras provisórias de posicionamento, não fórmulas finais de classe ou balanceamento.

### Recorte jogável de Gameplay 04

O responsável aprovou o comportamento atual da party. Tank, Assassin, Archer e Mage passam a ter definições de classe reutilizáveis com vantagens naturais, sem restringir builds. Os números de atributos e parâmetros de passivas são provisórios. O Tank conserva a interceptação e a geração de ameaça, tem vida alta e mobilidade maior que a do Archer. A cada 30 segundos, divide um orçamento de cura de 20 pontos percentuais entre os aliados vivos feridos, calculando cada parcela pela vida máxima do destinatário; parcelas não utilizadas vão prioritariamente para quem tem menor percentual de vida.

O Archer prioriza dano básico alto e mobilidade normal. Após dez ataques básicos, sua velocidade de ataque efetiva é multiplicada por 1,5 durante cinco segundos. Segue-se cooldown de dez segundos. Ataques durante ativação ou cooldown não contam, acumulam ou renovam a passiva. A Mage tem mobilidade e dano básico baixos, dano de skill alto e, após cinco ataques básicos ou três casts de skill, lança três fireballs contra os inimigos vivos mais próximos. A ativação zera ambos os contadores. Cada fireball usa provisoriamente 100% do dano de skill e pode repetir alvo se houver menos de três inimigos. O evento de cast está preparado para integração futura; o sistema completo de skills ainda não existe. Os projéteis carregam um identificador de elemento, sem criar resistências ou fórmula elemental neste incremento.

O Assassin tem mobilidade alta e bônus de dano contra inimigos à distância. Prioriza esses inimigos dentro de uma distância de caça configurável, pode sair temporariamente da formação e depois recua. Sua furtividade temporária reduz a prioridade na escolha de alvo dos inimigos, mas não a impede; atacar quebra a furtividade e inicia seu cooldown. Se for o único herói válido, continua selecionável. Furtividade não altera colisão de projéteis nem dano de área futuro. Limites, durações e multiplicadores não explicitamente aprovados são configuráveis e provisórios.

O painel Sandbox, disponível apenas em builds de desenvolvimento/editor, permite ajustar heróis, inimigos e velocidade da simulação durante o combate, inclusive composições solo e classes duplicadas. Suas alterações afetam apenas as instâncias ativas; não representam progressão nem modificam as definições de classe. Os limites de quantidade de heróis e inimigos são configuráveis. Equipamento, progressão, multiplayer, classes completas e sistema completo de skills continuam futuros.

### Refinamento de Gameplay 04B

O responsável aprovou manualmente Gameplay 03, Gameplay 04 e Gameplay 04B. O HUD de desenvolvimento apresenta cartões persistentes de cada herói, com vida, classe, progresso e temporizadores de passiva. A seleção pela arena ou pelos cartões alimenta um único estado para todos os painéis. O Sandbox agrupa controles existentes em Heroes, Attributes, Passives, Enemies e Simulation, com edição do herói selecionado distinta das configurações globais. O painel de diagnósticos é opcional e mostra o estado de ataque e atributos efetivos. Essas alterações refinam observabilidade e uso do protótipo, sem acrescentar mecânicas ou fixar a arte final.

## Valores tentativos e exemplos

Os números desta seção ilustram alvos ou propostas iniciais; não são balanceamento final, salvo quando reiterados como regra explícita na seção de decisões estabelecidas.

- **Progressão de habilidades:** o limite pretendido é aproximadamente o nível 30. Até esse ponto, as habilidades selecionadas no preset devem poder ser totalmente aprimoradas; níveis posteriores concederiam atributos em vez de aprimoramentos adicionais de habilidades. Requisitos de experiência devem crescer exponencialmente para que o ganho ilimitado de atributos não se torne trivial.
- **Penalidade/tempo após morte:** sequência inicial ilustrativa: primeira morte, 30 segundos; segunda, 1 minuto; terceira, 5 minutos; quarta, 10 minutos. Não é balanceamento final e ainda não define o que esse tempo representa.
- **Recurso Perfect:** aquisição esperada de aproximadamente 0 a 3 unidades em uma run longa de endgame. É uma estimativa inicial.
- **Mochila:** 20 espaços é um exemplo inicial de capacidade, não um valor final.
- **Teto de raridade:** a primeira dungeon de nível 1 ter Common como raridade máxima é um exemplo da regra de teto por nível, não uma tabela completa de raridades.
- **Atributos de item de nível 1:** dano 20–45 com exemplo de rolagem 30; velocidade de ataque 25%–45% com exemplo 40%; armadura 50–100 com exemplo 50. São números para ilustrar intervalos e cálculo, não dados finais de itens.
- **Atributos Perfect no exemplo acima:** dano 67,5; velocidade de ataque 67,5%; armadura 150, correspondendo a 150% dos máximos do exemplo. Não são valores de balanceamento finais.
- **Atributos e mecânicas de equipamento:** exemplos de direção incluem velocidade de ataque, chance e dano crítico, dano elemental, dano ao longo do tempo, resistências, regeneração, roubo de vida, redução de dano, geração de recurso e velocidade de movimento. A lista não é fechada.
- **Modificadores de dungeon:** exemplos não finais incluem resistências altas a fogo e dano físico com 50% menos eficácia de controle de grupo, incentivando dano alternativo e builds de dano direto; ou limitar o dano de um golpe a 10% da vida máxima do monstro, aumentando o valor relativo de velocidade de ataque, dano ao longo do tempo e controle de grupo. São propostas estratégicas, não modificadores finais; sua combinação ainda precisa ser avaliada contra a regra de não inviabilizar classes ou estilos.
- **Evolução dos monstros:** exemplos não finais incluem (A) taxa de surgimento +50%, +2 de ouro por monstro morto, vida dos monstros +10% e dano +10%; (B) escudos iguais a 50% da vida máxima em troca de +75% de experiência e ouro para jogadores. Fantasmas imunes a dano físico, elites com redução geral de dano muito alta e chefes imunes a controle de grupo ou certas mecânicas de dano bônus são propostas que ainda precisam ser avaliadas contra a regra de não inviabilizar classes ou estilos de jogo.
- **Dungeon especial:** chance de aproximadamente 0,001% para um item Divine é apenas um exemplo de taxa de drop; a categoria Divine está estabelecida, mas essa chance e sua fonte de drop não estão.

## Ideias ainda não aprovadas

- Um painel compacto de engenharia no HUD, com componentes que o jogador organiza e modifica; layout, adjacência ou conexões poderiam determinar atributos ou tipos de dano. O propósito deve ser estrategicamente significativo, sem virar trabalho repetitivo sem valor.
- Os exemplos de classes, modificadores, criaturas, itens, atributos e upgrades são referências de direção, não listas de conteúdo aprovadas.
- Builds, atributos, itens e outros sistemas da dungeon podem influenciar probabilidades de drop; quais fontes participam e em que magnitude continuam sem aprovação.

## Questões em aberto

### Escopo e sessão

- O que “MMO-inspired” significa além de grupos de até quatro jogadores? A sessão será online, local, assíncrona ou terá outra modalidade? Como se formam e encerram grupos?
- Quais funcionalidades multiplayer entram no protótipo e em quais etapas? Como personagens de níveis diferentes são equilibrados em dungeons avançadas?
- Como funcionam pausas, tempo offline, desconexões e retomada de sessão?

### Classes, atributos e builds

- Qual é a lista inicial e final de classes, especializações, atributos, habilidades e passivas?
- Presets são específicos por classe? Quantos podem ser salvos e quais itens, especializações ou atributos cada preset determina?
- Como se resolvem escolhas de atributos e pontos de habilidade ao subir de nível?
- Qual é a curva de experiência, o limite prático de progressão e os trade-offs de builds focadas em experiência?
- Como e quando se escolhem as categorias elegíveis para Mythic?

### Runs, combate e morte

- Quais são as regras de dano, tempo de ação, recursos, controle de grupo, vitória sobre monstros e avanço dentro da dungeon?
- Qual fórmula final relaciona dano e armadura? Quais prioridades de alvo, padrões de classe e regras de movimentação dentro da formação substituirão os comportamentos provisórios do protótipo?
- Como os sistemas individuais de ameaça, colisão/interceptação de projéteis e outras formas de proteção se aplicam a múltiplos heróis?
- Como se obtêm recompensas permanentes numa run curta e como se distingue recompensa de run de recompensa final?
- Como o tempo indicado para mortes funciona? É espera, penalidade ou outra coisa? Quais são as condições, durações e custos de respawn?
- Quando uma morte individual afeta o participante, a party ou a run? O que ocorre se parte do grupo morrer e os demais continuarem?
- A afirmação de que morrer encerra a run precisa ser conciliada com a regra multiplayer de término quando todos os jogadores morrem e com efeitos condicionais de respawn. Qual é o significado de encerramento da run para um jogador morto enquanto a party continua?
- Como são escolhidos, consumidos e limitados efeitos que impedem morte ou permitem respawn?
- Quais são o limite de contribuição dos recursos pós-chefe e suas regras exatas?

### Dungeons, modificadores, inimigos e evolução

- Como são gerados atributos e modificadores, como se controla sua combinação e como se garante que as condições não invalidem uma classe ou estilo?
- Imunidades e reduções extremas sugeridas nos exemplos de inimigos e modificadores podem inviabilizar algumas builds. Quais limites ou alternativas preservam a regra de adaptação sem inviabilizar classes ou estilos?
- Como escalam nível e dificuldade da dungeon e como o nível determina a raridade máxima?
- Quais são os arquétipos, atributos, builds e regras de seleção dos inimigos?
- Quais upgrades pertencem à evolução dos monstros, como são financiados e como o grupo decide investimentos compartilhados?

### Itens, recompensas e ferreiro

- Quais são as chances, fontes e condições de drop de cada raridade, inclusive Divine? Dungeons especiais terão alguma relação exclusiva com Divine?
- Quais categorias de equipamento existem? Quais atributos, intervalos e fórmulas de escala por nível se aplicam a cada uma?
- Quais são os efeitos distintos de Divine e como se compara, na prática, sua força ligeiramente maior? A especialização de equipamento escolhida antes da run afeta a elegibilidade de drops Divine em Necklace e Off-hand?
- Como se calculam tabelas de loot por dungeon, itens exclusivos, chances raras e influência de builds, atributos e outros sistemas?
- Como funciona a atribuição individual de drops em partidas multiplayer?
- Se a mochila enche durante a run, qual é o fluxo? Uma escolha de manter/descartar feita durante a run é final ou só confirma a seleção final? Como capacidade e descartes interagem?
- Quais tipos de recompensa são compartilhados, e como experiência, moeda de monstros, ouro e bônus são distribuídos?
- Quais são custo, elegibilidade e regras de repetição para extrair e transferir afixos?
- Como se define o máximo após escala de nível e arredondamento para cada atributo no sistema Perfect?
- Quais raridades podem receber aprimoramento Perfect e transferência de afixos? A elegibilidade de Mythic e Divine para esses sistemas não foi definida.

### Arcana, HUD e apresentação

- Arcana são atribuídas automaticamente ou escolhidas entre opções? Qual é seu conjunto, duração e interação com níveis/presets?
- A engenharia do HUD será universal, específica de classe ou um sistema de progressão separado? Quais decisões estratégicas concretas ela oferece?
- Quais são os detalhes finais de câmera além do zoom configurável, estrutura e navegação do mapa além da arena inicial, e a composição visual final do combate e HUD?

Não resolva estas questões por inferência durante a implementação; atualize este documento quando decisões forem aprovadas.
