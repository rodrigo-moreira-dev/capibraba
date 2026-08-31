# Usando o Harness para o Capibraba — Subagentes e Workflows

> **Objetivo:** aproveitar a infraestrutura de **subagentes**, **workflow**
> (fan-out) e **goals** do harness para o trabalho pesado do Capibraba —
> especialmente a refatoração da fundação (CRÍTICAS 1–4 do roadmap) e a
> revisão de game feel. Este documento é o guia de uso; as instruções de domínio
> já existem em `.github/agents/`.

---

## 1. Os agentes de domínio do projeto

O projeto já define três agentes especializados (para o seu editor):

| Agente | Arquivo | Responsabilidade |
|---|---|---|
| Game Feel Director | `.github/agents/gamefeel-director.agent.md` | Veredito PASS/FAIL sobre juice/feedback/timing |
| VFX Animator | `.github/agents/vfx-animator.agent.md` | Partículas, squash & stretch, efeitos |
| Audio Designer | `.github/agents/audio-designer.agent.md` | SFX, tones procedurais, prioridade de mix |

Cada um tem instruções prontas (autoridade, constraints, formato de saída).
O harness pode usá-los de duas formas:
1. **Como subagente** — delegando uma tarefa isolada com `subagent`/`subagent_fork`.
2. **Como fase de um workflow** — fan-out para revisar várias partes ao mesmo tempo.

---

## 2. Quando usar subagente vs. workflow vs. goal

| Ferramenta | Use quando | Exemplo no Capibraba |
|---|---|---|
| **subagent** (1 tarefa) | Trabalho isolado e autocontido | "Refatorar `hellball_manager_2d.gd` para herdar da base comum" |
| **subagent_fork** (herda contexto) | Continuação que constrói sobre o que já vimos | "Revisar a lógica de troca de posição que acabamos de escrever" |
| **workflow** (fan-out, muitas partes iguais) | Auditar/revisar N arquivos independentes | "Rodar o gamefeel-director em todos os 6 scripts de jogador Hello" |
| **goal** (objetivo longevo) | Meta que avança entre turnos | "Fase 0 — fundação: itens genéricos + unificação + replicação" |

---

## 3. Guia: fan-out de game feel com `workflow`

Rode o **Game Feel Director** em cada script de jogador, em paralelo, e cole os
vereditos. Padrão de workflow:

```js
// meta: { name: "gamefeel-audit", description: "Audita game feel dos scripts de jogador" }
const files = [
  "scripts/player/hellball_player.gd",
  "scripts/player/hellball_platform_player.gd",
  "scripts/player/hellball_topdown_player.gd",
  "scripts/player/hellball_player_2d_base.gd",
]

const results = await Promise.all(files.map(async (f) => {
  const verdict = await agent(
    `Você é o Game Feel Director do Capibraba (veja .github/agents/gamefeel-director.agent.md). ` +
    `Revise ${f} contra docs/gamefeel/00_overview.md e as regras de ouro. ` +
    `Devolva PASS / PASS WITH CHANGES / FAIL + 1-3 bullets + handoff VFX/Audio/Gameplay.`,
    { label: f }
  )
  return { file: f, verdict }
}))
return results
```

**Resultado esperado:** um tabela de vereditos por arquivo, com exatamente o que
cada especialista faria, sem gastar seu contexto principal.

---

## 4. Guia: fan-out para a fundação (CRÍTICAS 1–4)

As quatro críticas bloqueiam os novos minigames. Cada uma é uma tarefa
autocontida — ideal para subagentes em paralelo:

| CRÍTICA | Tarefa | Subagente/Workflow |
|---|---|---|
| 1 | Sistema de itens genérico (`ItemSlot` + `MatchSettings.item_slots/items_pool`) | subagent: construir `scripts/items/` novo |
| 2 | Unificar managers 3D/2D (base comum) | subagent: extrair base + fazer modos herdarem |
| 3 | Replicar estado de ataque/polo/escudo | subagent: replicar `swinging`/polo/`shielded` |
| 4 | Anti-cheat (morte/parry no servidor) | subagent: mover resolução para o host |

> Dica: rode os 4 **em paralelo** (background) — são independentes em arquivos
> diferentes. Acompanhe com `list_agents`/`send_message`.

---

## 5. Guia: goal longevo (Fase 0)

Crie um goal com `create_goal` para o harness lembrar e avançar a fundação entre
turnos:

```
objetivo: "Fase 0 — fundação: sistema de itens genérico + unificação dos managers + replicação de estado de ataque/polo/escudo (CRITICAS 1-3 do relatorio_roadmap_minigames.md)"
```

Acompanhe com `get_goal`/`update_goal`. Marco o **completo** apenas quando os
três entregáveis da Fase 0 existirem e os testes (docs/netcode/test-plan.md)
passarem.

---

## 6. Convenções ao delegar

- **Dê contexto completo** ao subagente: ele não vê esta conversa. Passe o
  caminho dos arquivos e a spec (não diga "melhore isso").
- **Use `run_in_background: true`** para tarefas independentes; colete com
  `job_output`/`send_message`.
- **Não duplique trabalho:** se um subagente já está refatorando X, não mande
  outro fazer o mesmo.
- **Para revisão de game feel**, o diretor decide *o que* sentir; o VFX e o
  Audio *implementam*. Não deixe o diretor escrever partícula/áudio.
