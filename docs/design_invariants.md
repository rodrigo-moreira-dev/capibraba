# Design Invariants — Capibraba

> **Objetivo:** regras de design **não-negociáveis** que devem ser validadas em
> toda mudança de arte, UI, item ou game feel. Um "invariant" é um teste
> reproduzível: ou passa, ou falha. Nada aqui é opinião subjetiva — cada item é
> verificável por inspeção de código/cena.

Estas regras vêm de `AGENTS.md` e de `docs/gamefeel/05_color_palette.md`.
Use-as como **checklist de revisão** (manual ou automatizada via grep/script) e
como critério de aceite ao implementar.

---

## 1. Paleta funcional (cores são linguagem)

Nunca inventar um significado novo de cor sem atualizar
`docs/gamefeel/05_color_palette.md`.

| Significado | Cor | Uso obrigatório |
|---|---|---|
| Dano / Perigo | `#E63A2E` | flash de dano, lava alta, vida perdida |
| Teleporte / Info | `#4DC9FF` | orbe do teleporte, swap, dicas |
| Charge / Poder | `#FF8C1A` | Charge Gun, carga acumulada |
| Defesa | `#3FA9F5` | guard, escudo |
| Sucesso / Cura | `#4CD964` | pickup, vida ganha, abate |
| Aviso | `#FFD23F` | cooldown quase pronto, aviso de evento |
| Neutro | `#B8B8B8` | texto secundário |

**Invariant C1 — Cor de função tem sempre o mesmo significado.**
Um túnel de dano não pode ser azul; um pickup de cura não pode ser vermelho.

**Invariant C2 — Nenhum player usa cor de função pura.**
Cores de jogador (config em `AGENTS.md`): areia `0.72,0.56,0.28`, marrom
`0.40,0.24,0.12`, terracota `0.75,0.30,0.15`, cinza `0.60,0.60,0.60`, laranja
`0.90,0.55,0.08`, roxo `0.50,0.25,0.78`. **Nenhum player usa vermelho/ciano/
verde puros** (`#E63A2E`/`#4DC9FF`/`#4CD964`).

**Invariant C3 — Acessibilidade: significado nunca depende só de cor.**
Toda informação transmitida por cor deve ser **pareada** com forma, ícone ou
texto (daltonismo). Ex.: um pickup de vida = verde + cruz, não só verde.

---

## 2. Contraste e texto

**Invariant C4 — Texto ≥ 4.5:1 com contorno escuro.**
Todo `Label`/`RichTextLabel` com `outline_size` ≥ 6 sobre fundo do tema.

**Invariant C5 — Flash de tela nunca 100% opaco.**
Flash de dano em 40–60% de opacidade + blend ADD (nunca branco sólido 100%).

---

## 3. Game Feel — regras de ouro

Cada ação relevante deve ter **2+ canais de feedback** (visual + sonoro; háptico
via `Input.start_joypad_vibration` quando possível).

**Invariant G1 — Hit-stop 40–80 ms em impactos importantes.**
Hit-stop = pausa curta. Não usar `Engine.time_scale` global com `await` que
reverte cedo (ver CRÍTICA 6 do roadmap). Usar **hit-stop local/por-jogador**.

**Invariant G2 — Screen shake proporcional, nunca contínuo.**
Shake só em impacto; não deixar câmera tremendo o tempo todo.

**Invariant G3 — Squash & stretch em tudo que pula/cai/dispara/é atingido.**
Animação via `create_tween()` com `TRANS_BACK`/`TRANS_ELASTIC`. **Nunca** setar
escala por frame.

**Invariant G4 — Tempos.**
- Impacto < 0,1 s.
- Movimento secundário 0,2–0,4 s.
- Anúncios 2–4 s.

**Invariant G5 — Priorização de feedback.**
Nunca sobrepor 3+ sons/efeitos grandes; o mais importante vence
(morte > tiro > passos).

**Invariant G6 — Implementação do scale.**
- 2D: animar `scale` do *visual* (não o nó de movimento).
- 3D: animar `mesh_pivot.scale` (não a `CharacterBody3D`).
- Transições < 0,25 s.

---

## 4. Itens e ações básicas

**Invariant I1 — Ações básicas nunca somem por causa de item.**
Punch/Guard/Dash permanecem; no máximo **restritos por decisão de design** do
minigame (sempre documentado). Se um minigame tem 3 itens, pode desabilitar uma
ação básica — mas **documentado**.

**Invariant I2 — Não equipar item ⇒ ter as ações básicas.**
Regra geral: personagem sem item tem Punch/Guard/Dash.

**Invariant I3 — Cada item com uso primário e secundário bem definidos.**
E ações básicas nunca são reproduzidas por item (evitar redundância).

---

## 5. Rede / servidor autoritativo

**Invariant N1 — Server-authoritative para estado crítico.**
Vidas, mortes, abates, knockback e troca de posição decididos no servidor.
Nenhum cliente manda "matei".

**Invariant N2 — Validação de remetente em todo RPC.**
`get_remote_sender_id()` em qualquer RPC de efeito novo (morte/parry/força).

**Invariant N3 — Estado de ataque replicado.**
`swinging`, `polo`, `escudo`, `guarding`, `facing` são **replicados** — todos os
peers veem o mesmo estado. Projétil pode ser local, o estado não.

**Invariant N4 — Troca de posição validada pelo servidor.**
Padrão: `request_swap` (cliente) → servidor valida → `_perform_swap.rpc`
(todos) → cliente dono replica a posição final.

---

## 6. Como automatizar (grep/script)

Muitos invariantes são checáveis por busca:

```bash
# C2 — procurar cores puras de função em material de jogador
grep -rn "E63A2E\|4DC9FF\|4CD964" scripts/player/ | grep -iv "damage\|teleport\|heal\|success"

# N2 — RPCs sem validação de remetente (heurística)
grep -rn "@rpc" scripts/ | grep -v "get_remote_sender_id"

# G3 — escala setada por frame (procurar .scale  = fora de tween)
grep -rn "\.scale\s*=" scripts/ | grep -v "create_tween\|TRANS_"
```

> Estes greps são **heurísticas** (sinais), não prova. Use-os para reduzir a
> área de revisão manual.

---

## 7. Checklist de aceite rápido

- [ ] C1 Cor de função com significado consistente.
- [ ] C2 Nenhum player com cor de função pura.
- [ ] C3 Significado nunca só por cor (pareia com forma/ícone/texto).
- [ ] C4 Texto ≥ 4.5:1 + contorno.
- [ ] C5 Flash nunca 100% opaco.
- [ ] G1 Hit-stop 40–80 ms, local/por-jogador.
- [ ] G3 Squash & stretch por tween, nunca scale por frame.
- [ ] G6 Escala animada no visual/mesh_pivot, não no corpo.
- [ ] I1/I2 Ações básicas preservadas (ou restrição documentada).
- [ ] N1–N4 Regras de servidor autoritativo e replicação respeitadas.
