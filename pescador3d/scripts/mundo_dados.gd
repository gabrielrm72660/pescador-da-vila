extends RefCounted
## Dados do mundo editável (ilha principal): ruas, casas, postes, props e vegetação.
## É o que o Modo Construtor (F9) edita. Ordem de leitura:
##   1. user://mundo_ilha_principal.json   (o que o jogador salvou no Modo Construtor)
##   2. res://dados/mundo_ilha_principal.json   (um mundo publicado junto com o jogo)
##   3. nada disso: a ilha gera o padrão (o desenho de scripts/layout_principal.gd + vegetação sorteada).
## Posições são em metros, no sistema LOCAL da ilha (mundo menos o centro da ilha). A altura vem sempre do terreno.
##
## Formato de cada lista:
##   ruas:      [{"tipo": "calcada"|"areia", "pts": [[x, z], ...]}]
##   casas:     [{"tipo": "casa"|"armazem"|"mercado"|"capela", "x", "z", "giro", "w", "h", "d", "cor", "porta"}]
##   postes:    [[x, z]]
##   props:     [{"tipo": "rede"|"canoa"|"caixote"|"barril"|"banco", "x", "z", "giro", "var"}]
##   pinheiros, arvores, pedras, moitas: [[x, z, semente]]
##   coqueiros: [[x, z, semente, variante 0..2]]

const VERSAO := 1
const ARQUIVO_USUARIO := "user://mundo_ilha_principal.json"
const ARQUIVO_JOGO := "res://dados/mundo_ilha_principal.json"
const CHAVES := ["ruas", "casas", "postes", "props", "pinheiros", "coqueiros", "arvores", "pedras", "moitas"]

## Onde o Modo Construtor grava. PESCADOR_MUNDO_ARQUIVO troca o caminho (as sondas de teste usam isso).
static func caminho_usuario() -> String:
    var outro: String = OS.get_environment("PESCADOR_MUNDO_ARQUIVO")
    return outro if outro != "" else ARQUIVO_USUARIO

## Devolve o mundo salvo, ou {} se não há (a ilha então gera o padrão).
## PESCADOR_MUNDO_PADRAO=1 ignora qualquer arquivo (comparação com o padrão).
static func carregar() -> Dictionary:
    if OS.get_environment("PESCADOR_MUNDO_PADRAO") == "1":
        return {}
    for caminho in [caminho_usuario(), ARQUIVO_JOGO]:
        var lido: Dictionary = _ler(caminho)
        if not lido.is_empty():
            return lido
    return {}

## Só o mundo publicado junto com o jogo (res://dados), sem olhar o que o jogador salvou. {} se não há.
static func carregar_publicado() -> Dictionary:
    if OS.get_environment("PESCADOR_MUNDO_PADRAO") == "1":
        return {}
    return _ler(ARQUIVO_JOGO)

static func tem_publicado() -> bool:
    return not carregar_publicado().is_empty()

static func _ler(caminho: String) -> Dictionary:
    if not FileAccess.file_exists(caminho):
        return {}
    var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho))
    if typeof(dados) == TYPE_DICTIONARY and int(dados.get("versao", 0)) == VERSAO:
        var limpo: Dictionary = {}
        for chave in CHAVES:
            if dados.has(chave) and typeof(dados[chave]) == TYPE_ARRAY:
                limpo[chave] = dados[chave]
        return limpo
    return {}

static func existe_salvo() -> bool:
    return FileAccess.file_exists(caminho_usuario())

static func salvar(mundo: Dictionary, caminho: String = "") -> bool:
    if caminho == "":
        caminho = caminho_usuario()
    var saida: Dictionary = {"versao": VERSAO}
    for chave in CHAVES:
        if mundo.has(chave):
            saida[chave] = mundo[chave]
    var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
    if arquivo == null:
        return false
    arquivo.store_string(JSON.stringify(saida))
    return true

static func apagar_salvo() -> void:
    var caminho: String = caminho_usuario()
    if FileAccess.file_exists(caminho):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho) if caminho.begins_with("user://") else caminho)

## Cópia independente (desfazer/refazer guardam fotos do mundo).
static func copiar(mundo: Dictionary) -> Dictionary:
    return mundo.duplicate(true)
