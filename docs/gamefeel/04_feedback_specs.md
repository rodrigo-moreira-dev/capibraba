# Feedback — Specs por Ação

> Especificação técnica de feedback (visual + sonoro + estado) para cada
> ação básica e item. Todo agente implementa estas specs.

## Ações Básicas (desarmado)

### Punch (ataque)
| Canal | Spec |
|---|---|
| Antecipação | recuo 80 ms (squash traseiro) |
| Impacto | hit-stop 40 ms, sparks, slash (linha de arco) |
| Recuperação | follow-through 120 ms |
| Som | whoosh → impacto (thud seco) |
| Gameplay | 20–30 knockback, raio 1.2 m à frente, cooldown 0.4 s |

### Guard (defesa)
| Canal | Spec |
|---|---|
| Visual | bolha/escudo translúcido azul (emissão 2.0) |
| Ao bloquear | sparks azuis + flash pequeno + "clank" |
| Gameplay | reduz knockback recebido em 80%; não pode atacar enquanto guarda; movimento lento |
| Som | clank metálico |

### Dash (movimentação)
| Canal | Spec |
|---|---|
| Visual | stretch direcional + rastro (8–14 partículas) |
| Som | whoosh curto |
| Gameplay | 0.16 s de dash, cooldown 0.65 s, invencível a knockback durante |
| Recuperação | poeira de parada (slow-out 0.12 s) |

## Dano / Ser Empurrado
| Canal | Spec |
|---|---|
| Hit-stop | 50 ms no impacto de projétil |
| Flash | branco no mesh por 80 ms (3D emissão / 2D modulate) |
| Animação | squash direcional (achatamento oposto ao empurrão, 100 ms) |
| Screen shake | 0.15–0.2 s, intensidade ∝ força |
| Som | thud + sting curto |
| VFX | sparks na origem + linha de impacto |
| Estado | `last_attacker_id` atribuído para crédito de abate na lava |

## Lava
| Canal | Spec |
|---|---|
| Visual | burst laranja + fumaça + sparks (rebote) |
| Screen flash | leve vermelho 80 ms |
| Som | sizzle + thud |
| Estado | -1 vida, rebote alto (28 m/s 3D / 18–22 m/s 2D), cooldown 2 s |
| HUD | coração perdido + anúncio se eliminar |

## Itens (Hellball)

### Charge Gun
| Fase | Feedback |
|---|---|
| Carga 0→1 | orbe cresce 0.8→1.8, emissão sobe, shake leve, pitch sobe |
| Disparo | flash cano, recuo, whoosh |
| Explosão | flash → anel → fumaça → sparks + shake 0.2 s + hit-stop 50 ms |
| Som | whine crescente → whoosh → boom |

### Teleport Gun
| Fase | Feedback |
|---|---|
| Disparo | whoosh ciano + rastro |
| Teleporte dono | espiral ciano + flash no destino |
| Troca com rival | anel duplo (ciano+laranja) + flash 120 ms |
| Som | shimmer (teleporte) / portal whoosh (troca) |

## Vitória / Eliminação
- Eliminação: anúncio + fade do personagem (vanish com partículas).
- Vitória: confete na cor do vencedor + anúncio + fanfarra (se houver áudio).

## Tabela de Tempos (referência rápida)
| Feedback | Tempo |
|---|---|
| Hit-stop | 40–80 ms |
| Flash de dano | 80 ms |
| Screen shake | 0.15–0.25 s |
| Anel de choque | 0.25–0.35 s |
| Fumaça | 0.8 s |
| Anúncio de evento | 2–4 s |
| Squash & stretch recover | 0.12–0.18 s |
