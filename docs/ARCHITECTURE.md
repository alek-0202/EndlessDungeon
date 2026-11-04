# Arquitetura

## Direção

- Engine: Godot 4.
- Linguagem: GDScript.
- Desenvolvimento inicial offline-first, sem backend ou multiplayer nas primeiras versões.
- Manter o protótipo pequeno; adicionar estrutura quando uma necessidade concreta surgir.

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

## Responsabilidades previstas

- **Personagem/progressão permanente:** representar o estado duradouro definido pelo design.
- **Run/dungeon:** acompanhar o estado temporário e o avanço da run, respeitando regras de gameplay aprovadas.
- **Combate:** resolver interações entre participantes, atributos, habilidades e modificadores conforme regras aprovadas.
- **Conteúdo:** fornecer definições reutilizáveis para entidades e opções de jogo.
- **HUD:** apresentar informações relevantes do personagem, inimigo e run.

Persistência e salvamento ficam fora do escopo arquitetural inicial até que as regras de continuidade sejam decididas.

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
