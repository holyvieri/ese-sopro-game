-- =============================================================================
-- SOPRO - FRAMEWORK AUDIO-COGNITIVO REATIVO v2
-- Protótipo com Física de Flutuação e Feedback Visual por Aura
-- =============================================================================

local ESTADO_ATUAL = "intro" -- intro, exploracao, pausa_sincopada, solo_de_alma, game_over, vitoria

-- Atuador Principal Refatorado para Flutuação
local Sopro = {
    x = 100, y = 300, vy = 0, raio = 18, 
    velocidade_horizontal = 220, 
    forca_flutuacao = -250, -- Velocidade de subida ao levitar
    vel_glide = 40,         -- Velocidade de descida lenta ao planar
    no_chao = false,
    pulsa_raio = 18,
    perto_de_nota = false   -- Estado para controle da aura
}

-- Variáveis do Sistema
local CâmeraX = 0
local RuídoMental = 15
local LimiteRuído = 100
local GravidadeBasal = 600 -- Gravidade reduzida para sensação etérea
local FaseAtual = 1

-- Tabelas e Buffers
local NotasDoAmbiente = {}
local NotasColetadas = 0
local TempoImóvel = 0
local TempoRequeridoPausa = 5.0

local SequenciaMemoria = {}
local SequenciaJogador = {}
local NotaExibidaAtual = 1
local TemporizadorSequencia = 0
local EstadoSolo = "exibindo"

local Sons = {}

local ConfigFases = {
    { cor = {0.35, 0.55, 0.75}, onda = 160, qtd_notas = 2, tam_sequencia = 3 },
    { cor = {0.75, 0.45, 0.35}, onda = 110, qtd_notas = 3, tam_sequencia = 4 },
    { cor = {0.45, 0.25, 0.65}, onda = 80,  qtd_notas = 4, tam_sequencia = 5 }
}

-- =============================================================================
-- SINTETIZADOR DE ÁUDIO NATIVO (Sem alterações)
-- =============================================================================
local function GerarNotaAudio(frequencia, duracao, tipo_onda)
    local taxa_amostragem = 44100
    local total_amostras = math.floor(taxa_amostragem * duracao)
    local dados_som = love.sound.newSoundData(total_amostras, taxa_amostragem, 16, 1)
    
    for i = 0, total_amostras - 1 do
        local tempo = i / taxa_amostragem
        local onda = 0
        if tipo_onda == "seno" then onda = math.sin(2 * math.pi * frequencia * tempo)
        elseif tipo_onda == "ruido" then onda = love.math.random() * 2 - 1 end
        local fator_decaimento = math.exp(-3.5 * tempo)
        dados_som:setSample(i, onda * fator_decaimento * 0.3)
    end
    return love.audio.newSource(dados_som)
end

local function ObterYTerreno(x)
    local config = ConfigFases[FaseAtual] or ConfigFases[1]
    return 460 + math.sin(x / config.onda) * 35 + math.sin(x / (config.onda * 2)) * 25
end

local function InicializarFase(fase)
    FaseAtual = fase
    if FaseAtual > #ConfigFases then ESTADO_ATUAL = "vitoria"; return end

    local conf = ConfigFases[FaseAtual]
    NotasDoAmbiente = {}
    NotasColetadas = 0
    RuídoMental = 15
    Sopro.x = 100
    Sopro.vy = 0
    
    for i = 1, conf.qtd_notas do
        local px = 550 * i
        table.insert(NotasDoAmbiente, {
            x = px,
            y = ObterYTerreno(px) - 100, -- Notas flutuando mais alto para exigir levitação
            progresso = 0, absorvida = false
        })
    end
    ESTADO_ATUAL = "exploracao"
end

-- =============================================================================
-- NÚCLEO LÖVE2D
-- =============================================================================
function love.load()
    love.window.setTitle("Sopro - Ressonância v2")
    love.window.setMode(800, 600)
    love.graphics.setNewFont(16)
    
    Sons["grave"] = GerarNotaAudio(261.63, 0.8, "seno")
    Sons["medio"] = GerarNotaAudio(329.63, 0.8, "seno")
    Sons["agudo"] = GerarNotaAudio(392.00, 0.8, "seno")
    Sons["sucesso"] = GerarNotaAudio(523.25, 0.4, "seno")
    Sons["dissonancia"] = GerarNotaAudio(130.00, 0.5, "ruido")

    InicializarFase(1)
    ESTADO_ATUAL = "intro"
end

function love.update(dt)
    Sopro.pulsa_raio = Sopro.raio + math.sin(love.timer.getTime() * 5) * 1.5

    if ESTADO_ATUAL == "intro" or ESTADO_ATUAL == "vitoria" or ESTADO_ATUAL == "game_over" then return end

    RuídoMental = RuídoMental + (3.8 * dt)
    if RuídoMental >= LimiteRuído then Sons["dissonancia"]:play(); ESTADO_ATUAL = "game_over" end

    -- -------------------------------------------------------------------------
    -- NOVA FÍSICA DE FLUTUAÇÃO (EXPLORAÇÃO)
    -- -------------------------------------------------------------------------
    if ESTADO_ATUAL == "exploracao" then
        -- Movimento Horizontal
        if love.keyboard.isDown("right") then Sopro.x = Sopro.x + Sopro.velocidade_horizontal * dt end
        if love.keyboard.isDown("left") then Sopro.x = Sopro.x - Sopro.velocidade_horizontal * dt end
        if Sopro.x < 0 then Sopro.x = 0 end

        -- Lógica de Levitação vs Glide
        if love.keyboard.isDown("up") then
            -- Ativamente levitando: aplica força para cima anulando a gravidade
            Sopro.vy = Sopro.forca_flutuacao
        else
            -- Planando: aplica gravidade basal mas limita a velocidade de queda
            Sopro.vy = Sopro.vy + GravidadeBasal * dt
            if Sopro.vy > Sopro.vel_glide then Sopro.vy = Sopro.vel_glide end
        end

        Sopro.y = Sopro.y + Sopro.vy * dt

        -- Colisão com terreno (Não há mais 'pulo', apenas parada)
        local chaoY = ObterYTerreno(Sopro.x) - Sopro.raio
        if Sopro.y >= chaoY then
            Sopro.y = chaoY
            Sopro.vy = 0
            Sopro.no_chao = true
        else
            Sopro.no_chao = false
        end

        CâmeraX = Sopro.x - 400

        -- Lógica de Interação e Controle da Aura
        local zona_ativa = false
        for _, nota in ipairs(NotasDoAmbiente) do
            if not nota.absorvida then
                local dx = math.abs(Sopro.x - nota.x)
                local dy = math.abs(Sopro.y - nota.y)

                -- Distância de interação (raio onde a aura acende)
                if dx < 50 and dy < 60 then
                    zona_ativa = true
                    if love.keyboard.isDown("space") then
                        nota.progresso = nota.progresso + (45 * dt)
                        if math.floor(love.timer.getTime() * 5) % 2 == 0 then Sons["medio"]:play() end

                        if nota.progresso >= 100 then
                            nota.absorvida = true
                            NotasColetadas = NotasColetadas + 1
                            RuídoMental = math.max(0, RuídoMental - 35)
                            Sons["sucesso"]:play()
                            
                            -- Transições
                            if NotasColetadas == 1 and FaseAtual == 1 then
                                ESTADO_ATUAL = "pausa_sincopada"; TempoImóvel = 0
                            elseif NotasColetadas >= #NotasDoAmbiente then
                                ESTADO_ATUAL = "solo_de_alma"
                                SequenciaMemoria = {}
                                local opcoes = {"grave", "medio", "agudo"}
                                for i = 1, ConfigFases[FaseAtual].tam_sequencia do
                                    table.insert(SequenciaMemoria, opcoes[love.math.random(1, 3)])
                                end
                                SequenciaJogador = {}; NotaExibidaAtual = 1; TemporizadorSequencia = 0; EstadoSolo = "exibindo"
                            end
                        end
                    else
                        nota.progresso = math.max(0, nota.progresso - (80 * dt))
                    end
                end
            end
        end
        Sopro.perto_de_nota = zona_ativa -- Atualiza estado para o desenho da aura

        -- Penalidade de clique rápido
        if not zona_ativa and love.keyboard.isDown("space") then
            RuídoMental = RuídoMental + (20 * dt) -- Sobe rápido se segurar errado
            if math.floor(love.timer.getTime() * 8) % 2 == 0 then Sons["dissonancia"]:play() end
        end

    -- -------------------------------------------------------------------------
    -- PAUSA SINCOPADA E SOLO (Sem alterações na lógica)
    -- -------------------------------------------------------------------------
    elseif ESTADO_ATUAL == "pausa_sincopada" then
        if love.keyboard.isDown("left", "right", "up", "space") then
            TempoImóvel = 0; RuídoMental = RuídoMental + (8 * dt)
            if math.floor(love.timer.getTime() * 6) % 3 == 0 then Sons["dissonancia"]:play() end
        else
            TempoImóvel = TempoImóvel + dt
            if TempoImóvel >= TempoRequeridoPausa then RuídoMental = 0; Sons["sucesso"]:play(); ESTADO_ATUAL = "exploracao" end
        end
    elseif ESTADO_ATUAL == "solo_de_alma" then
        if EstadoSolo == "exibindo" then
            TemporizadorSequencia = TemporizadorSequencia + dt
            if TemporizadorSequencia > 0.9 then
                TemporizadorSequencia = 0
                local nota = SequenciaMemoria[NotaExibidaAtual]
                if nota then Sons[nota]:play() end
                NotaExibidaAtual = NotaExibidaAtual + 1
                if NotaExibidaAtual > #SequenciaMemoria + 1 then EstadoSolo = "esperando_jogador" end
            end
        end
    end
end

function love.keypressed(key)
    if ESTADO_ATUAL == "intro" then
        if key == "return" then InicializarFase(1) end
        return
    elseif ESTADO_ATUAL == "game_over" and key == "r" then
        InicializarFase(1)
        return
    end

    if ESTADO_ATUAL == "solo_de_alma" and EstadoSolo == "esperando_jogador" then
        local nota = nil
        if key == "left" then nota = "grave"
        elseif key == "up" then nota = "medio"
        elseif key == "right" then nota = "agudo" end
        
        if nota then
            table.insert(SequenciaJogador, nota); Sons[nota]:play()
            local idx = #SequenciaJogador
            if SequenciaJogador[idx] ~= SequenciaMemoria[idx] then
                Sons["dissonancia"]:play(); RuídoMental = math.min(100, RuídoMental + 20)
                SequenciaJogador = {}; NotaExibidaAtual = 1; TemporizadorSequencia = 0; EstadoSolo = "exibindo"
            elseif #SequenciaJogador == #SequenciaMemoria then
                Sons["sucesso"]:play(); InicializarFase(FaseAtual + 1)
            end
        end
    end
end

-- =============================================================================
-- RENDERIZAÇÃO VISUAL COGNITIVA
-- =============================================================================
function love.draw()
    local conf = ConfigFases[FaseAtual] or ConfigFases[1]
    local fatorRuido = RuídoMental / LimiteRuído
    local r = conf.cor[1] * (1.0 - fatorRuido * 0.85); local g = conf.cor[2] * (1.0 - fatorRuido * 0.85); local b = conf.cor[3] * (1.0 - fatorRuido * 0.85)
    love.graphics.setBackgroundColor(r, g, b)

    -- -------------------------------------------------------------------------
    -- INTRODUÇÃO SIMPLIFICADA (Feedback: Menos texto)
    -- -------------------------------------------------------------------------
    if ESTADO_ATUAL == "intro" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("S O P R O", 0, 180, 800, "center")
        love.graphics.printf("Resgate sua Alma do ruído digital.", 0, 230, 800, "center")
        
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("[Setas ESQ/DIR] Move\n[Segurar CIMA] Flutua\n\nAo acender a Aura Verde, SUSTENTE segurando [ESPAÇO].", 0, 280, 800, "center")
        
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("[ Pressione ENTER ]", 0, 480, 800, "center")
        return
    elseif ESTADO_ATUAL == "game_over" then
        love.graphics.setColor(0.9, 0.2, 0.2); love.graphics.printf("MENTE SOBRECARREGADA", 0, 260, 800, "center")
        love.graphics.setColor(1, 1, 1, 0.6); love.graphics.printf("Pressione 'R' para focar novamente.", 0, 300, 800, "center"); return
    elseif ESTADO_ATUAL == "vitoria" then
        love.graphics.setColor(1, 0.9, 0.3); love.graphics.printf("CANÇÃO COMPLETA", 0, 250, 800, "center")
        love.graphics.printf("O silêncio foi restaurado.", 0, 290, 800, "center"); return
    end

    love.graphics.push()
    if ESTADO_ATUAL == "exploracao" or ESTADO_ATUAL == "pausa_sincopada" then love.graphics.translate(-CâmeraX, 0) end

    -- Terreno
    love.graphics.setColor(0.14, 0.16, 0.2, 0.9)
    local passo = 10
    local inX = (ESTADO_ATUAL == "solo_de_alma") and 0 or CâmeraX - 50
    local fimX = (ESTADO_ATUAL == "solo_de_alma") and 800 or CâmeraX + 850
    for px = inX, fimX, passo do
        love.graphics.polygon("fill", px, ObterYTerreno(px), px + passo, ObterYTerreno(px + passo), px + passo, 600, px, 600)
    end

    -- Notas
    if ESTADO_ATUAL == "exploracao" or ESTADO_ATUAL == "pausa_sincopada" then
        for _, nota in ipairs(NotasDoAmbiente) do
            if not nota.absorvida then
                love.graphics.setColor(1, 0.9, 0.4, 0.2); love.graphics.circle("fill", nota.x, nota.y, 25)
                love.graphics.setColor(1, 0.9, 0.3); love.graphics.circle("fill", nota.x, nota.y, 8)
                if nota.progresso > 0 then
                    love.graphics.setColor(1, 1, 1, 0.7); love.graphics.setLineWidth(3)
                    love.graphics.arc("line", "open", nota.x, nota.y, 18, -math.pi/2, (-math.pi/2) + (nota.progresso / 100) * math.pi * 2); love.graphics.setLineWidth(1)
                end
            end
        end
    end

    -- Sopro e Aura Reativa
    local pX = (ESTADO_ATUAL == "solo_de_alma") and 400 or Sopro.x
    local pY = (ESTADO_ATUAL == "solo_de_alma") and 350 or Sopro.y
    
    -- -------------------------------------------------------------------------
    -- NOVA AURA DE FEEDBACK (Verde = Perto, Branco/Alfa = Longe)
    -- -------------------------------------------------------------------------
    if ESTADO_ATUAL == "exploracao" then
        love.graphics.setLineWidth(2)
        if Sopro.perto_de_nota then
            -- Aura Verde brilhante indica: APERTE ESPAÇO AGORA
            love.graphics.setColor(0.2, 1, 0.4, 0.6 + math.sin(love.timer.getTime() * 10) * 0.2)
            love.graphics.circle("line", pX, pY, Sopro.raio + 15 + math.sin(love.timer.getTime() * 8) * 2)
        else
            -- Aura Branca fraca: Modo de espera
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.circle("line", pX, pY, Sopro.raio + 12)
        end
        love.graphics.setLineWidth(1)
    end

    -- Corpo Sopro
    love.graphics.setColor(1, 1, 1, 0.95); love.graphics.circle("fill", pX, pY, Sopro.pulsa_raio)
    love.graphics.polygon("fill", pX - Sopro.raio, pY, pX + Sopro.raio, pY, pX, pY + 22)
    love.graphics.setColor(r * 0.2, g * 0.2, b * 0.2); love.graphics.circle("fill", pX - 5, pY - 2, 2.5); love.graphics.circle("fill", pX + 5, pY - 2, 2.5)

    love.graphics.pop()

    -- HUD
    if ESTADO_ATUAL == "exploracao" then
        love.graphics.setColor(1, 0.2, 0.2, 0.1 + (RuídoMental/100) * 0.6); love.graphics.rectangle("fill", 0, 0, 800, 5)
    elseif ESTADO_ATUAL == "pausa_sincopada" then
        love.graphics.setColor(1, 1, 1, 0.8); love.graphics.printf("A   P A U S A   S I N C O P A D A", 0, 160, 800, "center")
        love.graphics.printf("Cultive o silêncio. Não aja.", 0, 190, 800, "center")
        love.graphics.rectangle("line", 320, 240, 160, 6); love.graphics.rectangle("fill", 320, 240, (TempoImóvel / TempoRequeridoPausa) * 160, 6)
    elseif ESTADO_ATUAL == "solo_de_alma" then
        love.graphics.setColor(1, 1, 1, 0.85); love.graphics.printf("S O L O   D E   A L M A", 0, 100, 800, "center")
        if EstadoSolo == "exibindo" then
            love.graphics.printf("Ouça a melodia do Eco...", 0, 130, 800, "center")
            local nota = SequenciaMemoria[NotaExibidaAtual - 1]
            if nota then
                love.graphics.setColor(1, 0.9, 0.3)
                if nota == "grave" then love.graphics.printf("<< GRAVE (Esq)", 0, 180, 800, "center")
                elseif nota == "medio" then love.graphics.printf("== MÉDIO (Cima) ==", 0, 180, 800, "center")
                elseif nota == "agudo" then love.graphics.printf("(Dir) AGUDO >>", 0, 180, 800, "center") end
            end
        else
            love.graphics.printf("Repita a melodia (Setas Esq, Cima, Dir)", 0, 130, 800, "center")
            local m = ""; for i = 1, #SequenciaJogador do m = m .. " o " end
            love.graphics.setColor(0.3, 0.9, 0.4); love.graphics.printf(m, 0, 180, 800, "center")
        end
    end
end