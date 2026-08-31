pico-8 cartridge // http://www.pico-8.com
version 46
__lua__
-- Hellball Plataforma — Estudo de caso PICO-8 (protótipo jogável)
-- Capibraba: testar se as 3 mecânicas são divertidas.
--
-- Mecânicas (jogador 1 = humano, os demais são bots):
--   Barrigada (Z)      : mini dash p/ frente que ARREMESSA rivais/projéteis p/ longe (parry)
--   Bola de Fogo (X)   : segure p/ carregar, solte p/ disparar (empurra; dano gera leveza)
--   Selo (C)           : dispara selo viajante; re-ative p/ trocar com ele/rival; atinge rival p/ troca
--   (No HTML: A/D mover, W/Espaço pular, S descer plataforma, Z barrida, X bola, C selo)
--
-- Objetivo: empurrar rivais p/ lava. Leveza acumula com dano (quem apanha, mais leve
-- -> mais knockback). Último de pé vence. Foco: interações (bola×bola explode,
-- parry reflete, selo troca) + empurrão/leveza + movimento/escape.

-- ── arena ────────────────────────────────────────────────────────────────
local W, H = 128, 128
local LAVA_Y = 116
local GRAV = 0.24
local MAX_PLAYERS = 4

local players = {}
local projectiles = {}
local seals = {}
local sparks = {}

local COL_BG = 0
local COL_PLAT = 7
local COL_PLAT2 = 5
local COL_LAVA = 9
local COL_LAVA2 = 8
local COL_SEAL = 12
local COL_FIRE = 9
local COL_TXT = 7

local ground_top = LAVA_Y - 28
local platforms = {
    { x = 2,  y = ground_top,      w = 124, h = 28 },
    { x = 20, y = ground_top - 26, w = 30,  h = 6 },
    { x = 78, y = ground_top - 26, w = 30,  h = 6 },
    { x = 50, y = ground_top - 48, w = 28,  h = 6 },
}

local hitstop = 0
local shake = 0
local winner = 0
local round_done = false
local frame = 0

-- ── util ─────────────────────────────────────────────────────────────────
local function rndi(a, b) return a + flr(rnd() * (b - a + 1)) end

local function pc(i)
    local c = { 2, 3, 13, 15 } -- roxo, verde, lavanda, pêssego (nada de função pura)
    return c[((i - 1) % #c) + 1]
end

local function spark(x, y, color, n)
    for i = 1, (n or 6) do
        add(sparks, { x=x, y=y, vx=rndi(-1,1)*1.2, vy=rndi(-16,2)/10, color=color, life=rndi(8,18), c=rnd() })
    end
end

local function impact(st)
    hitstop = max(hitstop, st)
    shake = max(shake, st * 3)
end

-- ── jogador ──────────────────────────────────────────────────────────────
local function new_player(id)
    return {
        id = id,
        x = 12 + (id - 1) * 34,
        y = 60, vx = 0, vy = 0,
        w = 7, h = 9,
        facing = (id % 2 == 0) and -1 or 1,
        on_ground = false,
        belly_cooldown = 0, belly_anim = 0,
        fire_charge = 0, fire_charging = false, fire_cooldown = 0,
        seal_active = nil, seal_cooldown = 0,
        air_jumps = 1,
        lava_hits = 0, knock_flash = 0,
        alive = true, dead_t = 0,
        bot = id ~= 1,
        dir = 1, think = rndi(10, 40),
        color = pc(id),
    }
end

function _init()
    players = {}; projectiles = {}; seals = {}; sparks = {}
    for i = 1, MAX_PLAYERS do add(players, new_player(i)) end
    winner = 0; round_done = false
end

-- ── física ───────────────────────────────────────────────────────────────
local function is_on_platform(p, px, py)
    if p.vy < 0 then return nil end
    for _, pl in ipairs(platforms) do
        if px >= pl.x and px <= pl.x + pl.w and py > pl.y and py <= pl.y + 4 then
            return pl.y
        end
    end
    return nil
end

local function physics(p, move)
    p.vy += GRAV

    if p.bot then
        if p.think <= 0 then
            p.think = rndi(20, 46)
            p.dir = rndi(0, 26) == 0 and 0 or p.dir
            if rndi(0, 24) == 0 then p.dir = -p.dir end
        end
        p.think -= 1
        move = p.dir
        -- bot às vezes usa mecânicas
        if rndi(0, 90) == 0 and p.fire_charge == 0 then p.fire_charging = true end
        if p.fire_charge >= 1 and p.bot then p.fire_projectile = true end
        if rndi(0, 160) == 0 then do_belly(p) end
        if rndi(0, 220) == 0 then do_seal(p) end
    end

    -- barrigada em curso: mantém o impulso do dash (não deixa o clamp cortar)
    if p.belly_anim > 0 then
        p.vx = p.facing * 1.7
    else
        p.vx = max(-1.5, min(1.5, p.vx + move * 0.28))
        if move == 0 then p.vx *= 0.78 end
    end
    if move ~= 0 then p.facing = move > 0 and 1 or -1 end

    p.x += p.vx
    p.x = max(2, min(W - 2 - p.w, p.x))
    p.y += p.vy

    p.on_ground = false
    local gy = is_on_platform(p, p.x + p.w / 2, p.y + p.h)
    if gy then
        p.y = gy - p.h; p.vy = 0; p.on_ground = true; p.air_jumps = 1
    end

    if p.y > LAVA_Y and p.alive then
        p.alive = false; p.dead_t = 60
        impact(0.2)
        spark(p.x + p.w / 2, LAVA_Y, COL_LAVA, 14)
    end
end

-- ── ações ────────────────────────────────────────────────────────────────
function do_belly(p)
    if p.belly_cooldown > 0 or not p.alive then return end
    p.belly_cooldown = 60 -- 2s @30fps
    p.belly_anim = 10
    -- mini dash para frente (mobilidade reduzida pela metade) + leve pop
    p.vx = p.facing * 1.7
    p.vy = min(p.vy, -0.4)
    impact(0.12)
    spark(p.x + p.w / 2, p.y + 6, COL_SEAL, 5)
end

function fire_projectile(p)
    p.fire_charging = false
    p.fire_cooldown = 30 -- 1s @30fps
    local charge = p.fire_charge
    local pow = 0.5 + charge * 2.2
    local force = 3.0 + charge * 4.0
    local dmg = 1 + flr(charge * 2 + 0.5)
    add(projectiles, { x=p.x+p.w/2+p.facing*6, y=p.y+3, vx=p.facing*pow, vy=0,
        owner=p.id, alive=true, life=130, force=force, dmg=dmg })
    impact(0.1)
    spark(p.x + p.w/2 + p.facing*6, p.y+3, COL_FIRE, 4)
    p.fire_charge = 0
end

local function do_fire(p)
    if p.fire_cooldown > 0 then return end
    if p.fire_charging then
        p.fire_charge = min(1, p.fire_charge + 1 / 60) -- carga maxima = 2s
        if p.fire_charge >= 1 and not p.bot then
            fire_projectile(p)
        elseif p.bot and (p.fire_projectile or p.fire_charge >= 1) then
            fire_projectile(p); p.fire_projectile = false
        end
    end
end

function do_seal(p)
    if p.seal_cooldown > 0 or not p.alive then return end
    p.seal_cooldown = 120 -- 4s @30fps
    if p.seal_active and p.seal_active.alive then
        local s = p.seal_active
        -- 2ª ativação: teleporta para o selo (a troca com rival acontece na colisão)
        p.x = s.x - p.w / 2
        p.y = s.y - p.h
        p.vy = 0
        impact(0.16)
        spark(p.x + p.w/2, p.y + p.h/2, COL_SEAL, 10)
        s.alive = false
        p.seal_active = nil
        return
    end
    local s = { x=p.x+p.w/2+p.facing*6, y=p.y+3, vx=p.facing*1.0, vy=0,
        owner=p.id, alive=true, planted=false }
    add(seals, s)
    p.seal_active = s
    spark(s.x, s.y, COL_SEAL, 5)
end

local function swap_players(a, b)
    local ax, ay = a.x, a.y
    a.x, a.y = b.x, b.y
    b.x, b.y = ax, ay
    a.vy = 0; b.vy = 0; a.vx = 0; b.vx = 0
    a.seal_active = nil; b.seal_active = nil
    impact(0.2)
    spark(a.x + a.w/2, a.y + a.h/2, COL_SEAL, 10)
    spark(b.x + b.w/2, b.y + b.h/2, COL_SEAL, 10)
end

-- ── knockback (com leveza) ───────────────────────────────────────────────
local function knockback(target, px, py, force)
    local light = 1 + target.lava_hits * 0.22
    local dx = (target.x + target.w / 2) - px
    local dy = (target.y + target.h / 2) - py
    local len = sqrt(dx*dx + dy*dy) + 0.001
    target.vx += (dx / len) * force * light
    target.vy += (dy / len) * force * light * 0.5
    target.lava_hits += 1
    target.knock_flash = 8
    impact(force * 0.08)
    spark(target.x + target.w/2, target.y + target.h/2, 7, 8)
end

local function explosion(x, y)
    impact(0.25)
    spark(x, y, COL_LAVA2, 18)
    for _, p in ipairs(players) do
        if p.alive and abs((p.x + p.w/2) - x) < 26 then
            knockback(p, x, y, 6.0)
        end
    end
end

-- ── colisões ─────────────────────────────────────────────────────────────
local function resolve_collisions()
    for pi = #projectiles, 1, -1 do
        local pr = projectiles[pi]
        local skip = false
        if not pr.alive then skip = true end
        if not skip then
            pr.x += pr.vx; pr.y += pr.vy; pr.life -= 1
            if pr.life <= 0 then pr.alive = false; skip = true end
        end

        -- bola × bola -> explosão radial
        if not skip then
            for pj = pi - 1, 1, -1 do
                local other = projectiles[pj]
                if other.alive and abs(pr.x - other.x) < 6 and abs(pr.y - other.y) < 6 then
                    explosion(pr.x, pr.y)
                    pr.alive = false; other.alive = false
                    skip = true
                    break
                end
            end
        end

        if not skip and (pr.x < -6 or pr.x > W + 6 or pr.y > LAVA_Y) then
            pr.alive = false; skip = true
        end

        if not skip then
            for _, p in ipairs(players) do
                -- ignora o próprio dono (evita a bola agredir quem a disparou)
                if p.alive and p.id ~= pr.owner and abs(pr.x - (p.x + p.w/2)) < 7 and abs(pr.y - (p.y + p.h/2)) < 9 then
                    knockback(p, pr.x, pr.y, pr.vx >= 0 and pr.force or -pr.force)
                    p.lava_hits += (pr.dmg or 1) - 1
                    pr.alive = false
                    break
                end
            end
        end
    end

    for si = #seals, 1, -1 do
        local s = seals[si]
        if s.alive then
            s.x += s.vx; s.y += s.vy
            if s.vx ~= 0 and (s.x < 2 or s.x > W - 2) then s.planted = true; s.vx = 0 end

            local gy = is_on_platform(s, s.x, s.y + 3)
            if not s.planted and gy then s.planted = true; s.vx = 0; s.y = gy - 3 end

            for _, p in ipairs(players) do
                if p.id ~= s.owner and p.alive and abs(s.x - (p.x + p.w/2)) < 6 and abs(s.y - (p.y + p.h/2)) < 8 then
                    -- ao atingir outro jogador: troca os DOIS de lugar imediatamente
                    for _, owner in ipairs(players) do
                        if owner.id == s.owner and owner.alive then
                            swap_players(owner, p)
                            owner.seal_active = nil
                            break
                        end
                    end
                    s.alive = false
                    break
                end
            end
        end
    end
end

-- barrigada: mini dash que arremessa jogadores e reflete projéteis
local function apply_belly_hits()
    for _, p in ipairs(players) do
        if p.alive and p.belly_anim > 0 then
            local hx = p.x + p.w/2 + p.facing * 8
            local hy = p.y + p.h/2
            for _, o in ipairs(players) do
                if o ~= p and o.alive and abs((o.x + o.w/2) - hx) < 10 and abs((o.y + o.h/2) - hy) < 12 then
                    o.vx = p.facing * 7.0
                    o.vy = -4.5
                    o.lava_hits += 1
                    o.knock_flash = 8
                    impact(0.25)
                    spark(o.x + o.w/2, o.y, 7, 10)
                end
            end
            for _, pr in ipairs(projectiles) do
                if pr.alive and abs(pr.x - hx) < 9 and abs(pr.y - hy) < 9 then
                    pr.vx = -pr.vx * 1.5
                    pr.vy = 0
                    pr.owner = p.id
                    impact(0.25)
                    spark(pr.x, pr.y, COL_SEAL, 10)
                end
            end
        end
    end
end

-- ── vitória ──────────────────────────────────────────────────────────────
local function check_winner()
    local alive = 0
    for _, p in ipairs(players) do if p.alive then alive += 1 end end
    if alive <= 1 and not round_done then
        round_done = true
        for _, p in ipairs(players) do if p.alive then winner = p.id end end
    end
end

-- ── input do humano ──────────────────────────────────────────────────────
local function handle_input()
    local p = players[1]
    if not p.alive then return end
    local move = 0
    if btn(0) then move -= 1 end
    if btn(1) then move += 1 end
    if btnp(4) then do_belly(p) end      -- Z = barrigada
    if btn(2) then p.fire_charging = true end  -- X segura = carrega bola
    if not btn(2) and p.fire_charging then fire_projectile(p) end
    if btnp(5) then do_seal(p) end        -- C = selo
    return move
end

function _update()
    frame += 1
    if hitstop > 0 then
        hitstop -= 0.5
        return
    end

    local move = 0
    -- jogador 1 humano
    if not round_done then
        move = handle_input()
    end
    for _, p in ipairs(players) do
        if p.alive then
            physics(p, (p.id == 1) and move or p.dir)
            if p.fire_cooldown ~= nil then p.fire_cooldown = max(0, p.fire_cooldown - 1) end
            p.belly_cooldown = max(0, p.belly_cooldown - 1)
            p.seal_cooldown = max(0, p.seal_cooldown - 1)
            if p.belly_anim > 0 then p.belly_anim -= 1 end
            if p.knock_flash > 0 then p.knock_flash -= 1 end
            -- bot também chama do_fire (carregar)
            if p.bot then do_fire(p) end
        else
            -- respawn após "morrer" na lava (mantém a rodada viva p/ testar)
            if p.dead_t > 0 then
                p.dead_t -= 1
                if p.dead_t <= 0 then
                    p.alive = true
                    p.x = 12 + (p.id - 1) * 34
                    p.y = 40; p.vy = 0; p.vx = 0
                    p.lava_hits = 0
                    p.fire_charge = 0; p.fire_charging = false
                    p.seal_active = nil
                end
            end
        end
        -- jogador 1 carrega bomba (do_fire precisa rodar dentro da física)
        if p.id == 1 and p.alive then do_fire(p) end
    end

    -- aplica mecânicas de empurrão/parry e colisões
    apply_belly_hits()
    resolve_collisions()
    check_winner()

    -- partículas
    for i = #sparks, 1, -1 do
        local s = sparks[i]
        s.x += s.vx; s.y += s.vy; s.vy += 0.1; s.life -= 1
        if s.life <= 0 then del(sparks, i) end
    end

    if shake > 0 then shake *= 0.86 end
end

-- ── render ───────────────────────────────────────────────────────────────
function _draw()
    local ox = shake > 0.3 and rndi(-1, 1) or 0
    local oy = shake > 0.3 and rndi(-1, 1) or 0
    cls(COL_BG)

    -- lava
    for x = 0, W, 4 do
        rectfill(x, LAVA_Y, x + 3, H, COL_LAVA)
        if ((frame \ 6 + x \ 4) % 2) == 0 then rectfill(x, LAVA_Y, x + 3, LAVA_Y + 2, COL_LAVA2) end
    end

    -- plataformas (visual: contorno + preenchido)
    for _, pl in ipairs(platforms) do
        rectfill(pl.x, pl.y, pl.x + pl.w, pl.y + min(pl.h, 6), COL_PLAT2)
        rectfill(pl.x, pl.y, pl.x + pl.w, pl.y + 2, COL_PLAT)
    end

    -- selos
    for _, s in ipairs(seals) do
        if s.alive then
            circfill(s.x, s.y, 2, COL_SEAL)
            if s.planted then rectfill(s.x - 1, s.y - 1, s.x + 1, s.y + 1, 7) end
        end
    end

    -- bolas de fogo
    for _, pr in ipairs(projectiles) do
        if pr.alive then
            circfill(pr.x, pr.y, 2, COL_FIRE)
            circfill(pr.x, pr.y, 1, 10)
        end
    end

    -- partículas
    for _, s in ipairs(sparks) do
        pset(s.x, s.y, s.color)
    end

    -- players
    for _, p in ipairs(players) do
        draw_player(p, ox, oy)
    end

    -- HUD
    draw_hud()
end

local function draw_player(p, ox, oy)
    local x = p.x + ox
    local y = p.y + oy
    local c = p.knock_flash > 0 and 7 or p.color
    if not p.alive then
        pset(x + 2, y + 2, 6) -- "fantasma" ao cair
        return
    end

    -- corpo
    rectfill(x, y, x + p.w, y + p.h, c)
    rectfill(x, y, x + p.w, y, c)  -- topo
    -- olho (direção)
    rectfill(x + (p.facing > 0 and 5 or 1), y + 2, x + (p.facing > 0 and 6 or 2), y + 3, 7)
    pset(x + (p.facing > 0 and 6 or 2), y + 3, 0)
    -- barriga (flash da barrigada)
    if p.belly_anim > 0 then
        rectfill(x + (p.facing > 0 and p.w + 1 or -2), y + 3, x + (p.facing > 0 and p.w + 3 or -4), y + 5, COL_SEAL)
    end
    -- leveza visual (quem apanhou, "infla" um pouco)
    if p.lava_hits > 0 then
        rectfill(x - 1, y - 1, x + p.w + 1, y, 7)
    end
    -- nome/id
    print(p.id, x - 2, y - 7, 7)
end

local function draw_hud()
    -- título
    print("HELLBALL PLATAFORMA", 2, 2, 7)
    print("Z:barrida  X:bola  C:selo", 2, 11, 6)
    -- vidas ativas
    local alive = 0
    for _, p in ipairs(players) do if p.alive then alive += 1 end end
    if round_done then
        print("VENCEDOR: " .. winner, 40, 60, 10)
        if btnp(4) then _init() end
        print("pressione Z p/ reiniciar", 30, 70, 6)
    end
end

-- fim do cartucho
__gfx__
__map__
__sfx__
