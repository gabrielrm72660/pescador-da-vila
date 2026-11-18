extends RefCounted
## Idioma da interface (v0.5.6): português (padrão), español e english.
## O texto em português é a chave: Idioma.t("Porão") devolve "Bodega" ou "Hold" conforme a escolha.
## O que não está na tabela volta em português (missões e mensagens do diário, por enquanto).
## A escolha fica em user://pescador.cfg, seção "geral", chave "idioma".

const ARQUIVO := "user://pescador.cfg"
const IDIOMAS := ["pt", "es", "en"]
const NOME_IDIOMA := {"pt": "Português", "es": "Español", "en": "English"}

static var lingua: String = "pt"
static var _carregado: bool = false

static func t(texto: String) -> String:
    if not _carregado:
        carregar()
    if lingua == "pt":
        return texto
    var linha = TABELA.get(texto)
    if linha == null:
        return texto
    return String(linha[0 if lingua == "es" else 1])

static func carregar() -> void:
    _carregado = true
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO) == OK:
        var v = String(cfg.get_value("geral", "idioma", "pt"))
        lingua = v if v in IDIOMAS else "pt"

static func definir(codigo: String) -> void:
    if not codigo in IDIOMAS:
        return
    lingua = codigo
    _carregado = true
    var cfg := ConfigFile.new()
    cfg.load(ARQUIVO)                          # mantém os volumes e o que mais houver
    cfg.set_value("geral", "idioma", codigo)
    cfg.save(ARQUIVO)

## português -> [español, english]
const TABELA := {
    # menu principal
    "PAUSA": ["PAUSA", "PAUSED"],
    "O oceano continua esperando por você.": ["El océano te sigue esperando.", "The ocean is still waiting for you."],
    "Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do Estrela d'Alva.": ["Una aventura de pesca en el Atlántico brasileño.\nToma el mando del Estrela d'Alva.", "A fishing adventure in the Brazilian Atlantic.\nTake command of the Estrela d'Alva."],
    "VOLTAR A NAVEGAR": ["VOLVER A NAVEGAR", "BACK TO SAILING"],
    "CONTINUAR A VIAGEM": ["CONTINUAR EL VIAJE", "CONTINUE VOYAGE"],
    "COMEÇAR A VIAGEM": ["EMPEZAR EL VIAJE", "START VOYAGE"],
    "NOVO JOGO": ["NUEVO JUEGO", "NEW GAME"],
    "OPÇÕES": ["OPCIONES", "OPTIONS"],
    "SAIR DO JOGO": ["SALIR DEL JUEGO", "QUIT GAME"],
    "CONFIRMAR: APAGAR A VIAGEM SALVA?": ["¿CONFIRMAR: BORRAR EL VIAJE GUARDADO?", "CONFIRM: DELETE SAVED VOYAGE?"],
    "W A S D  navegar   •   ESPAÇO  frear\nF  pescar e atracar no cais   •   I  inventário (porão)\nTAB  diário de bordo   •   M  carta náutica   •   ESC  menu":
        ["W A S D  navegar   •   ESPACIO  frenar\nF  pescar y atracar en el muelle   •   I  inventario (bodega)\nTAB  diario de a bordo   •   M  carta náutica   •   ESC  menú",
         "W A S D  sail   •   SPACE  brake\nF  fish and dock at the pier   •   I  inventory (hold)\nTAB  logbook   •   M  nautical chart   •   ESC  menu"],
    # opções
    "Ajuste o jogo do seu jeito.": ["Ajusta el juego a tu manera.", "Set up the game your way."],
    "GERAL": ["GENERAL", "GENERAL"],
    "ÁUDIO": ["AUDIO", "AUDIO"],
    "GRÁFICOS": ["GRÁFICOS", "GRAPHICS"],
    "VOLTAR AO MENU": ["VOLVER AL MENÚ", "BACK TO MENU"],
    "VOLTAR": ["VOLVER", "BACK"],
    "Idioma do jogo.": ["Idioma del juego.", "Game language."],
    "IDIOMA": ["IDIOMA", "LANGUAGE"],
    "Menus, painéis e o HUD mudam na hora. Missões e mensagens do diário continuam em português por enquanto.":
        ["Los menús, paneles y el HUD cambian al instante. Las misiones y los mensajes del diario siguen en portugués por ahora.",
         "Menus, panels and the HUD change right away. Missions and logbook messages are still in Portuguese for now."],
    "Cada som tem o seu volume.": ["Cada sonido tiene su volumen.", "Each sound has its own volume."],
    "Geral": ["General", "Master"],
    "Mar e ondas": ["Mar y olas", "Sea and waves"],
    "Música": ["Música", "Music"],
    "Vento": ["Viento", "Wind"],
    "Chuva e trovões": ["Lluvia y truenos", "Rain and thunder"],
    "Motor e casco": ["Motor y casco", "Engine and hull"],
    "Efeitos": ["Efectos", "Effects"],
    "Silenciar tudo": ["Silenciar todo", "Mute all"],
    "Som desligado — ligar": ["Sonido apagado — activar", "Sound off — turn on"],
    "Qualidade e desempenho (o mesmo do F10).": ["Calidad y rendimiento (lo mismo que F10).", "Quality and performance (same as F10)."],
    "QUALIDADE": ["CALIDAD", "QUALITY"],
    "Baixa": ["Baja", "Low"],
    "Média": ["Media", "Medium"],
    "Alta": ["Alta", "High"],
    "Ultra": ["Ultra", "Ultra"],
    "LIMITE DE QUADROS": ["LÍMITE DE FOTOGRAMAS", "FRAME RATE LIMIT"],
    "Sem limite": ["Sin límite", "Unlimited"],
    "TELA": ["PANTALLA", "DISPLAY"],
    "Janela": ["Ventana", "Windowed"],
    "Tela cheia  (Alt+Enter)": ["Pantalla completa  (Alt+Enter)", "Fullscreen  (Alt+Enter)"],
    "ligado": ["activado", "on"],
    "desligado": ["desactivado", "off"],
    "Ajuste automático (abaixa a qualidade se travar)": ["Ajuste automático (baja la calidad si se traba)", "Auto adjust (lowers quality if it stutters)"],
    "Mostrar FPS (F3)": ["Mostrar FPS (F3)", "Show FPS (F3)"],
    "AVANÇADO  (luz, névoa, reflexos, pintura)  [F11]": ["AVANZADO  (luz, niebla, reflejos, pintura)  [F11]", "ADVANCED  (light, fog, reflections, paint)  [F11]"],
    "Teste de desempenho da GPU (≈2 min)  [F2]": ["Prueba de rendimiento de la GPU (≈2 min)  [F2]", "GPU performance test (≈2 min)  [F2]"],
    "Baixa: sem sombras, vegetação reduzida. Para PCs fracos.": ["Baja: sin sombras, vegetación reducida. Para PCs débiles.", "Low: no shadows, reduced vegetation. For weak PCs."],
    "Média: sombras simples, vegetação reduzida.": ["Media: sombras simples, vegetación reducida.", "Medium: simple shadows, reduced vegetation."],
    "Alta: sombras, vegetação detalhada e árvores que balançam com o vento.": ["Alta: sombras, vegetación detallada y árboles que se mecen con el viento.", "High: shadows, detailed vegetation and trees swaying in the wind."],
    "Ultra: tudo da Alta + sombras suaves em alta resolução, mar mais fino, árvores e pedras com mais detalhe, filtro de textura máximo e alcance maior. Pede placa de vídeo boa; extras de iluminação só no renderizador Forward+.":
        ["Ultra: todo lo de Alta + sombras suaves en alta resolución, mar más fino, árboles y rocas con más detalle, filtro de textura máximo y mayor alcance. Pide una buena tarjeta de video; extras de iluminación solo en Forward+.",
         "Ultra: everything in High + soft high-resolution shadows, finer sea, more detailed trees and rocks, maximum texture filtering and longer view distance. Needs a good graphics card; lighting extras only in Forward+."],
    # cais
    "Cais de %s": ["Muelle de %s", "%s pier"],
    "Carteira: R$ %d   ·   Porão: %d peixe(s), %s kg   ·   Tanque: %d de %d L   ·   Casco: %d%%":
        ["Cartera: R$ %d   ·   Bodega: %d pez(es), %s kg   ·   Tanque: %d de %d L   ·   Casco: %d%%",
         "Wallet: R$ %d   ·   Hold: %d fish, %s kg   ·   Tank: %d of %d L   ·   Hull: %d%%"],
    "Iscas: %s · kit R$ 25 [Q]": ["Carnadas: %s · kit R$ 25 [Q]", "Bait: %s · kit R$ 25 [Q]"],
    "Linha reforçada (máximo)": ["Sedal reforzado (máximo)", "Line reinforced (max)"],
    "Reforçar linha [U] · nível %d/4 · R$ %d": ["Reforzar sedal [U] · nivel %d/4 · R$ %d", "Reinforce line [U] · level %d/4 · R$ %d"],
    "Vender tudo por R$ %d  [1]": ["Vender todo por R$ %d  [1]", "Sell everything for R$ %d  [1]"],
    "Nada para vender": ["Nada para vender", "Nothing to sell"],
    "Casco em ordem (100%)": ["Casco en buen estado (100%)", "Hull in good shape (100%)"],
    "Conserto do casco: R$ %d por ponto — sem dinheiro": ["Reparación del casco: R$ %d por punto — sin dinero", "Hull repair: R$ %d per point — no money"],
    "Consertar casco: %d%% → %d%% · R$ %d  [R]": ["Reparar casco: %d%% → %d%% · R$ %d  [R]", "Repair hull: %d%% → %d%% · R$ %d  [R]"],
    "Tanque cheio": ["Tanque lleno", "Tank full"],
    "Diesel R$ %d/L — sem dinheiro": ["Diésel R$ %d/L — sin dinero", "Diesel R$ %d/L — no money"],
    "Abastecer %d L · R$ %d  [2]": ["Repostar %d L · R$ %d  [2]", "Refuel %d L · R$ %d  [2]"],
    "MELHORIAS DO BARCO": ["MEJORAS DEL BARCO", "BOAT UPGRADES"],
    "Zarpar   [F]": ["Zarpar   [F]", "Set sail   [F]"],
    # HUD
    "Pescar  [F]": ["Pescar  [F]", "Fish  [F]"],
    "Porão  [I]": ["Bodega  [I]", "Hold  [I]"],
    "Diário de bordo  [TAB]": ["Diario de a bordo  [TAB]", "Logbook  [TAB]"],
    "Porão": ["Bodega", "Hold"],
    "Diário de bordo": ["Diario de a bordo", "Logbook"],
    "PERFEITO!": ["¡PERFECTO!", "PERFECT!"],
    "BOM!": ["¡BIEN!", "GOOD!"],
    "ERROU": ["FALLASTE", "MISSED"],
    "Percorrido: %d m": ["Recorrido: %d m", "Travelled: %d m"],
    "Cais a %d m": ["Muelle a %d m", "Pier %d m"],
    "nós": ["nudos", "kn"],
    "Nada anotado ainda.": ["Nada anotado todavía.", "Nothing written yet."],
    "Cardume: %s": ["Cardumen: %s", "School: %s"],
    "Alto": ["Alto", "High"],
    "Médio": ["Medio", "Medium"],
    "Baixo": ["Bajo", "Low"],
    "Puxar": ["Tirar", "Reel"],
    "Clique num peixe para pegar.": ["Haz clic en un pez para tomarlo.", "Click a fish to pick it up."],
    "Clique numa casa para soltar.": ["Haz clic en una casilla para soltarlo.", "Click a cell to drop it."],
    "R ou botão direito: girar.": ["R o botón derecho: girar.", "R or right click: rotate."],
    "Vazio. Pare perto de um": ["Vacía. Detente cerca de un", "Empty. Stop near a"],
    "cardume e pesque com F.": ["cardumen y pesca con F.", "school and fish with F."],
    "Peixe grande ocupa mais casas.": ["Un pez grande ocupa más casillas.", "Big fish take more cells."],
    "Devolver ao mar": ["Devolver al mar", "Release to the sea"],
    "Arrumar o porão": ["Ordenar la bodega", "Tidy the hold"],
    "F: atracar em %s": ["F: atracar en %s", "F: dock at %s"],
    "Destino marcado: %.0f m  [M]": ["Destino marcado: %.0f m  [M]", "Marked destination: %.0f m  [M]"],
    "Cais": ["Muelle", "Pier"],
    "Farol": ["Faro", "Lighthouse"],
    "Arquipélagos de São Paulo e São Pedro": ["Archipiélagos de São Paulo y São Pedro", "São Paulo and São Pedro archipelagos"],
    "Arquipélago de São Paulo": ["Archipiélago de São Paulo", "São Paulo archipelago"],
    "Arquipélago de São Pedro": ["Archipiélago de São Pedro", "São Pedro archipelago"],
    "casa da grade: %d m": ["casilla: %d m", "grid square: %d m"],
    "Recife / banco": ["Arrecife / banco", "Reef / bank"],
    "Casas": ["Casas", "Houses"],
    "Você": ["Tú", "You"],
    "Destino": ["Destino", "Destination"],
    "Carta náutica": ["Carta náutica", "Nautical chart"],
    "Arquipélago da Vila do Porto  ·  cada casa da grade: %d m": ["Archipiélago de Vila do Porto  ·  cada casilla: %d m", "Vila do Porto archipelago  ·  each grid square: %d m"],
    "M fecha · roda: zoom · botão direito: arrastar · clique: destino · Shift+clique: limpa": ["M cierra · rueda: zoom · botón derecho: arrastrar · clic: destino · Shift+clic: borra", "M closes · wheel: zoom · right button: drag · click: destination · Shift+click: clear"],
    "Posição %s   ·   E %+d m   N %+d m   ·   rumo %03d°": ["Posición %s   ·   E %+d m   N %+d m   ·   rumbo %03d°", "Position %s   ·   E %+d m   N %+d m   ·   heading %03d°"],
    "Destino a %d m (linha reta)": ["Destino a %d m (línea recta)", "Destination %d m away (straight line)"],
    "PUXANDO · %s · tensão %d%% · [J] técnica": ["TIRANDO · %s · tensión %d%% · [J] técnica", "REELING · %s · tension %d%% · [J] technique"],
    "PROCURE UM CARDUME": ["BUSCA UN CARDUMEN", "FIND A SCHOOL OF FISH"],
    "CARDUME PERTO — reduza para pescar": ["CARDUMEN CERCA — reduce para pescar", "SCHOOL NEARBY — slow down to fish"],
    "CARDUME AO ALCANCE — F pescar · B isca · N profundidade": ["CARDUMEN AL ALCANCE — F pescar · B carnada · N profundidad", "SCHOOL IN RANGE — F fish · B bait · N depth"],
}
