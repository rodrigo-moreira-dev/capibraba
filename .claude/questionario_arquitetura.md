# Questionário para o Documento Final de Arquitetura — Capibraba

**Base:** `docs/CRITICA_REVISOR.md` e `.claude/revisao_arquitetura.md`
**Como responder:** marque a opção escolhida em cada questão. A opção marcada com ✅ é a recomendação da revisão (default). Onde a resposta for livre, escreva uma linha. As respostas fecham as decisões que o documento final vai declarar como ADR.

---

## Bloco A — Escopo e produto

### Q1. Modos 3D (legado: `hellball_arena`, `lava_*`, `player.gd`/`player_extended.gd`)
**Contexto:** o briefing diz "minijogos 2D". Carregar os modos 3D pelo refactor de rede dobra o custo das Fases 2–3. É a maior alavanca de prazo disponível.
- [ ] a) Congelar os modos 3D (ficam fora do refactor de rede) — ✅
- [X] b) Remover os modos 3D do projeto
- [ ] c) Manter os modos 3D no escopo do refactor
**Sua resposta:**

### Q2. Envelope de jogadores por sala
**Contexto:** hoje `MAX_PEERS := 4`. A revisão recomenda fixar 2–8 (esticando 12) e cortar AOI/delta-vs-baseline.
- [x] a) 2–8, esticando 12 — ✅
- [ ] b) 2–4 (estado atual)
- [ ] c) Outro: ______
**Sua resposta:**

### Q3. Plataformas / SKUs
**Contexto:** "Steam mas não exclusivo". Fora da Steam, conectividade grátis = EOS. A revisão propõe transporte por SKU.
- [x] a) Steam-first + SKU off-Steam via EOS — ✅
- [ ] b) Só Steam
- [ ] c) Steam + ENet manual (IP:porta) off-Steam
- [ ] d) Outro: ______
**Sua resposta:**

---

## Bloco B — Modelo de netcode e física

### Q4. Núcleo multi-modelo com perfil por minijogo
**Contexto:** coleção de minijogos tem requisitos de fidelidade diferentes (Espadas ≠ Roubo de Comida). A revisão propõe um núcleo que suporte PREDICTED + INTERPOLATED desde o dia zero, com ROLLBACK opcional para duelos.
- [X] a) Núcleo PREDICTED + INTERPOLATED, ROLLBACK opcional (duelo) — ✅
- [ ] b) Só CSP (predição + reconciliação) para todos
- [ ] c) Outro: ______
**Sua resposta:**

### Q5. Tabela de perfil por minijogo (usar como ponto de partida?)
**Contexto:** a revisão propôs uma tabela inicial (Espadas = CSP+rollback local, Hellball = CSP, Last Standing/King of the Hill = CSP 30 Hz, Corrida = CSP sem lag comp, Roubo de Comida/Capivara Bomb = interpolação + confirmação de evento).
- [X] a) Usar a tabela sugerida como base, validar por playtest — ✅
- [ ] b) Ajustar (indique quais minijogos e o quê): ______
**Sua resposta:**

### Q6. Send rate default
**Contexto:** para ≤8 jogadores em 2D com estado de ~6 bytes, 60 Hz fica trivialmente pagável e corta o interp delay para ~33 ms.
- [X] a) 60 Hz default para ≤8; 30 Hz por perfil quando o minijogo permitir — ✅
- [ ] b) 30 Hz default
- [ ] c) 20 Hz default (como o plano atual)
**Sua resposta:**

### Q7. Buffer de interpolação
**Contexto:** o plano fixa ~100 ms (`cl_interp 0.1`, Source 2001). A revisão recomenda adaptativo por p99 de jitter.
- [X] a) Adaptativo 25–120 ms, dimensionado por p99 de jitter em janela deslizante — ✅
- [ ] b) Fixo em ~100 ms
- [ ] c) Outro: ______
**Sua resposta:**

### Q8. Física dos personagens 2D
**Contexto:** re-simulação com `CharacterBody2D` + `move_and_slide()` exige rebobinar o mundo inteiro; rollback com física exige Rapier/build custom. A revisão recomenda cinemática própria em ponto fixo com colisão AABB/círculo à mão.
- [X] a) Cinemática própria em ponto fixo (colisão à mão) — ✅
- [ ] b) Manter `CharacterBody2D` + `move_and_slide()`
- [ ] c) SGPhysics2D (ponto fixo, para rollback)
**Sua resposta:**

### Q9. Resolução de contato em melee (punch/espadas)
**Contexto:** alternativa ao rewind completo: cliente reporta acerto, host valida plausibilidade contra histórico curto.
- [X] a) Favor-the-attacker com validação de plausibilidade no host — ✅
- [ ] b) Lag compensation por rewind de histórico no host
- [ ] c) Híbrido (validação para melee, rewind para projéteis)
**Sua resposta:**

---

## Bloco C — Identidade, transporte e conectividade

### Q10. Identidade estável de jogador
**Contexto:** `peer_id` não sobrevive à migração/rejoin. A revisão exige `player_id` estável (SteamID64 / EOS PUID / UUID) como chave primária de placar, autoridade, telemetria e rejoin.
- [X] a) Adotar `player_id` estável; `peer_id` vira detalhe de transporte — ✅
- [ ] b) Manter indexação por `peer_id` por enquanto
**Sua resposta:**

### Q11. Transporte por SKU atrás de fachada
**Contexto:** Steam SDR resolve NAT, esconde IP do host e pode reduzir RTT; EOS cobre off-Steam; ENet fica para LAN/dev. Exige fachada `MultiplayerPeer` (hoje `network_manager.gd` instancia ENet inline).
- [X] a) Fachada + Steam SDR / EOS / ENet-LAN — ✅
- [ ] b) ENet direto em todos os SKUs
- [ ] c) Outro: ______
**Sua resposta:**

### Q12. Export headless como artefato de build
**Contexto:** bots headless são o export que o plano "descartou". A revisão recomenda manter o export headless desde a Fase 1 (CI, teste de carga, fuga futura), sem prometer hospedagem oficial.
- [X] a) Manter export headless desde a Fase 1 — ✅
- [ ] b) Não manter (só build de cliente)
**Sua resposta:**

---

## Bloco D — Continuidade de sala (migração de host)

### Q13. Modelo de migração de host
**Contexto:** migrar a simulação contínua é caro e frágil (relógio, tick, predição, RPCs em vôo). Para rodadas de 60–180 s, a revisão recomenda migrar a **sala** (aborta a rodada, preserva placar, reabre sala, repete a rodada).
- [X] a) Migração de sessão (aborta rodada, preserva placar) — ✅
- [ ] b) Migração de simulação contínua
- [ ] c) Sessão agora; simulação contínua como pós-lançamento
**Sua resposta:**

### Q14. Critério de eleição do novo host
**Contexto:** menor `peer_id` ignora NAT/upload do eleito. A revisão recomenda eleger por qualidade de rede medida, com candidatos pré-validados (capazes de hospedar).
- [X] a) Qualidade de rede medida + capacidade de hospedar pré-validada — ✅
- [ ] b) Menor `peer_id` sobrevivente
- [ ] c) Outro: ______
**Sua resposta:**

### Q15. Política da rodada abortada
**Contexto:** na migração de sessão, a rodada corrente é perdida.
- [ ] a) Repetir a rodada abortada — ✅
- [ ] b) Pular para a próxima rodada do ciclo
- [X] c) Votação entre os sobreviventes
**Sua resposta:**

---

## Bloco E — Justiça, segurança e anti-cheat

### Q16. Combate host-autoritativo (Etapa A) primeiro
**Contexto:** hoje o cliente envia `force`/`pos` arbitrários (`_broadcast_punch_2d`). A revisão recomenda mover só o combate para o host antes de mexer em movimento.
- [X] a) Sim — fechar o buraco do `force` primeiro (Etapa A) — ✅
- [ ] b) Não — fazer tudo junto (movimento + combate)
**Sua resposta:**

### Q17. Nivelamento de vantagem do host
**Contexto:** sem correção, o host joga com latência zero. A revisão recomenda atrasar o input local do host em ~mediana da latência dos convidados (1–4 frames).
- [X] a) Adotar delay de input no host — ✅
- [ ] b) Não nivelar (assumir vantagem do host)
**Sua resposta:**

### Q18. Anti-cheat de cliente (EAC e similares)
**Contexto:** validação no host cobre convidados; EAC só se justifica com incentivo econômico real.
- [X] a) Adiar; decidir pós-lançamento competitivo — ✅
- [ ] b) Incluir já na Fase 4
- [ ] c) Nunca
**Sua resposta:**

### Q19. Privacidade de IP do host
**Contexto:** com ENet cru, todo convidado aprende o IP residencial do host (vetor de DDoS/assédio). SDR/EOS resolvem por construção.
- [X] a) Obrigatório: nunca expor IP do host a convidados — ✅
- [ ] b) Nice-to-have
**Sua resposta:**

---

## Bloco F — Operação, produto e qualidade

### Q20. Splitscreen / múltiplos jogadores locais
**Contexto:** requisito implícito de party game e pré-requisito de Remote Play Together. Muda o input global (`Input.is_action_*`) para input por dispositivo/slot.
- [X] a) Sim, decidir na Fase 0 e suportar por slot — ✅
- [ ] b) Não por enquanto
**Sua resposta:**

### Q21. Steam Remote Play Together + Steam Deck como requisitos
**Contexto:** canal de distribuição sério para party game; Deck vive em Wi-Fi (jitter alto), reforçando buffer adaptativo.
- [X] a) Sim — requisitos de primeira fase (gamepad em tudo, UI legível, multi local) — ✅
- [ ] b) Steam Deck sim, RPT depois
- [ ] c) Não agora
**Sua resposta:**

### Q22. Rejoin / reconexão em partida
**Contexto:** exige assento reservado por `player_id` + re-sync na entrada.
- [X] a) Sim — rejoin por `player_id` — ✅
- [ ] b) Depois do lançamento
**Sua resposta:**

### Q23. Moderação de sala (anti-grief)
**Contexto:** em sala de jogador, o host é a moderação: kick, ban por `player_id`, senha, detecção de idle, filtro de região.
- [X] a) Sim — incluir no plano (Fase 4) — ✅
- [ ] b) Depois do lançamento
**Sua resposta:**

### Q24. Achievements/stats da Steam
**Contexto:** conceder só em confirmação autoritativa (nunca em predição).
- [ ] a) Só em confirmação autoritativa — ✅
- [X] b) Sem restrição
**Sua resposta:**

---

## Bloco G — Correções factuais e de engenharia

### Q25. Versão do engine
**Contexto:** o plano fala em Godot 4.6; o projeto declara 4.7.
- [X] a) Godot 4.7 — ✅
- [ ] b) Godot 4.6
**Sua resposta:**

### Q26. Higiene de números
**Contexto:** a conta de banda está ~22–55× fora do próprio orçamento; várias constantes vêm de blogs de vendor. A revisão recomenda recalcular bottom-up e mover citações para "hipóteses a medir".
- [X] a) Recalcular bottom-up + seção "hipóteses a medir na Fase 1" — ✅
- [ ] b) Manter os números atuais
**Sua resposta:**

### Q27. Bug de colisão do jogador de plataforma
**Contexto:** `hellball_platform_player.tscn` declara `CapsuleShape2D` com `radius=0.4`, `height=1.5` (metros) num espaço em pixels, com velocidades de 190–430 px/s.
- [X] a) Corrigir antes do trabalho de netcode — ✅
- [ ] b) Investigar depois
**Sua resposta:**

---

## Bloco H — Roadmap e priorização

### Q28. Roadmap em 5 fases
**Contexto:** a revisão propõe Fase 0 (decisões/fundações) → F1 (fundação de rede) → F2 (combate host) → F3 (predição por minijogo) → F4 (conectividade/produção) → F5 (opcional), total 12–18 semanas para 2D.
- [X] a) Adotar o roadmap de 5 fases — ✅
- [ ] b) Ajustar fases/escopo (indique): ______
**Sua resposta:**

### Q29. Restrições de prazo e equipe
**Contexto:** o documento final precisa declarar time-box e capacidade para as fases.
**Sua resposta (livre):** equipe (nº pessoas/áreas), prazo-alvo e qualquer restrição externa (ex.: data de lançamento, limite de budget):

### Q30. Pendências fora da lista
**Contexto:** alguma decisão que a revisão não cobriu e que você quer ver fixada no documento final?
**Sua resposta (livre):** 
