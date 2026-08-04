# Relatório — Roadmap + 2 Novos Minigames (Espadas e Ímãs)

> **Data:** 2026-08-03 · **Escopo:** diagnóstico do estado atual, críticas
> críticas/urgentes, roadmap e design de dois minigames: **Espadas** e
> **Ímãs**. Estilo: conciso e didático, seguindo `docs/items.md` e
> `docs/hellball.md`.

---

## 1. Estado atual (o que já existe)

| Camada | Status |
|---|---|
| Hellball 3D + 2D (Plataforma/Topdown) | ✅ funcionando |
| Ações básicas (Punch, Guard, Dash) | ✅ implementadas |
| 2 itens fixos (Charge Gun, Teleport Gun) | ✅ implementados, **mas hardcoded** |
| Game Feel (squash, hit-stop, shake, flash) | ✅ implementado |
| Áudio (SfxBus procedural) | 🟡 autoload pronto, sons **não conectados** |
| Sistema de itens genérico (`item_slots`, `items_pool`) | ❌ **proposto em `docs/items.md`, NÃO implementado** |
| Replicação de estado de ataque / projéteis | ❌ projéteis são **locais** (rivais não os veem) |
| Unificação de managers (3D/2D) | ❌ deferido (apontado na `CRITICA_REVISOR`) |

---

## 2. Críticas críticas e urgentes

> Ordenadas por impacto. As 🔴 **bloqueiam** os dois minigames novos; as 🟠
> degradam qualidade; as 🟡 são ajustes.

### 🔴 CRÍTICA 1 — Sistema de itens não existe de forma genérica (bloqueador nº 1)
Os itens estão **embutidos nos scripts de jogador** (`hellball_player.gd` e
`hellball_player_2d_base.gd`): cada um tem sua própria lógica de
`_broadcast_charge` / `_broadcast_punch`. O `MatchSettings` **não tem**
`item_slots`, `items_pool`, `punch_enabled`, `guard_enabled` nem
`dash_enabled` (tudo isso está **só proposto** em `docs/items.md`).
- **Por que é urgente:** sem a camada de slots, cada minigame novo (espada,
  ímã) vira mais um script de jogador com itens colados — o custo **explode
  e o código triplica**.
- **Ação:** antes dos minigames, criar `ItemSlot` (uso primário/secundário,
  cooldown, visual) + `MatchSettings.item_slots` / `items_pool` e
  `*_enabled` para as ações básicas.

### 🔴 CRÍTICA 2 — Duplicação de managers (bloqueador nº 2)
`hellball_manager.gd` (3D) e `hellball_manager_2d.gd` (2D) repetem
vidas/lava/vitória/placar. Cada minigame novo repetiria tudo.
- **Ação:** extrair base comum (métodos virtuais: `on_player_lava_touch`,
  `_eliminate_player`, `check_victory`, `request_swap`) e fazer os modos
  herdarem. Já foi apontado como "manager unification" na revisão anterior e
  ficou **deferred** — agora é o momento de pagar essa dívida.

### 🔴 CRÍTICA 3 — Estado de ataque não é replicado (bloqueia espada e ímã)
Projéteis/orbes são **locais**; rivais **não veem** o orbe do Teleport nem o
projétil do Charge. Para a **espada** (parry precisa ver o golpe do rival e
resolver o clash no servidor) e para o **ímã** (polo + projétil
eletromagnético), isso é fatal: parry dessincronizado = morte injusta.
- **Ação:** replicar **estado de ataque** (booleano `swinging` + direção por
  ~0,12 s), **polo** e **escudo** como `guarding`/`facing` já são replicados.
  O projétil pode continuar local se o **efeito** for por RPC (padrão atual),
  mas o *estado* do golpe precisa ser visível a todos.

### 🟠 CRÍTICA 4 — Anti-cheat fraco agrava com 1-hit-kill
RPCs `any_peer` com validação básica. Com **espada 1-hit-kill** e **força
magnética**, um cliente malicioso pode forjar morte/empurrão.
- **Ação:** morte e parry **decididos no servidor** com base no estado
  replicado (nunca por "matei" vindo do cliente); manter a validação de
  remetente (`get_remote_sender_id()`) em todo RPC de efeito novo.

### 🟠 CRÍTICA 5 — Áudio ainda não conectado
`SfxBus` (procedural) existe, mas nenhum som está plugado. Parry (clank) e
ímã (hum elétrico) são **50% do juice** nesses minigames.
- **Ação:** conectar `SfxBus.play(...)` nos eventos dos dois minigames, já
  seguindo `docs/gamefeel/06_audio.md`.

### 🟠 CRÍTICA 6 — Race conditions no game feel vão aparecer mais
Hit-stop usa `Engine.time_scale` global + `await`, e `flash_hurt` usa
`await` mutando material/modulate — sobreposição reverte cedo. Espada (parry
frequente) e ímã (empurrões constantes) disparam muitos efeitos ao mesmo
tempo.
- **Ação:** usar **hit-stop local/por-jogador** (contador já criado no 2D —
  replicar no 3D e nos novos) e cancelar tweens antes de reiniciar.

### 🟡 CRÍTICA 7 — Definir mira desde o início nos minigames novos
Topdown ainda não tem right-stick de mira (gamepad). Espada (arco frontal) e
ímã (projétil) dependem de direção de mira **determinística** — especificar
mouse + gamepad no design desde o começo.

### 🟡 CRÍTICA 8 — Config de partida não é estado replicado
`MatchPresets`/`MatchSettings` são aplicados localmente via RPC `call_local`
(depende de todos aplicarem igual). Aceitável para party game; registrar como
dívida conhecida.

---

## 3. Roadmap (fases)

> Princípio: **pagar a fundação antes de multiplicar conteúdo**. A ordem
> evita que cada minigame novo custe "dois minigames" de refatoração.

| Fase | Entrega | Esforço | Depende de |
|---|---|---|---|
| **0 — Fundação** | Sistema de itens genérico (slots/pool/restrições) + unificação dos managers + replicação de estado de ataque/polo | L | — |
| **1 — Infra de modos** | `mode_select`/`lobby`/`hud` genéricos (registry de modos em vez de `match` hardcoded); `MatchSettings` de itens | M | F0 |
| **2 — Minigame Ímãs** | Primeiro minigame novo (reusa o padrão de força radial do Charge — o mais barato, valida a infra) | M | F0, F1 |
| **3 — Minigame Espadas** | Segundo minigame (parry exige a replicação de F0; 1-hit-kill exige resolução no servidor) | M–L | F0, F1 |
| **4 — Polimento** | Áudio conectado, hit-stop local, presets novos, balanceamento, game feel específico por minigame | S–M | F2, F3 |

> 💡 **Por que Ímãs antes de Espadas?** O ímã reusa 1:1 o pipeline de
> "empurrão radial por RPC" já validado no Charge Gun — entrega rápida que
> exercita a fundação. A espada depende da replicação de estado de ataque +
> resolução de parry no servidor (mais novo e mais arriscado). Se quiser
> priorizar a espada por apelo, ela pode vir antes — mas o esforço será maior
> no mesmo faseamento.

---

## 4. Minigame: ESPADAS (Duelo de Espadas)

> **Regra de itens:** exatamente **2 itens** — respeita a média do projeto.
> Ações básicas Punch e Guard continuam; **Dash básico é desativado** para
> dar valor à bota (regra de `docs/items.md`: minigame pode limitar uma ação
> básica, sempre documentado).

### Conceito
Arena de duelo onde cada jogador tem uma **espada letal (1 golpe = morte)** e
uma **bota de dash garantido**. O contra-jogo é o **timing**: espada contra
espada = **parry**, que anula a morte certa e empurra os dois para trás.

### Itens

**1. Espada 1-hit-kill** (uso primário — Clique Esq / X)
- **Wind-up** telegrafado (0,08 s: lâmina erguida + brilho) → **janela ativa**
  (0,12 s, arco ~100°, alcance ~2 m / 60 px 2D) → **recovery** (0,3 s).
- Golpe ativo acerta rival **sem guarda/parry** → **morte instantânea**
  (resolvida no servidor).
- **Decisão de design:** a espada **perfura o Guard** — o parry é a única
  defesa real, mantendo o jogo rápido e o duelo honesto. (Alternativa segura:
  Guard vira "bloqueio que empurra sem matar" — mais defensivo, menos tenso.)

**2. Bota de Dash Garantido** (uso secundário — Shift / L3)
- Dash **sem cooldown** (ou 0,15 s), +50% de distância, i-frames 0,2 s.
- Como a espada é letal, a mobilidade é o contra-jogo: fechar distância,
  fugir de um swing, flanquear.
- Visual: rastro forte + botas emissivas.

### Parry (o coração do modo)
Resolução **no servidor**, por sobreposição de janelas ativas:

| Situação | Resultado |
|---|---|
| Janela ativa de A ∩ janela ativa de B | **PARRY** — ninguém morre; ambos recuam; hit-stop maior; sparks + clank |
| Janela de A ∩ B guardando | Bloqueio: A empurra B, sem morte (se mantiver Guard como bloqueio) |
| Janela de A ∩ B ocioso/movendo | **MORTE** de B |

- **Regra de ângulo (opcional):** parry só conta se A e B estão de frente
  (ângulo entre os `facing` < ~120°) — premia o duelo frente a frente e evita
  parry por acaso.
- **Game feel do parry:** anel de choque, hit-stop 80 ms, clank (SfxBus),
  screen shake — deve ser o momento mais "suculento" do modo.

### Arena
- Plataforma circular com **borda letal** (lava/abismo) — sair = eliminação.
- 2–4 pilares para quebrar linha de visão e permitir flanco.
- Sudden death: plataforma encolhe → força confrontos.

### Rede (o que muda em relação ao padrão)
- `swinging` é **estado replicado** (0,12 s) — todos veem o golpe de todos.
- Morte/parry **só no servidor** (`_resolve_swing` → `_parry.rpc` ou
  `_eliminate_player`). O cliente **nunca** manda "matei".
- Dash: client-autoritativo (como movimento).

---

## 5. Minigame: ÍMÃS (Magnet Showdown)

> **Regra de itens:** exatamente **2 itens**. O ímã e o escudo são as duas
> metades do sistema: **ofensivo/movimento** e **defensivo/anti-ímã**.

### Conceito
Arena sobre lava onde cada jogador carrega um **ímã de dois polos**. Polos
interagem entre jogadores: **opostos se atraem, iguais se repelem**. O ímã
tem dois usos (campo radial e projétil eletromagnético); o escudo anula as
forças magnéticas sobre você e reflete projéteis.

### Itens

**1. Ímã de Dois Polos** (uso primário — Clique Esq / X)
- **Alternar polo** (clique): Norte (azul) ↔ Sul (vermelho). Cooldown 0,3 s.
  **Polo é estado replicado** — todos veem a cor de cada jogador.
- **Campo radial** (segurar = carregar 1→3×): aplica força nos jogadores
  dentro do raio conforme os polos:
  - Polo **oposto** → **atrai** (puxa para você).
  - Polo **igual** → **repele** (empurra para longe).
  - Leve **recuo** no próprio ímã (permite micro-manobras).
- **Projétil eletromagnético** (soltar após carregar): dispara uma carga com
  o **seu polo atual**; ao acertar um rival, puxa/empurra conforme o polo do
  alvo **naquele momento**. Pode ser "plantado" no chão virando zona
  magnética temporária. Cooldown ~1,2 s.
- Energia (barra de carga) limita o uso contínuo.

**2. Escudo Magnético** (uso secundário — Clique Dir / RB)
- Bolha que **imuniza a forças magnéticas** (não é puxado/empurrado por ímãs
  nem projéteis) — **estado replicado** (`shielded`).
- **Reflete** projéteis eletromagnéticos: ao refletir, o projétil **inverte o
  polo** e volta contra o atirador (fica útil contra o dono do ímã).
- **Trade-off:** enquanto ativo, você **não usa o campo radial**. Duração
  1,5 s, cooldown 4 s.
- Visual: bolha emissiva; sparks + inversão de cor ao refletir.

### Ciclo de jogo (didático)
1. Magneto puxa rival (polo oposto) → rival cai na lava.
2. Rival liga o escudo → magneto não puxa mais.
3. Magneto troca de polo (repelir) ou dispara projétil → escudo reflete.
4. Escudo acaba → o jogo de "cabo de guerra magnético" recomeça.

### Arena
- Plataforma central sobre lava + **núcleos metálicos** presos no chão:
  interagem com os ímãs (puxados/empurrados) e servem de obstáculos móveis ou
  de "esmagamento". (Simplificação opcional: núcleos fixos que só mudam de
  visual/comportamento.)

### Rede (o que muda em relação ao padrão)
- **Polo e escudo** replicados (como `guarding`/`facing`) → consistência de
  cor e de imunidade para todos.
- **Força magnética** por RPC broadcast (padrão `_broadcast_charge`): quem
  ativa emite `_apply_magnetic_force.rpc(pos, pole, charge)`; cada peer
  aplica no jogador local (autoridade). O polo do alvo é o **replicado**.
- Projétil eletromagnético: **local** (padrão), efeito por RPC.
- Nota: se um jogador troca de polo no mesmo frame do efeito, pode haver
  dessync de 1 frame — aceitável para party game; documentar.

### Game feel
Linhas de força, anel colorido pelo polo, "hum" elétrico que sobe com a carga
(SfxBus), partículas de atração/rejeição, flash ao refletir, hit-stop pequeno
nos "tracos", shake suave.

---

## 6. Encaixe no código (arquivos)

| Ação | Arquivo |
|---|---|
| Criar sistema de itens (slots/pool) | `scripts/items/` (novo) + `scripts/game/match_settings.gd` |
| Unificar managers | `scripts/game/hellball_manager.gd` + `hellball_manager_2d.gd` → base comum |
| Registrar modos (registry) | `scripts/ui/mode_select.gd`, `scripts/ui/lobby.gd`, `scripts/ui/hud.gd` (hoje `match` hardcoded em `lobby._start_game`) |
| Ímãs: jogador + gerente + arena | `scripts/player/magnet_player*.gd`, `scripts/game/magnet_manager*.gd`, `scenes/levels/magnet_arena.tscn` |
| Espadas: jogador + gerente + arena | `scripts/player/sword_player*.gd`, `scripts/game/sword_manager*.gd`, `scenes/levels/sword_arena.tscn` |
| Projéteis ímã | `scripts/player/electro_projectile*.gd` |
| MatchSettings novos | `item_slots`, `items_pool`, `punch/guard/dash_enabled` (já propostos em `docs/items.md`) |

---

## 7. Medidas de sucesso (checklist dos minigames)

- [ ] Ação → resposta < 100 ms (tela + som + animação) em **ambos**.
- [ ] Parry sempre legível (clank + anel + hit-stop) e **nunca** injusto por
      dessync (estado de swing replicado).
- [ ] Polo do ímã identificável à distância (cor + anel) em todos os peers.
- [ ] 1-hit-kill não vira "frustrante": morte sempre tem wind-up telegrafado e
      sempre havia um parry possível (mesmo que arriscado).
- [ ] Nenhuma tela fica "sem juice" por mais de 2 interações.
