# Ações Básicas e Itens — Design

> Design dos **itens** (atuais e futuros) e das **ações básicas desarmadas**.
> Regra geral: **não equipar nenhum item garante as ações básicas** (Punch,
> Guard, Dash). Itens adicionam capacidades sobre essa base, podendo haver
> restrições conforme o design do minigame.

## Ações Básicas (sempre disponíveis, desarmado)

### Punch (ataque)
- Melee curta à frente (raio ~1.2 m / alcance 2D ~40 px), arco visual.
- Knockback 20–30 na direção do golpe; hit-stop 40 ms; cooldown 0.4 s.
- Não empurra o usuário. Bom para defesa de espaço e "empurrão" de precisão.

### Guard (defesa)
- Segurar: bolha/escudo azul na frente. Reduz knockback recebido em 80%.
- Enquanto guarda: movimento 50% mais lento, não pode atacar/disparar.
- Cooldown de ativação mínimo; pode cancelar a qualquer momento.
- Visual: escudo translúcido emissivo; ao bloquear, sparks azuis + clank.

### Dash (movimentação)
- Impulso rápido curto (0.16 s) com cooldown 0.65 s; invencível a knockback
  durante o dash.
- Rastro de partículas; usado para reposicionar e escapar de empurrões.

### Restrições (exemplos)
- Topdown: dash em 8 direções; punch vira "empurrão em área" pequena.
- Plataforma: dash só horizontal; punch pode dar um micro "hop" (saltinho)
  opcional para uso aéreo.
- Se um minigame tiver 3 itens, uma ação básica pode ser limitada (ex.: sem
  dash) para dar espaço aos itens — sempre documentado no minigame.

## Sistema de Itens (conceitual)

Todo item:
- Ocupa um slot; o personagem carrega no máximo **1 item equipado** (a
  média de 2 itens por minigame vem de haver 2 slots quando o minigame
  pede, ou itens que combinam 2 funções).
- Alternativa simples para a média: `slots = {1, 2, 3}` configurável por
  minigame em `MatchSettings` (`item_slots`).
- Cada item tem **uso primário** (botão esquerdo/disparo) e **uso
  secundário** (botão direito/habilidade) quando fizer sentido.
- Ações básicas nunca somem por causa de item — no máximo ficam
  restritas por decisão de design do minigame.

### Item: Ímã de Dois Polos (futuro)
- **Clique** alterna o polo (Norte = atrai, Sul = repele).
- **Segurar** (carregar) intensifica a força magnética (escala 1→3×).
- Aplica força radial sobre jogadores dentro do raio; afeta também o
  próprio ímã levemente (recuo) — permite manobras.
- Visual: campo magnético (linhas de força) + anel da cor do polo
  (Norte = azul, Sul = vermelho).
- Combina bem com minigames de "empurrar para a lava" sem projétil.

### Item: Katana do Hattori Hanzo (futuro)
- **Corte** (clique): slash de grande alcance com hit-stop forte; pode
  refletir projéteis (charge orb) de volta ao atirador.
- **Dash-corte** (segurar + clique): dash perfurante com invencibilidade
  curta (i-frame 0.15 s).
- Visual: rastro de lâmina (arc trail), sparks ao refletir.
- Alta habilidade, alto risco (alcance curto).

### Item: Capa de Teleporte (futuro)
- **Teleporte**: blink curto na direção do movimento (8 m), sem projétil.
- **Passo fantasma** (ao ser empurrado): se estiver com capa, ativa
  automaticamente um blink para trás (cooldown longo 6 s) — escapa de
  empurrões, mas pode te colocar na lava se usar mal.
- Visual: capa esvoaçante + rastro ciano de "sombras".

### Item: Explosão (futuro)
- **Uso**: detona uma carga em área — **empurra inimigos E propulsiona o
  usuário** na direção oposta (movimentação + empurrão).
- Segurar aumenta o raio e o auto-impulso; risco: se explodir muito perto
  da borda, o próprio usuário cai na lava.
- Visual: anel duplo (laranja p/ inimigos, branco p/ usuário) + fumaça.
- Ótimo para escape e ofensiva simultâneos.

## Configuração Futura (MatchSettings)
```gdscript
# (proposta — a implementar junto dos itens)
var item_slots: int = 2                 # 1, 2 ou 3 itens por minigame
var items_pool: Array[String] = ["charge_gun", "teleport_gun"]
var punch_enabled: bool = true
var guard_enabled: bool = true
var dash_enabled: bool = true
```
- `hellball_3d/platform/topdown` → itens `["charge_gun","teleport_gun"]`.
- Itens futuros entram no pool e os minigames escolhem a combinação.
