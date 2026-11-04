# Game Design

## Visão

Endless Dungeon é um idle RPG com runs de dungeon e inspiração roguelite. O personagem combina progressão permanente com progresso temporário de cada run. A dungeon pode avançar indefinidamente, com dificuldade e recompensas crescentes. O jogo é planejado como experiência offline-first, inicialmente para Windows, com estilo pixel art.

Esta visão registra a direção atual; não define regras de gameplay que ainda não foram aprovadas.

## Requisitos confirmados

- O projeto será desenvolvido em Godot 4 com GDScript.
- O jogo será offline-first; backend e multiplayer não fazem parte das primeiras versões.
- O personagem terá progressão permanente envolvendo nível, atributos, equipamentos, classe e presets de builds.
- Cada run terá progressão temporária própria, incluindo níveis, atributos, habilidades e modificadores.
- A dungeon poderá ter progressão infinita, com dificuldade e recompensas crescentes.
- A morte encerra a run e reinicia sua progressão temporária; a preservação da progressão permanente ainda será definida.
- Inimigos deverão poder ter builds, atributos, habilidades e modificadores; não devem ser apenas valores maiores de vida e dano.
- O HUD deverá apresentar informações do jogador e dos inimigos. A disposição pode colocar jogador e inimigo em lados opostos da tela.
- O estilo visual planejado é pixel art e o alvo inicial é Windows.
- O conteúdo de classes, habilidades, itens, inimigos e modificadores deverá ser orientado a dados.
- O protótipo inicial deve ser pequeno e evitar abstrações prematuras.

## Primeira meta de protótipo aprovada

Um protótipo 2D com um personagem, um inimigo, combate automático, HUD básico e progressão temporária simples. Esta meta delimita uma etapa verificável; detalhes das regras de combate, progressão e recompensa continuam pendentes.

## Ideias e sugestões ainda não aprovadas

- Apresentar jogador e inimigo em lados opostos do HUD.
- Usar arquétipos de inimigos como forma inicial de demonstrar builds distintas.
- Expandir futuramente o conteúdo e os sistemas conforme o protótipo validar o loop principal.

Esses itens são possibilidades para avaliação, não compromissos de implementação.

## Questões em aberto

- O que a morte preserva, perde ou converte entre a run e a progressão permanente?
- Como e quando o progresso é salvo? Uma run pode ser retomada após fechar o jogo?
- Como funcionam combate automático, ritmo idle, pausa e eventual progresso offline?
- Como são concedidas as recompensas e como elas afetam progressão permanente e temporária?
- Quais atributos, recursos, classes, habilidades, equipamentos e modificadores existem?
- Como escalam dificuldade e recompensas, e quais limites práticos existem para uma dungeon infinita?
- Como são construídas e selecionadas as builds dos inimigos?
- Quais informações o HUD precisa mostrar e qual será sua composição visual final?
- Qual é o escopo de controles, resolução, distribuição e suporte além do alvo inicial Windows?

Nenhuma resposta para essas questões deve ser presumida durante a implementação.
