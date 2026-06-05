-- =============================================================================
-- SOPRO - FRAMEWORK AUDIO-COGNITIVO REATIVO v5
-- Melhorias: símbolos desenhados (sem emoji), partículas + som ao coletar,
-- ritmo mais lento e musical, trilha relaxante procedural, Aura funcional
-- =============================================================================

local ESTADO_ATUAL = "intro"

-- -----------------------------------------------------------------------------
-- SOPRO
-- -----------------------------------------------------------------------------
local Sopro = {
    x = 100, y = 300,
    vy = 0,
    raio = 18,
    velocidade_horizontal = 240,
    forca_flutuacao = -270,
    vel_glide = 50,
    no_chao = false,
    pulsa_raio = 18,
    perto_de_nota = false,
    tem_aura_ressonancia = false,
    tem_eco_miller       = false,
    cor_atual = {1, 1, 1},
    invulneravel = 0,
}

-- -----------------------------------------------------------------------------
-- VARIÁVEIS GLOBAIS
-- -----------------------------------------------------------------------------
local CameraX         = 0
local RuidoMental     = 15
local LimiteRuido     = 100
local GravidadeBasal  = 600
local FaseAtual       = 1

local NotasDoAmbiente     = {}
local NotasColetadas      = 0
local TempoImovel         = 0
local TempoRequeridoPausa = 11.0

-- Partículas de coleta
local Particulas = {}

-- Solo de Alma + Ritmo
local SequenciaMemoria   = {}
local SequenciaJogador   = {}
local NotaExibidaAtual   = 1
local TemporizadorSeq    = 0
local EstadoSolo         = "exibindo"

local Ritmo = {
    ativo       = false,
    pos         = 0,
    velocidade  = 1.6,       -- MAIS LENTO: 1.6s para descer (antes 0.55s)
    janela_perfeita = 0.10,  -- janelas mais generosas
    janela_boa      = 0.22,
    indice_nota = 1,
    feedback        = "",
    feedback_timer  = 0,
    feedback_cor    = {1,1,1},
    aguardando_input = false,
    combo = 0,               -- combo de acertos seguidos
    melhor_combo = 0,
}

local IconesDistracao = {}
local ZonasSilencio = {}

local Nevoa = {
    densidade     = 0.0,
    particulas    = {},
    timer_notif   = 0,
}

local LinhasEcoMiller = {}

local FlashErro       = { ativo = false, timer = 0, duracao = 0.4 }
local FlashAcerto     = { ativo = false, timer = 0, duracao = 0.3, cor = {0.3,1,0.5} }
local MsgZonaSilencio = { ativo = false, timer = 0, duracao = 2.0 }

-- Trilha relaxante procedural (para o Solo)
local TrilhaSolo = {
    ativa       = false,
    fonte       = nil,
    timer_acorde = 0,
    timer_arp   = 0,
    indice_arp  = 1,
}

local EcoMundoReal = {
    "Hoje, escolha uma tarefa e dê a ela 5 minutos inteiros, sem celular.",
    "Experimente ouvir uma música até o fim, sem pular.",
    "Antes de dormir, respire fundo 3 vezes e observe o silêncio.",
    "Tente ler uma página de livro sem parar. O foco é um músculo.",
}
local MensagemVitoria = ""

local Sons = {}

local ConfigFases = {
    { cor = {0.25, 0.45, 0.70}, onda = 160, qtd_notas = 2, tam_seq = 3, qtd_distracao = 4, vel_distracao = 35 },
    { cor = {0.70, 0.40, 0.30}, onda = 110, qtd_notas = 3, tam_seq = 4, qtd_distracao = 6, vel_distracao = 55 },
    { cor = {0.40, 0.20, 0.65}, onda = 80,  qtd_notas = 4, tam_seq = 5, qtd_distracao = 8, vel_distracao = 75 },
}

-- =============================================================================
-- ÁUDIO PROCEDURAL
-- =============================================================================
local function GerarNota(freq, dur, tipo)
    local taxa  = 44100
    local total = math.floor(taxa * dur)
    local dados = love.sound.newSoundData(total, taxa, 16, 1)
    for i = 0, total - 1 do
        local t = i / taxa
        local onda = 0
        if tipo == "seno" then
            onda = math.sin(2*math.pi*freq*t) * 0.7
                 + math.sin(4*math.pi*freq*t) * 0.2
                 + math.sin(6*math.pi*freq*t) * 0.1
        elseif tipo == "ruido" then
            onda = (love.math.random()*2 - 1) * math.sin(2*math.pi*8*t)
        elseif tipo == "sino" then
            onda = math.sin(2*math.pi*freq*t) * math.cos(math.pi*freq*0.5*t)
        elseif tipo == "piano" then
            -- Timbre suave de piano elétrico
            onda = math.sin(2*math.pi*freq*t) * 0.6
                 + math.sin(2*math.pi*freq*2*t) * 0.25
                 + math.sin(2*math.pi*freq*3*t) * 0.1
        end
        local decay = math.exp(-3.0*t)
        dados:setSample(i, onda * decay * 0.28)
    end
    return love.audio.newSource(dados)
end

local function GerarZumbido(freq, dur)
    local taxa  = 44100
    local total = math.floor(taxa * dur)
    local dados = love.sound.newSoundData(total, taxa, 16, 1)
    for i = 0, total - 1 do
        local t = i / taxa
        local onda = math.sin(2*math.pi*freq*t) * 0.5
                   + math.sin(2*math.pi*freq*1.5*t) * 0.3
        local env = math.min(t/0.05, 1.0) * math.exp(-1.5*t)
        dados:setSample(i, onda * env * 0.18)
    end
    return love.audio.newSource(dados)
end

-- Loop ambiente relaxante: pad de cordas + arpejo suave em Dó maior
local function GerarTrilhaRelaxante()
    local taxa = 44100
    local dur  = 8.0       -- 8 segundos em loop
    local total = math.floor(taxa * dur)
    local dados = love.sound.newSoundData(total, taxa, 16, 1)

    -- Acordes: Cmaj7 (0-2s), Fmaj7 (2-4s), Am7 (4-6s), Gmaj7 (6-8s)
    local acordes = {
        {261.63, 329.63, 392.00, 493.88},  -- C E G B
        {174.61, 261.63, 349.23, 440.00},  -- F C A C
        {220.00, 261.63, 329.63, 392.00},  -- A C E G
        {196.00, 246.94, 293.66, 392.00},  -- G B D G
    }

    for i = 0, total - 1 do
        local t = i / taxa
        local idx = math.floor(t / 2) + 1
        if idx > 4 then idx = 4 end
        local ac = acordes[idx]

        -- Pad suave (soma dos tons do acorde, baixo volume)
        local pad = 0
        for _, f in ipairs(ac) do
            pad = pad + math.sin(2*math.pi*f*t) * 0.08
        end

        -- Envelope global suave (fade in/out por seção)
        local local_t = t % 2
        local env = math.min(local_t / 0.3, 1.0) * math.min((2 - local_t) / 0.3, 1.0)
        env = math.max(0, env)

        -- Sub-bass suave (oitava abaixo do tom raiz)
        local sub = math.sin(2*math.pi*(ac[1]/2)*t) * 0.05

        dados:setSample(i, (pad * env + sub) * 0.5)
    end

    local src = love.audio.newSource(dados)
    src:setLooping(true)
    src:setVolume(0.6)
    return src
end

-- Som positivo de "chime" para coleta de nota (acorde maior)
local function GerarChimePositivo()
    local taxa = 44100
    local dur  = 0.9
    local total = math.floor(taxa * dur)
    local dados = love.sound.newSoundData(total, taxa, 16, 1)
    -- Acorde maior arpejado rapidamente: C-E-G-C agudo
    local freqs = {523.25, 659.25, 783.99, 1046.50}
    for i = 0, total - 1 do
        local t = i / taxa
        local onda = 0
        for k, f in ipairs(freqs) do
            local atraso = (k-1) * 0.06
            if t > atraso then
                local lt = t - atraso
                local env = math.exp(-2.5 * lt)
                onda = onda + (math.sin(2*math.pi*f*lt) * 0.5 + math.sin(2*math.pi*f*2*lt)*0.15) * env
            end
        end
        dados:setSample(i, onda * 0.18)
    end
    return love.audio.newSource(dados)
end

-- =============================================================================
-- TERRENO
-- =============================================================================
local function ObterYTerreno(x)
    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    return 460
        + math.sin(x / conf.onda) * 35
        + math.sin(x / (conf.onda * 2)) * 25
end

-- =============================================================================
-- PARTÍCULAS (coleta de nota)
-- =============================================================================
local function CriarExplosaoParticulas(x, y, cor, qtd)
    cor = cor or {1, 0.9, 0.3}
    qtd = qtd or 24
    for i = 1, qtd do
        local ang = love.math.random() * math.pi * 2
        local vel = 80 + love.math.random() * 140
        table.insert(Particulas, {
            x = x, y = y,
            vx = math.cos(ang) * vel,
            vy = math.sin(ang) * vel,
            vida = 0,
            duracao = 0.7 + love.math.random() * 0.5,
            raio = 2 + love.math.random() * 3,
            cor = {cor[1], cor[2], cor[3]},
            gravidade = 120,
        })
    end
    -- Anel expansivo
    for i = 1, 12 do
        local ang = (i / 12) * math.pi * 2
        table.insert(Particulas, {
            x = x, y = y,
            vx = math.cos(ang) * 200,
            vy = math.sin(ang) * 200,
            vida = 0,
            duracao = 0.5,
            raio = 4,
            cor = {1, 1, 0.8},
            gravidade = 0,
        })
    end
end

local function AtualizarParticulas(dt)
    for i = #Particulas, 1, -1 do
        local p = Particulas[i]
        p.vida = p.vida + dt
        if p.vida >= p.duracao then
            table.remove(Particulas, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + p.gravidade * dt
            p.vx = p.vx * 0.96
        end
    end
end

local function DesenharParticulas()
    for _, p in ipairs(Particulas) do
        local a = 1 - (p.vida / p.duracao)
        love.graphics.setColor(p.cor[1], p.cor[2], p.cor[3], a)
        love.graphics.circle("fill", p.x, p.y, p.raio * a)
    end
end

-- =============================================================================
-- NÉVOA
-- =============================================================================
local function CriarParticulaNevoa()
    return {
        x = love.math.random(0, 800),
        y = love.math.random(50, 400),
        vx = love.math.random()*40 - 20,
        vy = love.math.random()*20 - 10,
        raio = love.math.random(15, 50),
        alpha = love.math.random() * 0.3,
        tem_simbolo = love.math.random() > 0.6,
    }
end

local function InicializarNevoa()
    Nevoa.particulas = {}
    for i = 1, 40 do
        table.insert(Nevoa.particulas, CriarParticulaNevoa())
    end
end

local function AtualizarNevoa(dt)
    Nevoa.densidade = RuidoMental / LimiteRuido
    for _, p in ipairs(Nevoa.particulas) do
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.x < -p.raio then p.x = 820 end
        if p.x > 820     then p.x = -p.raio end
        if p.y < 20      then p.vy = math.abs(p.vy) end
        if p.y > 430     then p.vy = -math.abs(p.vy) end
        p.alpha = Nevoa.densidade * (0.15 + math.sin(love.timer.getTime()*3 + p.x)*0.07)
    end
end

-- =============================================================================
-- ZONAS DE SILÊNCIO
-- =============================================================================
local function GerarZonasSilencio()
    ZonasSilencio = {}
    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    table.insert(ZonasSilencio, {
        x = 280, y = ObterYTerreno(280) - 90,
        raio = 95, dentro = false,
    })
    for i = 1, conf.qtd_notas do
        local px = 550 * i + 200
        table.insert(ZonasSilencio, {
            x = px, y = ObterYTerreno(px) - 90,
            raio = 95, dentro = false,
        })
    end
end

local function ChecarZonaSilencio(dt)
    for _, z in ipairs(ZonasSilencio) do
        local dx = Sopro.x - z.x
        local dy = Sopro.y - z.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local estava = z.dentro
        z.dentro = dist < z.raio
        if z.dentro and not estava then
            if Sons["silencio"] then Sons["silencio"]:play() end
            MsgZonaSilencio.ativo = true
            MsgZonaSilencio.timer = 0
        end
        if z.dentro then
            RuidoMental = math.max(0, RuidoMental - 18 * dt)
            Sopro.invulneravel = math.max(Sopro.invulneravel, 0.3)
        end
    end
end

-- =============================================================================
-- DISTRAÇÕES — agora MAIS LENTAS e Aura interage com elas
-- =============================================================================
local function GerarIconesDistracao()
    IconesDistracao = {}
    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    for i = 1, conf.qtd_distracao do
        local px = love.math.random(300, 550 * conf.qtd_notas)
        local py = love.math.random(80, 350)
        local simbolos = {"!", "?", "@", "#", "*", "+"}
        table.insert(IconesDistracao, {
            x = px, y = py,
            vx = 0, vy = 0,
            raio = 20,
            simbolo = simbolos[love.math.random(#simbolos)],
            velocidade = conf.vel_distracao,
            cooldown = 0,
            ativo = true,
            timer_aleatorio = love.math.random() * 6.28,
            empurrado = false,    -- se a Aura empurrou
        })
    end
end

local function AtualizarIconesDistracao(dt)
    for _, ic in ipairs(IconesDistracao) do
        if ic.cooldown > 0 then
            ic.cooldown = ic.cooldown - dt
            if ic.cooldown <= 0 then
                ic.ativo = true
                ic.empurrado = false
            end
        end

        if ic.ativo then
            ic.timer_aleatorio = ic.timer_aleatorio + dt

            local sopro_protegido = false
            for _, z in ipairs(ZonasSilencio) do
                if z.dentro then sopro_protegido = true; break end
            end

            -- AURA DE RESSONÂNCIA: cria um campo de exclusão que empurra distrações
            local dx_aura = ic.x - Sopro.x
            local dy_aura = ic.y - Sopro.y
            local dist_aura = math.sqrt(dx_aura*dx_aura + dy_aura*dy_aura) + 0.001
            local raio_aura = 130

            if Sopro.tem_aura_ressonancia and dist_aura < raio_aura then
                -- Repele com força proporcional à proximidade
                local forca = (1 - dist_aura/raio_aura) * 250
                ic.vx = (dx_aura/dist_aura) * forca
                ic.vy = (dy_aura/dist_aura) * forca
            elseif sopro_protegido then
                local d = dist_aura
                ic.vx = (dx_aura/d) * ic.velocidade * 0.7
                ic.vy = (dy_aura/d) * ic.velocidade * 0.7
            else
                -- Persegue normalmente (mais lento agora)
                local dx = Sopro.x - ic.x
                local dy = Sopro.y - ic.y
                local d  = math.sqrt(dx*dx + dy*dy) + 0.001
                local osc_x = math.cos(ic.timer_aleatorio * 1.5) * 15
                local osc_y = math.sin(ic.timer_aleatorio * 2.0) * 12
                ic.vx = (dx/d) * ic.velocidade + osc_x
                ic.vy = (dy/d) * ic.velocidade + osc_y
            end

            ic.x = ic.x + ic.vx * dt
            ic.y = ic.y + ic.vy * dt

            if ic.y < 40 then ic.y = 40 end
            if ic.y > 420 then ic.y = 420 end

            -- Colisão (a Aura previne dano direto também)
            if Sopro.invulneravel <= 0 and not sopro_protegido and not Sopro.tem_aura_ressonancia then
                local dx = Sopro.x - ic.x
                local dy = Sopro.y - ic.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < (Sopro.raio + ic.raio) then
                    RuidoMental = math.min(LimiteRuido, RuidoMental + 14)
                    Nevoa.densidade = math.min(1, Nevoa.densidade + 0.15)
                    if Sons["dissonancia"] then Sons["dissonancia"]:play() end
                    FlashErro.ativo = true
                    FlashErro.timer = 0
                    Sopro.invulneravel = 1.2
                    ic.cooldown = 2.0
                    ic.ativo = false
                    ic.vx = -ic.vx * 3
                    ic.vy = -ic.vy * 3
                end
            end
        else
            ic.x = ic.x + ic.vx * dt * 0.3
            ic.y = ic.y + ic.vy * dt * 0.3
        end
    end
end

-- =============================================================================
-- COR DO SOPRO
-- =============================================================================
local function AtualizarCorSopro()
    local t = RuidoMental / LimiteRuido
    Sopro.cor_atual = {
        1.0 - t * 0.4,
        1.0 - t * 0.7,
        1.0 - t * 0.5,
    }
end

-- =============================================================================
-- INICIALIZAR FASE
-- =============================================================================
local function InicializarFase(fase)
    FaseAtual = fase
    if FaseAtual > #ConfigFases then
        MensagemVitoria = EcoMundoReal[love.math.random(#EcoMundoReal)]
        ESTADO_ATUAL = "vitoria"
        if TrilhaSolo.fonte then TrilhaSolo.fonte:stop() end
        TrilhaSolo.ativa = false
        return
    end

    local conf = ConfigFases[FaseAtual]
    NotasDoAmbiente = {}
    NotasColetadas  = 0
    RuidoMental     = 15
    Sopro.x         = 100
    Sopro.y         = 300
    Sopro.vy        = 0
    Sopro.invulneravel = 0
    Sopro.tem_aura_ressonancia = false
    Sopro.tem_eco_miller       = false
    LinhasEcoMiller = {}
    FlashErro.ativo = false
    Particulas = {}

    for i = 1, conf.qtd_notas do
        local px = 550 * i
        local py = ObterYTerreno(px) - 120
        table.insert(NotasDoAmbiente, {
            x = px, y = py,
            progresso = 0,
            absorvida = false,
        })
    end

    GerarZonasSilencio()
    GerarIconesDistracao()
    InicializarNevoa()
    ESTADO_ATUAL = "exploracao"

    if TrilhaSolo.fonte then TrilhaSolo.fonte:stop() end
    TrilhaSolo.ativa = false
end

-- =============================================================================
-- LINHAS DO ECO DE MILLER
-- =============================================================================
local function GerarLinhasEcoMiller()
    LinhasEcoMiller = {}
    local notas_vis = {}
    for _, n in ipairs(NotasDoAmbiente) do
        if not n.absorvida then table.insert(notas_vis, n) end
    end
    for i = 1, #notas_vis - 1 do
        table.insert(LinhasEcoMiller, {
            x1 = notas_vis[i].x,   y1 = notas_vis[i].y,
            x2 = notas_vis[i+1].x, y2 = notas_vis[i+1].y,
            alpha = 0,
        })
    end
end

-- =============================================================================
-- SOLO DE ALMA: começa a tocar a trilha relaxante
-- =============================================================================
local function IniciarTrilhaSolo()
    if not TrilhaSolo.fonte then
        TrilhaSolo.fonte = GerarTrilhaRelaxante()
    end
    TrilhaSolo.fonte:setVolume(0.6)
    TrilhaSolo.fonte:play()
    TrilhaSolo.ativa = true
end

local function PararTrilhaSolo()
    if TrilhaSolo.fonte then TrilhaSolo.fonte:stop() end
    TrilhaSolo.ativa = false
end

local function IniciarNotaRitmo(idx)
    Ritmo.ativo = true
    Ritmo.pos = -0.4    -- começa acima do trilho (pausa visual)
    Ritmo.indice_nota = idx
    Ritmo.aguardando_input = true
    -- Toca a nota como referência só na primeira vez
    local n = SequenciaMemoria[idx]
    if n and Sons[n] then Sons[n]:play() end
end

local function ResolverInputRitmo(tecla_correta)
    local dist = math.abs(Ritmo.pos - 1.0)
    local resultado, recompensa

    if not tecla_correta then
        resultado = "TECLA ERRADA!"
        recompensa = -1
    elseif dist <= Ritmo.janela_perfeita then
        resultado = "PERFEITO!"
        recompensa = 2
    elseif dist <= Ritmo.janela_boa then
        resultado = "BOM!"
        recompensa = 1
    else
        resultado = "FORA DO RITMO!"
        recompensa = -1
    end

    Ritmo.feedback = resultado
    Ritmo.feedback_timer = 0
    Ritmo.aguardando_input = false

    if recompensa > 0 then
        Ritmo.feedback_cor = recompensa == 2 and {0.3,1,0.5} or {1,0.9,0.3}
        Ritmo.combo = Ritmo.combo + 1
        if Ritmo.combo > Ritmo.melhor_combo then Ritmo.melhor_combo = Ritmo.combo end

        if Sons["chime"] then Sons["chime"]:play() end
        -- Toca a nota com timbre de piano (mais musical)
        local nm = SequenciaMemoria[Ritmo.indice_nota]
        if nm and Sons[nm .. "_piano"] then Sons[nm .. "_piano"]:play() end

        FlashAcerto.ativo = true
        FlashAcerto.timer = 0
        FlashAcerto.cor = recompensa == 2 and {0.3,1,0.5} or {1,0.9,0.3}

        -- Partículas no alvo
        CriarExplosaoParticulas(400, 420, Ritmo.feedback_cor, 18)

        table.insert(SequenciaJogador, SequenciaMemoria[Ritmo.indice_nota])

        if #SequenciaJogador >= #SequenciaMemoria then
            Ritmo.ativo = false
            PararTrilhaSolo()
            if not Sopro.tem_eco_miller then
                Sopro.tem_eco_miller = true
                if Sons["poder"] then Sons["poder"]:play() end
            end
            -- Pausa pequena de comemoração antes de avançar
            EstadoSolo = "vitoria_fase"
            TemporizadorSeq = 0
            CriarExplosaoParticulas(400, 300, {1, 0.95, 0.4}, 40)
        else
            Ritmo.pos = -0.4
            Ritmo.indice_nota = Ritmo.indice_nota + 1
            Ritmo.aguardando_input = true
            local n = SequenciaMemoria[Ritmo.indice_nota]
            if n and Sons[n] then Sons[n]:play() end
        end
    else
        Ritmo.feedback_cor = {1, 0.3, 0.3}
        Ritmo.combo = 0
        if Sons["dissonancia"] then Sons["dissonancia"]:play() end
        RuidoMental     = math.min(LimiteRuido, RuidoMental + 12)
        Nevoa.densidade = math.min(1, Nevoa.densidade + 0.15)
        FlashErro.ativo = true
        FlashErro.timer = 0
        Ritmo.pos = -0.4
        Ritmo.aguardando_input = true
    end
end

-- =============================================================================
-- LOVE.LOAD
-- =============================================================================
function love.load()
    love.window.setTitle("Sopro — Ressonância v5")
    love.window.setMode(800, 600, { resizable = false })
    love.graphics.setNewFont(16)

    Sons["grave"]       = GerarNota(261.63, 0.85, "seno")
    Sons["medio"]       = GerarNota(329.63, 0.85, "seno")
    Sons["agudo"]       = GerarNota(392.00, 0.85, "seno")
    Sons["grave_piano"] = GerarNota(261.63, 1.2, "piano")
    Sons["medio_piano"] = GerarNota(329.63, 1.2, "piano")
    Sons["agudo_piano"] = GerarNota(392.00, 1.2, "piano")
    Sons["sucesso"]     = GerarNota(523.25, 0.50, "sino")
    Sons["dissonancia"] = GerarNota(130.00, 0.45, "ruido")
    Sons["silencio"]    = GerarZumbido(220, 1.2)
    Sons["poder"]       = GerarNota(659.25, 0.60, "sino")
    Sons["notif1"]      = GerarNota(880, 0.15, "sino")
    Sons["notif2"]      = GerarNota(1046, 0.12, "sino")
    Sons["chime"]       = GerarChimePositivo()
    Sons["coleta"]      = GerarChimePositivo()

    InicializarFase(1)
    ESTADO_ATUAL = "intro"
end

-- =============================================================================
-- LOVE.UPDATE
-- =============================================================================
function love.update(dt)
    Sopro.pulsa_raio = Sopro.raio + math.sin(love.timer.getTime()*5)*1.5

    AtualizarParticulas(dt)

    if ESTADO_ATUAL == "intro" or ESTADO_ATUAL == "vitoria" or ESTADO_ATUAL == "game_over" then
        return
    end

    AtualizarCorSopro()

    if Sopro.invulneravel > 0 then
        Sopro.invulneravel = Sopro.invulneravel - dt
    end

    if FlashErro.ativo then
        FlashErro.timer = FlashErro.timer + dt
        if FlashErro.timer >= FlashErro.duracao then FlashErro.ativo = false end
    end
    if FlashAcerto.ativo then
        FlashAcerto.timer = FlashAcerto.timer + dt
        if FlashAcerto.timer >= FlashAcerto.duracao then FlashAcerto.ativo = false end
    end

    if MsgZonaSilencio.ativo then
        MsgZonaSilencio.timer = MsgZonaSilencio.timer + dt
        if MsgZonaSilencio.timer >= MsgZonaSilencio.duracao then MsgZonaSilencio.ativo = false end
    end

    AtualizarNevoa(dt)

    if Nevoa.densidade > 0.4 then
        Nevoa.timer_notif = Nevoa.timer_notif + dt
        local intervalo = 2.5 - Nevoa.densidade * 1.5
        if Nevoa.timer_notif >= intervalo then
            Nevoa.timer_notif = 0
            if not Sopro.tem_aura_ressonancia then
                local s = love.math.random() > 0.5 and Sons["notif1"] or Sons["notif2"]
                if s then s:play() end
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- EXPLORAÇÃO
    -- -------------------------------------------------------------------------
    if ESTADO_ATUAL == "exploracao" then
        RuidoMental = RuidoMental + (3.0 * dt)

        if RuidoMental >= LimiteRuido then
            if Sons["dissonancia"] then Sons["dissonancia"]:play() end
            ESTADO_ATUAL = "game_over"
            return
        end

        if love.keyboard.isDown("right") then
            Sopro.x = Sopro.x + Sopro.velocidade_horizontal * dt
        end
        if love.keyboard.isDown("left") then
            Sopro.x = Sopro.x - Sopro.velocidade_horizontal * dt
        end
        if Sopro.x < 0 then Sopro.x = 0 end

        if love.keyboard.isDown("up") then
            Sopro.vy = Sopro.forca_flutuacao
        else
            Sopro.vy = Sopro.vy + GravidadeBasal * dt
            if Sopro.vy > Sopro.vel_glide then Sopro.vy = Sopro.vel_glide end
        end
        Sopro.y = Sopro.y + Sopro.vy * dt

        local chaoY = ObterYTerreno(Sopro.x) - Sopro.raio
        if Sopro.y >= chaoY then
            Sopro.y = chaoY; Sopro.vy = 0; Sopro.no_chao = true
        else
            Sopro.no_chao = false
        end

        CameraX = Sopro.x - 400

        ChecarZonaSilencio(dt)
        AtualizarIconesDistracao(dt)

        if Sopro.tem_eco_miller then
            for _, ln in ipairs(LinhasEcoMiller) do
                ln.alpha = 0.5 + math.sin(love.timer.getTime()*4)*0.3
            end
        end

        local zona_ativa = false
        for _, nota in ipairs(NotasDoAmbiente) do
            if not nota.absorvida then
                local dx = math.abs(Sopro.x - nota.x)
                local dy = math.abs(Sopro.y - nota.y)
                if dx < 55 and dy < 65 then
                    zona_ativa = true
                    if love.keyboard.isDown("space") then
                        nota.progresso = nota.progresso + (45 * dt)
                        if math.floor(love.timer.getTime()*6) % 2 == 0 then
                            if Sons["medio"] then Sons["medio"]:play() end
                        end
                        if nota.progresso >= 100 then
                            nota.absorvida = true
                            NotasColetadas = NotasColetadas + 1
                            RuidoMental = math.max(0, RuidoMental - 30)
                            -- SOM POSITIVO + PARTÍCULAS
                            if Sons["coleta"] then Sons["coleta"]:play() end
                            CriarExplosaoParticulas(nota.x, nota.y, {1, 0.95, 0.4}, 30)
                            CriarExplosaoParticulas(Sopro.x, Sopro.y, {0.6, 1, 0.8}, 12)

                            if NotasColetadas == 1 and FaseAtual == 1 then
                                ESTADO_ATUAL = "pausa_sincopada"
                                TempoImovel = 0
                            elseif NotasColetadas >= #NotasDoAmbiente then
                                ESTADO_ATUAL = "solo_de_alma"
                                SequenciaMemoria = {}
                                SequenciaJogador = {}
                                local opcoes = {"grave", "medio", "agudo"}
                                local conf = ConfigFases[FaseAtual]
                                for i = 1, conf.tam_seq do
                                    table.insert(SequenciaMemoria, opcoes[love.math.random(1,3)])
                                end
                                EstadoSolo = "preparando"
                                TemporizadorSeq = 0
                                NotaExibidaAtual = 1
                                Ritmo.ativo = false
                                Ritmo.combo = 0
                                if Sopro.tem_eco_miller then GerarLinhasEcoMiller() end
                                IniciarTrilhaSolo()
                            end
                        end
                    else
                        nota.progresso = math.max(0, nota.progresso - (75*dt))
                    end
                end
            end
        end
        Sopro.perto_de_nota = zona_ativa

        if not zona_ativa and love.keyboard.isDown("space") then
            RuidoMental = RuidoMental + (18 * dt)
        end

    -- -------------------------------------------------------------------------
    -- PAUSA SINCOPADA
    -- -------------------------------------------------------------------------
    elseif ESTADO_ATUAL == "pausa_sincopada" then
        if love.keyboard.isDown("left", "right", "up", "space", "down") then
            TempoImovel = 0
            RuidoMental = RuidoMental + (10*dt)
            Nevoa.densidade = math.min(1, Nevoa.densidade + 0.05*dt)
            if math.floor(love.timer.getTime()*6) % 3 == 0 then
                if Sons["dissonancia"] then Sons["dissonancia"]:play() end
            end
        else
            TempoImovel = TempoImovel + dt
            RuidoMental = math.max(0, RuidoMental - (2*dt))
            if TempoImovel >= TempoRequeridoPausa then
                RuidoMental = 0
                Sopro.tem_aura_ressonancia = true
                if Sons["poder"] then Sons["poder"]:play() end
                if Sons["sucesso"] then Sons["sucesso"]:play() end
                CriarExplosaoParticulas(Sopro.x - CameraX, Sopro.y, {0.3, 1, 0.5}, 50)
                ESTADO_ATUAL = "exploracao"
            end
        end

    -- -------------------------------------------------------------------------
    -- SOLO DE ALMA
    -- -------------------------------------------------------------------------
    elseif ESTADO_ATUAL == "solo_de_alma" then
        if EstadoSolo == "preparando" then
            TemporizadorSeq = TemporizadorSeq + dt
            if TemporizadorSeq >= 3.0 then
                EstadoSolo = "exibindo"
                TemporizadorSeq = 0
                NotaExibidaAtual = 1
            end
        elseif EstadoSolo == "exibindo" then
            TemporizadorSeq = TemporizadorSeq + dt
            if TemporizadorSeq >= 0.85 then    -- mais devagar pra memorizar
                TemporizadorSeq = 0
                local nota = SequenciaMemoria[NotaExibidaAtual]
                if nota and Sons[nota .. "_piano"] then Sons[nota .. "_piano"]:play() end
                NotaExibidaAtual = NotaExibidaAtual + 1
                if NotaExibidaAtual > #SequenciaMemoria then
                    EstadoSolo = "pausa_pre_jogo"
                    TemporizadorSeq = 0
                end
            end
        elseif EstadoSolo == "pausa_pre_jogo" then
            TemporizadorSeq = TemporizadorSeq + dt
            if TemporizadorSeq >= 1.0 then
                EstadoSolo = "jogando"
                SequenciaJogador = {}
                IniciarNotaRitmo(1)
            end
        elseif EstadoSolo == "jogando" then
            if Ritmo.ativo then
                Ritmo.pos = Ritmo.pos + (dt / Ritmo.velocidade)
                if Ritmo.pos > 1.0 + Ritmo.janela_boa and Ritmo.aguardando_input then
                    ResolverInputRitmo(false)
                end
            end
            if Ritmo.feedback ~= "" then
                Ritmo.feedback_timer = Ritmo.feedback_timer + dt
                if Ritmo.feedback_timer > 0.8 then Ritmo.feedback = "" end
            end
        elseif EstadoSolo == "vitoria_fase" then
            TemporizadorSeq = TemporizadorSeq + dt
            if TemporizadorSeq >= 1.8 then
                InicializarFase(FaseAtual + 1)
            end
        end
    end
end

-- =============================================================================
-- LOVE.KEYPRESSED
-- =============================================================================
function love.keypressed(key)
    if ESTADO_ATUAL == "intro" then
        if key == "return" or key == "space" then
            if Sons["dissonancia"] then Sons["dissonancia"]:play() end
            love.timer.sleep(0.2)
            if Sons["grave"] then Sons["grave"]:play() end
            InicializarFase(1)
        end
        return
    end

    if ESTADO_ATUAL == "game_over" and key == "r" then
        Sopro.tem_aura_ressonancia = false
        Sopro.tem_eco_miller       = false
        Ritmo.melhor_combo = 0
        InicializarFase(1)
        return
    end

    if ESTADO_ATUAL == "vitoria" and key == "return" then
        Sopro.tem_aura_ressonancia = false
        Sopro.tem_eco_miller       = false
        Ritmo.melhor_combo = 0
        InicializarFase(1)
        ESTADO_ATUAL = "intro"
        return
    end

    if ESTADO_ATUAL == "solo_de_alma" and EstadoSolo == "jogando" and Ritmo.aguardando_input then
        local nota_pressionada = nil
        if key == "left"  then nota_pressionada = "grave" end
        if key == "up"    then nota_pressionada = "medio" end
        if key == "right" then nota_pressionada = "agudo" end

        if nota_pressionada then
            local esperada = SequenciaMemoria[Ritmo.indice_nota]
            ResolverInputRitmo(nota_pressionada == esperada)
        end
    end
end

-- =============================================================================
-- DESENHO DE SETAS (substitui emojis)
-- =============================================================================
local function DesenharSeta(x, y, direcao, tamanho, cor)
    -- direcao: "esq", "cima", "dir"
    love.graphics.setColor(cor[1], cor[2], cor[3], cor[4] or 1)
    local s = tamanho
    if direcao == "esq" then
        love.graphics.polygon("fill",
            x - s,        y,
            x + s*0.3,    y - s*0.7,
            x + s*0.3,    y - s*0.25,
            x + s,        y - s*0.25,
            x + s,        y + s*0.25,
            x + s*0.3,    y + s*0.25,
            x + s*0.3,    y + s*0.7
        )
    elseif direcao == "dir" then
        love.graphics.polygon("fill",
            x + s,        y,
            x - s*0.3,    y - s*0.7,
            x - s*0.3,    y - s*0.25,
            x - s,        y - s*0.25,
            x - s,        y + s*0.25,
            x - s*0.3,    y + s*0.25,
            x - s*0.3,    y + s*0.7
        )
    elseif direcao == "cima" then
        love.graphics.polygon("fill",
            x,            y - s,
            x - s*0.7,    y + s*0.3,
            x - s*0.25,   y + s*0.3,
            x - s*0.25,   y + s,
            x + s*0.25,   y + s,
            x + s*0.25,   y + s*0.3,
            x + s*0.7,    y + s*0.3
        )
    end
end

-- Símbolo genérico de "notificação" (círculo com !)
local function DesenharSimboloDistracao(x, y, raio, alpha)
    -- Círculo vermelho
    love.graphics.setColor(1, 0.3, 0.2, 0.9 * alpha)
    love.graphics.circle("fill", x, y, raio * 0.55)
    love.graphics.setColor(1, 1, 1, 0.95 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, raio * 0.55)
    -- Exclamação branca dentro
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", x - 1.5, y - 6, 3, 8, 1, 1)
    love.graphics.circle("fill", x, y + 4, 1.8)
    love.graphics.setLineWidth(1)
end

-- =============================================================================
-- DESENHO — HUD
-- =============================================================================
local function DesenharBarraRuido()
    local t = RuidoMental / LimiteRuido
    local largura = 180
    love.graphics.setColor(0.1,0.1,0.1, 0.5)
    love.graphics.rectangle("fill", 10, 10, largura, 14, 4, 4)
    local r = 0.2 + t*0.7
    local g = 0.8 - t*0.7
    local b = 0.3 - t*0.2
    love.graphics.setColor(r,g,b, 0.85)
    love.graphics.rectangle("fill", 10, 10, largura*t, 14, 4, 4)
    love.graphics.setColor(1,1,1, 0.3)
    love.graphics.rectangle("line", 10, 10, largura, 14, 4, 4)
    love.graphics.setColor(1,1,1, 0.7)
    love.graphics.print("Ruido Mental", 10, 28)
end

local function DesenharPoderes()
    local yp = 55
    if Sopro.tem_aura_ressonancia then
        local a = 0.7 + math.sin(love.timer.getTime()*4)*0.2
        love.graphics.setColor(0.4,1.0,0.6, a)
        -- Ícone circular pulsante
        love.graphics.circle("fill", 18, yp + 8, 6)
        love.graphics.setColor(1,1,1, a)
        love.graphics.print("Aura Ativa - Repele distracoes", 32, yp)
        yp = yp + 22
    end
    if Sopro.tem_eco_miller then
        local a = 0.7 + math.sin(love.timer.getTime()*3 + 1)*0.2
        love.graphics.setColor(0.6,0.8,1.0, a)
        love.graphics.circle("fill", 18, yp + 8, 6)
        love.graphics.setColor(1,1,1, a)
        love.graphics.print("Eco de Miller - Memoria visual", 32, yp)
    end
end

local function DesenharNevoa()
    if Nevoa.densidade < 0.05 then return end
    local raio_exclusao = Sopro.tem_aura_ressonancia and 140 or 0
    for _, p in ipairs(Nevoa.particulas) do
        if raio_exclusao > 0 then
            local sx = Sopro.x - CameraX
            local sy = Sopro.y
            local d  = math.sqrt((p.x-sx)^2 + (p.y-sy)^2)
            if d < raio_exclusao then goto continua end
        end
        local r = 0.7 + Nevoa.densidade*0.3
        local g = 0.2
        local b = 0.3 + Nevoa.densidade*0.2
        love.graphics.setColor(r,g,b, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.raio)
        if p.tem_simbolo and Nevoa.densidade > 0.3 then
            DesenharSimboloDistracao(p.x, p.y, 10, p.alpha * 1.8)
        end
        ::continua::
    end
end

local function DesenharTerreno(iniX, fimX)
    love.graphics.setColor(0.12, 0.15, 0.20, 0.92)
    local passo = 10
    for px = iniX, fimX, passo do
        love.graphics.polygon("fill",
            px,         ObterYTerreno(px),
            px+passo,   ObterYTerreno(px+passo),
            px+passo,   600,
            px,         600
        )
    end
    love.graphics.setColor(0.3,0.45,0.60, 0.5)
    love.graphics.setLineWidth(1.5)
    for px = iniX, fimX-passo, passo do
        love.graphics.line(px, ObterYTerreno(px), px+passo, ObterYTerreno(px+passo))
    end
    love.graphics.setLineWidth(1)
end

local function DesenharNotas()
    for _, nota in ipairs(NotasDoAmbiente) do
        if not nota.absorvida then
            local pulso = math.sin(love.timer.getTime()*3)*4
            love.graphics.setColor(1, 0.9, 0.3, 0.15)
            love.graphics.circle("fill", nota.x, nota.y, 32+pulso)
            love.graphics.setColor(1, 0.85, 0.2, 0.35)
            love.graphics.circle("fill", nota.x, nota.y, 20+pulso*0.5)
            love.graphics.setColor(1, 0.95, 0.4, 1)
            love.graphics.circle("fill", nota.x, nota.y, 9)
            for i = 1, 4 do
                local ang = love.timer.getTime()*1.5 + i*math.pi/2
                local dist = 24+pulso
                love.graphics.setColor(1,1,0.6, 0.5)
                love.graphics.circle("fill", nota.x+math.cos(ang)*dist, nota.y+math.sin(ang)*dist, 2.5)
            end
            if nota.progresso > 0 then
                love.graphics.setColor(1,1,1, 0.8)
                love.graphics.setLineWidth(3)
                love.graphics.arc("line", "open", nota.x, nota.y, 20,
                    -math.pi/2, -math.pi/2 + (nota.progresso/100)*math.pi*2)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

local function DesenharIconesDistracao()
    for _, ic in ipairs(IconesDistracao) do
        local alpha = ic.ativo and 1.0 or 0.4
        local pulso = math.sin(love.timer.getTime()*4 + ic.x)*3
        if ic.ativo then
            local vmag = math.sqrt(ic.vx^2 + ic.vy^2) + 0.001
            local ux = -ic.vx / vmag
            local uy = -ic.vy / vmag
            for i = 1, 4 do
                love.graphics.setColor(0.9, 0.2, 0.2, (0.12 - i*0.025)*alpha)
                love.graphics.circle("fill", ic.x + ux*i*8, ic.y + uy*i*8, ic.raio*0.8)
            end
        end
        love.graphics.setColor(0.9,0.2,0.2, (0.25 + math.abs(math.sin(love.timer.getTime()*3))*0.15)*alpha)
        love.graphics.circle("fill", ic.x, ic.y, ic.raio+pulso)
        -- Símbolo desenhado (não emoji)
        DesenharSimboloDistracao(ic.x, ic.y, ic.raio, alpha)
    end
end

local function DesenharZonasSilencio()
    for _, z in ipairs(ZonasSilencio) do
        local puls = math.sin(love.timer.getTime()*2)*6
        love.graphics.setColor(0.3, 0.9, 0.8, z.dentro and 0.30 or 0.15)
        love.graphics.circle("fill", z.x, z.y, z.raio + puls)
        love.graphics.setColor(0.4, 1.0, 0.9, z.dentro and 0.7 or 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", z.x, z.y, z.raio)
        love.graphics.setColor(0.4, 1.0, 0.9, z.dentro and 0.4 or 0.2)
        love.graphics.circle("line", z.x, z.y, z.raio*0.7 + puls*0.5)
        love.graphics.circle("line", z.x, z.y, z.raio*0.4 + puls*0.3)
        love.graphics.setLineWidth(1)
        -- Símbolo central: folha estilizada (3 pétalas)
        love.graphics.setColor(0.6, 1, 0.7, 0.85)
        for i = 0, 2 do
            local ang = (i / 3) * math.pi * 2 - math.pi/2
            love.graphics.circle("fill", z.x + math.cos(ang)*8, z.y + math.sin(ang)*8, 5)
        end
        love.graphics.setColor(0.2, 0.5, 0.3, 0.9)
        love.graphics.circle("fill", z.x, z.y, 4)
    end
end

local function DesenharLinhasEcoMiller()
    if not Sopro.tem_eco_miller then return end
    for _, ln in ipairs(LinhasEcoMiller) do
        local a = ln.alpha or 0.6
        love.graphics.setColor(0.5, 0.85, 1.0, a)
        love.graphics.setLineWidth(2)
        love.graphics.line(ln.x1, ln.y1, ln.x2, ln.y2)
        love.graphics.setColor(1,1,1, a)
        love.graphics.circle("fill", ln.x1, ln.y1, 5)
        love.graphics.circle("fill", ln.x2, ln.y2, 5)
    end
    love.graphics.setLineWidth(1)
end

local function DesenharSopro(pX, pY)
    local c = Sopro.cor_atual

    -- AURA DE RESSONÂNCIA — agora claramente visível e funcional
    if Sopro.tem_aura_ressonancia then
        local t = love.timer.getTime()
        -- 3 anéis pulsantes em frequências diferentes
        for i = 1, 3 do
            local ph = (t * 1.5 + i * 0.7) % 1.5
            local raio = 30 + ph * 100
            local a = (1 - ph/1.5) * 0.4
            love.graphics.setColor(0.3, 1.0, 0.5, a)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", pX, pY, raio)
        end
        -- Halo interno constante
        love.graphics.setColor(0.3, 1.0, 0.5, 0.18)
        love.graphics.circle("fill", pX, pY, 60)
        love.graphics.setColor(0.3, 1.0, 0.5, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", pX, pY, 130) -- mostra o raio de repulsão
        love.graphics.setLineWidth(1)
    end

    if Sopro.invulneravel > 0 then
        if math.floor(love.timer.getTime()*15) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.3)
        else
            love.graphics.setColor(c[1], c[2], c[3], 0.95)
        end
    else
        love.graphics.setColor(c[1], c[2], c[3], 0.95)
    end

    if ESTADO_ATUAL == "exploracao" and Sopro.invulneravel <= 0 then
        love.graphics.setLineWidth(2)
        if Sopro.perto_de_nota then
            local ag = 0.55 + math.sin(love.timer.getTime()*10)*0.22
            love.graphics.setColor(0.15,1,0.35, ag)
            love.graphics.circle("line", pX, pY,
                Sopro.raio+18 + math.sin(love.timer.getTime()*8)*2)
        else
            love.graphics.setColor(1,1,1, 0.12)
            love.graphics.circle("line", pX, pY, Sopro.raio+14)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(c[1], c[2], c[3], 0.95)
    end

    love.graphics.circle("fill", pX, pY, Sopro.pulsa_raio)
    love.graphics.polygon("fill",
        pX-Sopro.raio, pY,
        pX+Sopro.raio, pY,
        pX,            pY+24
    )

    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    love.graphics.setColor(conf.cor[1]*0.25, conf.cor[2]*0.25, conf.cor[3]*0.25, 1)
    love.graphics.circle("fill", pX-5.5, pY-3, 3)
    love.graphics.circle("fill", pX+5.5, pY-3, 3)
    love.graphics.setColor(1,1,1, 0.6)
    love.graphics.circle("fill", pX-4.5, pY-4, 1.2)
    love.graphics.circle("fill", pX+6.5, pY-4, 1.2)
end

-- =============================================================================
-- DESENHO DO RITMO (com setas desenhadas)
-- =============================================================================
local function DesenharRitmo()
    if not Ritmo.ativo and EstadoSolo ~= "vitoria_fase" then return end
    if not Ritmo.ativo then return end

    local nota = SequenciaMemoria[Ritmo.indice_nota]
    local direcao, tecla_nome, tecla_cor
    if nota == "grave" then
        direcao = "esq";  tecla_nome = "ESQUERDA"; tecla_cor = {1, 0.55, 0.3}
    elseif nota == "medio" then
        direcao = "cima"; tecla_nome = "CIMA";     tecla_cor = {0.4, 1, 0.5}
    else
        direcao = "dir";  tecla_nome = "DIREITA";  tecla_cor = {0.5, 0.7, 1}
    end

    local centro_x = 400
    local topo_y   = 180
    local alvo_y   = 430
    local trilho_h = alvo_y - topo_y

    -- Pentagrama estilizado (3 linhas horizontais)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.setLineWidth(1)
    for i = 0, 4 do
        local y = topo_y + (i/4) * trilho_h
        love.graphics.line(centro_x - 200, y, centro_x + 200, y)
    end

    -- Trilho vertical com brilho
    love.graphics.setColor(0.25, 0.30, 0.45, 0.8)
    love.graphics.setLineWidth(6)
    love.graphics.line(centro_x, topo_y, centro_x, alvo_y)
    love.graphics.setColor(0.5, 0.7, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(centro_x, topo_y, centro_x, alvo_y)
    love.graphics.setLineWidth(1)

    -- ALVO: três anéis (perfeito / bom / fora)
    local pulse = 1 + math.sin(love.timer.getTime()*4)*0.08
    love.graphics.setColor(1, 0.85, 0.3, 0.20)
    love.graphics.circle("fill", centro_x, alvo_y, 55*pulse)
    love.graphics.setColor(0.3, 1, 0.5, 0.45)
    love.graphics.circle("fill", centro_x, alvo_y, 32*pulse)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", centro_x, alvo_y, 55)
    love.graphics.setColor(0.3, 1, 0.6, 1)
    love.graphics.circle("line", centro_x, alvo_y, 32)
    love.graphics.setLineWidth(1)

    -- SETA grande dentro do alvo
    DesenharSeta(centro_x, alvo_y, direcao, 22, {tecla_cor[1], tecla_cor[2], tecla_cor[3], 1})

    -- Nome da tecla embaixo
    love.graphics.setNewFont(13)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(tecla_nome, centro_x - 80, alvo_y + 70, 160, "center")
    love.graphics.setNewFont(16)

    -- CÍRCULO DESCENDENTE com rastro
    if Ritmo.pos >= 0 then
        local y_circulo = topo_y + Ritmo.pos * trilho_h
        for i = 1, 8 do
            local ya = y_circulo - i*7
            if ya > topo_y - 30 then
                love.graphics.setColor(tecla_cor[1], tecla_cor[2], tecla_cor[3], math.max(0, 0.55 - i*0.07))
                love.graphics.circle("fill", centro_x, ya, math.max(2, 20 - i*1.8))
            end
        end
        -- Brilho externo
        love.graphics.setColor(tecla_cor[1], tecla_cor[2], tecla_cor[3], 0.4)
        love.graphics.circle("fill", centro_x, y_circulo, 30)
        -- Núcleo
        love.graphics.setColor(tecla_cor[1], tecla_cor[2], tecla_cor[3], 1)
        love.graphics.circle("fill", centro_x, y_circulo, 20)
        love.graphics.setColor(1,1,1, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", centro_x, y_circulo, 20)
        -- Setinha pequena dentro do círculo descendente
        DesenharSeta(centro_x, y_circulo, direcao, 10, {1,1,1, 0.95})
        love.graphics.setLineWidth(1)
    else
        -- "Próxima nota em..."
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Prepare-se...", 0, topo_y - 30, 800, "center")
    end

    -- FEEDBACK textual
    if Ritmo.feedback ~= "" then
        love.graphics.setNewFont(32)
        local a = math.max(0, 1 - Ritmo.feedback_timer/0.8)
        local escala = 1 + (1 - a) * 0.4
        love.graphics.setColor(Ritmo.feedback_cor[1], Ritmo.feedback_cor[2], Ritmo.feedback_cor[3], a)
        love.graphics.printf(Ritmo.feedback, 0, alvo_y - 130, 800, "center")
        love.graphics.setNewFont(16)
    end

    -- COMBO
    if Ritmo.combo >= 2 then
        love.graphics.setNewFont(20)
        love.graphics.setColor(1, 0.8, 0.3, 0.9)
        love.graphics.printf("Combo x" .. Ritmo.combo, 0, 105, 800, "center")
        love.graphics.setNewFont(16)
    end

    -- Bolinhas de progresso
    local total = #SequenciaMemoria
    local feitos = #SequenciaJogador
    local bw = 18
    local gap = 8
    local lx = (800 - (total*(bw+gap) - gap)) / 2
    for i = 1, total do
        if i <= feitos then
            love.graphics.setColor(0.3, 1, 0.5, 0.9)
            love.graphics.circle("fill", lx + (i-1)*(bw+gap) + bw/2, 145, bw/2)
            love.graphics.setColor(1,1,1, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", lx + (i-1)*(bw+gap) + bw/2, 145, bw/2)
        elseif i == Ritmo.indice_nota then
            local p = 0.7 + math.sin(love.timer.getTime()*6) * 0.3
            love.graphics.setColor(1, 0.9, 0.3, p)
            love.graphics.circle("fill", lx + (i-1)*(bw+gap) + bw/2, 145, bw/2)
        else
            love.graphics.setColor(0.4, 0.4, 0.5, 0.6)
            love.graphics.circle("fill", lx + (i-1)*(bw+gap) + bw/2, 145, bw/2)
        end
    end
    love.graphics.setLineWidth(1)
end

-- =============================================================================
-- LOVE.DRAW
-- =============================================================================
function love.draw()
    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    local fatorR = RuidoMental / LimiteRuido

    local r = conf.cor[1] * (1.0 - fatorR*0.80)
    local g = conf.cor[2] * (1.0 - fatorR*0.80)
    local b = conf.cor[3] * (1.0 - fatorR*0.80)
    love.graphics.setBackgroundColor(r, g, b)

    if ESTADO_ATUAL == "intro" then
        love.graphics.setColor(1,1,1, 0.3)
        for i = 1, 60 do
            local sx = (i*137.5) % 800
            local sy = (i*97.3 + love.timer.getTime()*5) % 580
            love.graphics.circle("fill", sx, sy, 1)
        end
        love.graphics.setColor(1,1,1, 1)
        love.graphics.setNewFont(52)
        love.graphics.printf("S O P R O", 0, 110, 800, "center")
        love.graphics.setNewFont(18)
        love.graphics.setColor(0.8, 0.95, 1, 0.85)
        love.graphics.printf("Resgate sua alma do ruido digital.", 0, 185, 800, "center")
        love.graphics.setNewFont(14)
        love.graphics.setColor(1,1,1, 0.7)
        love.graphics.printf(
            "Setas Esq/Dir: mover     Seta Cima: flutuar\n" ..
            "Perto de uma nota dourada, segure ESPACO para absorve-la.\n" ..
            "Fuja das distracoes vermelhas! Zonas verdes restauram o foco.\n" ..
            "No Solo de Alma, aperte a tecla quando o circulo bater no alvo.",
            60, 245, 680, "center")
        love.graphics.setColor(0.9, 1, 0.7, 0.85)
        love.graphics.printf("Recompensas: Aura (repele distracoes) e Eco de Miller (memoria visual)",
            40, 340, 720, "center")
        local pa = 0.5 + math.sin(love.timer.getTime()*2.5)*0.4
        love.graphics.setColor(1,1,1, pa)
        love.graphics.printf("[ ENTER ou ESPACO para comecar ]", 0, 480, 800, "center")
        love.graphics.setNewFont(16)
        return

    elseif ESTADO_ATUAL == "game_over" then
        love.graphics.setColor(0.5, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setNewFont(36)
        love.graphics.setColor(0.95, 0.2, 0.2, 1)
        love.graphics.printf("MENTE SOBRECARREGADA", 0, 220, 800, "center")
        love.graphics.setNewFont(16)
        love.graphics.setColor(1,1,1, 0.75)
        love.graphics.printf("A nevoa tomou conta.\nRespire fundo e tente novamente.\n\n[R] para recomecar",
            0, 290, 800, "center")
        return

    elseif ESTADO_ATUAL == "vitoria" then
        love.graphics.setColor(0.05, 0.15, 0.08, 1)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        for i = 1, 80 do
            local sx = (i*97.3) % 800
            local sy = (i*137.5) % 580
            local sa = 0.5 + math.sin(love.timer.getTime()*2 + i)*0.4
            love.graphics.setColor(1,1,0.8, sa)
            love.graphics.circle("fill", sx, sy, love.math.random()*2)
        end
        love.graphics.setNewFont(40)
        love.graphics.setColor(0.9, 1.0, 0.4, 1)
        love.graphics.printf("CANCAO COMPLETA", 0, 130, 800, "center")
        love.graphics.setNewFont(18)
        love.graphics.setColor(0.6,1,0.7, 0.9)
        love.graphics.printf("O silencio foi restaurado.", 0, 195, 800, "center")
        love.graphics.setColor(0.2,0.2,0.2, 0.6)
        love.graphics.rectangle("fill", 80, 255, 640, 130, 12, 12)
        love.graphics.setColor(0.8,1,0.5, 0.9)
        love.graphics.setNewFont(15)
        love.graphics.printf("ECO DO MUNDO REAL", 0, 268, 800, "center")
        love.graphics.setColor(1,1,1, 0.85)
        love.graphics.printf('"' .. MensagemVitoria .. '"', 100, 300, 600, "center")
        love.graphics.setNewFont(14)
        local pa = 0.4 + math.sin(love.timer.getTime()*2)*0.4
        love.graphics.setColor(1,1,1, pa)
        love.graphics.printf("[ ENTER ] Jogar novamente", 0, 500, 800, "center")
        love.graphics.setNewFont(16)
        return
    end

    -- MUNDO COM CÂMERA
    love.graphics.push()
    if ESTADO_ATUAL == "exploracao" or ESTADO_ATUAL == "pausa_sincopada" then
        love.graphics.translate(-CameraX, 0)
    end

    local iniX = (ESTADO_ATUAL == "solo_de_alma") and 0    or (CameraX - 60)
    local fimX = (ESTADO_ATUAL == "solo_de_alma") and 800   or (CameraX + 860)
    DesenharTerreno(iniX, fimX)

    if ESTADO_ATUAL == "exploracao" or ESTADO_ATUAL == "pausa_sincopada" then
        DesenharZonasSilencio()
        DesenharIconesDistracao()
        DesenharNotas()
        DesenharLinhasEcoMiller()
    end

    local pX = (ESTADO_ATUAL == "solo_de_alma") and 110 or Sopro.x
    local pY = (ESTADO_ATUAL == "solo_de_alma") and 480 or Sopro.y
    DesenharSopro(pX, pY)

    -- Partículas no mundo (em coordenadas do mundo, dentro da câmera)
    if ESTADO_ATUAL == "exploracao" or ESTADO_ATUAL == "pausa_sincopada" then
        DesenharParticulas()
    end

    love.graphics.pop()

    DesenharNevoa()

    -- Partículas no Solo (fora da câmera)
    if ESTADO_ATUAL == "solo_de_alma" then
        DesenharParticulas()
    end

    if FlashErro.ativo then
        local at = 1 - (FlashErro.timer / FlashErro.duracao)
        love.graphics.setColor(1, 0.1, 0.1, at*0.35)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end
    if FlashAcerto.ativo then
        local at = 1 - (FlashAcerto.timer / FlashAcerto.duracao)
        love.graphics.setColor(FlashAcerto.cor[1], FlashAcerto.cor[2], FlashAcerto.cor[3], at*0.20)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end

    DesenharBarraRuido()
    DesenharPoderes()

    love.graphics.setColor(1, 0.15, 0.15, 0.08 + fatorR*0.55)
    love.graphics.rectangle("fill", 0, 0, 800, 5)

    love.graphics.setColor(1,1,1, 0.4)
    love.graphics.print("Fase " .. FaseAtual, 740, 12)

    if MsgZonaSilencio.ativo then
        local at = 1 - (MsgZonaSilencio.timer/MsgZonaSilencio.duracao)
        love.graphics.setColor(0.4, 1, 0.9, at*0.9)
        love.graphics.printf("Zona de Silencio - O ruido se dissolve aqui.", 0, 90, 800, "center")
    end

    if ESTADO_ATUAL == "pausa_sincopada" then
        love.graphics.setColor(0,0,0, 0.35)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1,1,1, 0.9)
        love.graphics.setNewFont(28)
        love.graphics.printf("A  PAUSA  SINCOPADA", 0, 145, 800, "center")
        love.graphics.setNewFont(16)
        love.graphics.setColor(0.8,1,0.8, 0.8)
        love.graphics.printf("Cultive o silencio.\nNao mova, nao aja.", 0, 188, 800, "center")
        local progresso = TempoImovel / TempoRequeridoPausa
        love.graphics.setColor(0.15,0.15,0.15, 0.7)
        love.graphics.rectangle("fill", 280, 255, 240, 12, 5, 5)
        love.graphics.setColor(0.3,1,0.6, 0.9)
        love.graphics.rectangle("fill", 280, 255, 240*progresso, 12, 5, 5)
        love.graphics.setColor(1,1,1, 0.4)
        love.graphics.rectangle("line", 280, 255, 240, 12, 5, 5)
        love.graphics.setColor(1,1,1, 0.55)
        local segs = math.floor(TempoRequeridoPausa - TempoImovel) + 1
        love.graphics.printf(segs .. "s", 0, 275, 800, "center")
        love.graphics.setColor(0.4,1,0.6, 0.7)
        love.graphics.printf("Resistindo ao impulso, voce ganha a Aura de Ressonancia.", 40, 310, 720, "center")
        love.graphics.setNewFont(16)

    elseif ESTADO_ATUAL == "solo_de_alma" then
        love.graphics.setColor(0,0,0, 0.55)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setNewFont(26)
        love.graphics.setColor(1,1,1, 0.9)
        love.graphics.printf("S O L O   D E   A L M A", 0, 30, 800, "center")

        -- Legenda das teclas (setas desenhadas, sem emoji)
        local ly = 70
        DesenharSeta(280, ly + 8, "esq",  10, {1, 0.55, 0.3, 0.9})
        love.graphics.setNewFont(13)
        love.graphics.setColor(1,1,1, 0.8)
        love.graphics.print("Grave", 300, ly + 1)
        DesenharSeta(380, ly + 8, "cima", 10, {0.4, 1, 0.5, 0.9})
        love.graphics.print("Medio", 400, ly + 1)
        DesenharSeta(480, ly + 8, "dir",  10, {0.5, 0.7, 1, 0.9})
        love.graphics.print("Agudo", 500, ly + 1)
        love.graphics.setNewFont(16)

        if EstadoSolo == "preparando" then
            love.graphics.setColor(1, 0.9, 0.3, 1)
            love.graphics.setNewFont(40)
            local segs = math.ceil(3.0 - TemporizadorSeq)
            love.graphics.printf("Preparar... " .. segs, 0, 280, 800, "center")
            love.graphics.setNewFont(16)
        elseif EstadoSolo == "exibindo" then
            love.graphics.setColor(0.8,0.9,1, 0.85)
            love.graphics.printf("Escute a melodia do Eco...", 0, 220, 800, "center")
            -- Sequência exibida com setas
            local bw, bh, gap = 60, 50, 12
            local total = #SequenciaMemoria * (bw+gap) - gap
            local sx = (800 - total)/2
            for i, n in ipairs(SequenciaMemoria) do
                local bx = sx + (i-1)*(bw+gap)
                local ativo = (i == NotaExibidaAtual - 1)
                love.graphics.setColor(ativo and 1 or 0.2, ativo and 0.9 or 0.4, ativo and 0.3 or 0.7, ativo and 0.95 or 0.4)
                love.graphics.rectangle("fill", bx, 290, bw, bh, 8, 8)
                love.graphics.setColor(1,1,1, ativo and 1 or 0.6)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", bx, 290, bw, bh, 8, 8)
                love.graphics.setLineWidth(1)
                local dir = n == "grave" and "esq" or (n == "medio" and "cima" or "dir")
                local cor = ativo and {1,1,1, 1} or {1,1,1, 0.7}
                DesenharSeta(bx + bw/2, 290 + bh/2, dir, 14, cor)
            end
        elseif EstadoSolo == "pausa_pre_jogo" then
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.setNewFont(22)
            love.graphics.printf("Agora repita no ritmo!", 0, 280, 800, "center")
            love.graphics.setNewFont(16)
        elseif EstadoSolo == "jogando" then
            DesenharRitmo()
        elseif EstadoSolo == "vitoria_fase" then
            love.graphics.setNewFont(36)
            love.graphics.setColor(0.9, 1, 0.5, 1)
            love.graphics.printf("SEQUENCIA COMPLETA!", 0, 220, 800, "center")
            love.graphics.setNewFont(18)
            love.graphics.setColor(1,1,1, 0.85)
            if Ritmo.melhor_combo >= 3 then
                love.graphics.printf("Melhor combo: x" .. Ritmo.melhor_combo, 0, 280, 800, "center")
            end
            love.graphics.setNewFont(16)
        end
    end
end
