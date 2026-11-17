extends RefCounted
## Guarda e recupera a viagem num arquivo (user://pescador_viagem.json): dinheiro, hora, missões,
## melhorias, onde o barco está, o diesel e os peixes no porão. O jogo salva sozinho (ver scripts/jogo.gd).

const ARQUIVO := "user://pescador_viagem.json"
const VERSAO := 1

static func existe() -> bool:
    return FileAccess.file_exists(ARQUIVO)

static func apagar() -> void:
    if existe():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))

static func salvar(jogo: Node) -> bool:
    var peixes: Array = []
    for item in jogo.porao.itens:
        peixes.append({"especie": item.especie, "peso": item.peso, "x": item.x, "y": item.y, "rot": item.rot})
    var dados := {
        "versao": VERSAO, "dinheiro": jogo.dinheiro, "hora": jogo.clima.hora,
        "objetivo_cumprido": jogo.objetivo_cumprido, "ja_vendeu": jogo.ja_vendeu, "num_peixes": jogo.pesca.num_peixes,
        "missao": jogo.missoes.indice, "missao_progresso": jogo.missoes.progresso,
        "melhorias": jogo.melhorias.nivel.duplicate(),
        "barco": {"x": jogo.barco.global_position.x, "z": jogo.barco.global_position.z, "giro": jogo.barco.rotation.y,
                "combustivel": jogo.barco.combustivel, "distancia": jogo.barco.distancia_percorrida},
        "porao": peixes,
    }
    var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(dados, "  "))
    return true

## Lê o arquivo e põe o jogo como estava. Falso se não há arquivo ou se ele não serve.
static func carregar(jogo: Node) -> bool:
    if not existe():
        return false
    var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
    if typeof(lido) != TYPE_DICTIONARY or int(lido.get("versao", 0)) != VERSAO:
        return false
    var d: Dictionary = lido
    jogo.dinheiro = maxi(0, int(d.get("dinheiro", jogo.DINHEIRO_INICIAL)))
    jogo.clima.hora = fposmod(float(d.get("hora", jogo.clima.HORA_INICIAL)), 24.0)
    jogo.objetivo_cumprido = bool(d.get("objetivo_cumprido", false))
    jogo.ja_vendeu = bool(d.get("ja_vendeu", false))
    jogo.pesca.num_peixes = maxi(0, int(d.get("num_peixes", 0)))
    if d.has("missao"):
        jogo.missoes.indice = clampi(int(d.missao), 0, jogo.missoes.LISTA.size())
        jogo.missoes.progresso = maxi(0, int(d.get("missao_progresso", 0)))
    else:                                                    # viagem salva antes de existirem as missões novas
        jogo.missoes.indice = 2 if jogo.ja_vendeu else (1 if jogo.objetivo_cumprido else 0)
        jogo.missoes.progresso = 0 if jogo.missoes.indice > 0 else mini(jogo.pesca.num_peixes, 2)
    var niveis = d.get("melhorias", {})
    if typeof(niveis) == TYPE_DICTIONARY:
        for id in jogo.melhorias.ORDEM:
            jogo.melhorias.nivel[id] = clampi(int(niveis.get(id, 0)), 0, jogo.melhorias.TABELA[id].niveis.size() - 1)
    jogo.melhorias.aplicar(jogo.barco, jogo.porao, jogo.pesca)
    var b = d.get("barco", {})
    if typeof(b) == TYPE_DICTIONARY:
        var pos := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
        if jogo.bloqueado(pos):
            pos = Vector3.ZERO                                   # arquivo mexido: não deixa o barco em terra
        jogo.barco.global_position = pos
        jogo.barco.rotation = Vector3(0.0, float(b.get("giro", 0.0)), 0.0)
        jogo.barco.combustivel = clampf(float(b.get("combustivel", jogo.barco.tanque)), 0.0, jogo.barco.tanque)
        jogo.barco.distancia_percorrida = maxf(0.0, float(b.get("distancia", 0.0)))
        jogo.barco.velocidade = 0.0
    jogo.porao.itens.clear()
    var peixes = d.get("porao", [])
    if typeof(peixes) == TYPE_ARRAY:
        for p in peixes:
            if typeof(p) != TYPE_DICTIONARY or not jogo.porao.FORMAS.has(p.get("especie", "")):
                continue
            var item := {"especie": str(p.especie), "peso": maxf(0.1, float(p.get("peso", 1.0))), "x": int(p.get("x", 0)), "y": int(p.get("y", 0)), "rot": posmod(int(p.get("rot", 0)), 4)}
            if jogo.porao.cabe_em(item.especie, item.x, item.y, item.rot):
                jogo.porao.itens.append(item)
            else:
                jogo.porao.guardar(item.especie, item.peso)          # não cabe onde estava: procura outro lugar
    jogo.porao.mudou.emit()
    jogo.clima.atualizar()
    return true
