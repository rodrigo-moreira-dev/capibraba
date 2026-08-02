# Áudio — Padrões de Design

> Sem assets por enquanto — aqui estão os **padrões de design** e como
> conectá-los no código, para que o agente de áudio (e o diretor) validem e
> prototipem quando houver bancos de sons. Use geradores procedurais
> (`AudioStreamGenerator`) ou placeholders até termos SFX.

## Princípios

1. **Sonificação**: cada ação básica/item tem 1 som "assinatura" + variação.
2. **Camadas**: (a) som de mundo, (b) som de jogador, (c) UI. Volumes
   relativos fixos para nunca sumir sob o mais alto.
3. **Range dinâmico**: impacto alto (boom), utilitário médio (whoosh),
   ambiente baixo (sizzle/lava).
4. **Variação**: `pitch_scale = randf_range(0.9, 1.1)` em todo toque —
   evita "metralhadora" e dá orgânico.
5. **Priorização**: nunca tocar 3+ sons críticos juntos; o mais importante
   vence (ex.: morte > tiro > passos).
6. **Pós-processamento**: use reverb seco para impacto seco, delay curto
   para teleporte (mágico).

## Mapa de Sons (por ação)

| Ação | Som (placeholder/procedural) | Tom/Pitch | Volume |
|---|---|---|---|
| Punch wind-up | whoosh seco curto | 1.0 | médio |
| Punch impacto | thud grave + crack | 0.7–0.9 | alto |
| Guard ativa | brilho suave (chime grave) | 1.2 | baixo |
| Guard block | clank metálico + sparks | 1.0 | médio |
| Dash | whoosh curto | 1.3 | médio |
| Charge (carrega) | whine crescente (pitch 0.8→1.6) | sobe | baixo→médio |
| Charge disparo | whoosh forte + crack | 1.0 | alto |
| Charge explosão | boom + sizzle (lava) + debris | 0.6 | muito alto |
| Teleporte orbe | shimmer (sine com vibrato) | 2.0 | médio |
| Teleporte dono | warp down (pitch 1.5→0.8) | cai | alto |
| Troca (swap) | portal whoosh duplo | 1.0 | alto |
| Dano (empurrado) | thud + sting grave | 0.7 | alto |
| Lava contato | sizzle (ruído branco filtrado) | 1.4 | alto |
| Vida perdida | coração quebrando (thud + glass) | 1.0 | alto |
| Eliminação | fade out + whoosh descendente | cai | alto |
| Abate (kill) | ding agudo (vitória curta) | 1.6 | médio |
| Vitória | fanfarra (3 notas ascendentes) | 1.0 | muito alto |
| UI click | blip | 1.2 | baixo |

## Como Conectar (Godot)

### 3D
- `AudioStreamPlayer3D` nos jogadores/itens com `max_distance` 30,
  `unit_size` por importância (boom 6, whoosh 3).
- Lava ambiente: `AudioStreamPlayer` (não 3D) no manager da arena, loop,
  volume baixo.

### 2D
- `AudioStreamPlayer2D` nos jogadores; `attenuation` 3.0.
- Ambiente: `AudioStreamPlayer` global na arena.

### Gerador procedural (sem assets)
```gdscript
# helper: tonep (pitch fixo) / noisen (ruído)
func _play_tone(stream_player: AudioStreamPlayer, freq: float, dur: float, vol: float, wave := 0) -> void:
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = 22050
    stream_player.stream = gen
    stream_player.volume_db = linear_to_db(vol)
    stream_player.play()
    var playback := stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
    # preenche amostras (senoidal) ...
```
> Para não poluir: centralizar em um autoload `SfxBus` com métodos
> `sfx(name)` e `tone(freq, dur, wave)`. Se um dia houver assets, só
> troca a implementação interna.

## Prioridade do Mix (mais alta primeiro)
1. Eliminação / morte
2. Vitória / abate
3. Explosão do Charge
4. Troca de Teleporte
5. Dano recebido
6. Lava
7. Punch/Guard/Dash
8. Teleporte/Charge utilitário
9. UI

## Checklist
- [ ] Todo toque tem `pitch_scale` com variação aleatória.
- [ ] Nenhuma ação crítica fica muda (silêncio = jogador não entendeu).
- [ ] Ambiente (lava) existe, mas não compete com os toques de jogador.
- [ ] Priorização implementada (não tocar 3+ sons críticos juntos).
