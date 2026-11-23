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
        peixes.append({"especie": item.especie, "peso": item.peso, "qualidade": item.get("qualidade", "Regular"), "x": item.x, "y": item.y, "rot": item.rot})
    var dados := {
        "versao": VERSAO, "dinheiro": jogo.dinheiro, "hora": jogo.clima.hora, "dias": jogo.clima.dias,
        "objetivo_cumprido": jogo.objetivo_cumprido, "ja_vendeu": jogo.ja_vendeu, "num_peixes": jogo.pesca.num_peixes,
        "luz_ligada": jogo.luz_ligada, "clima_modo": jogo.clima.modo_clima,
        "isca": jogo.pesca.tipo_isca, "profundidade": jogo.pesca.profundidade,
        "iscas_camarao": jogo.pesca.iscas_camarao, "iscas_lula": jogo.pesca.iscas_lula,
        "linha_nivel": jogo.pesca.linha_nivel, "desgaste_linha": jogo.pesca.desgaste_linha, "tecnica": jogo.pesca.tecnica,
        "destino_ativo": jogo.interface.mapa.tem_marcador,
        "destino_x": jogo.interface.mapa.marcador.x, "destino_z": jogo.interface.mapa.marcador.y,
        "contrato_indice": jogo.economia.indice, "contrato_local": jogo.economia.indice_local,
        "contratos_concluidos": jogo.economia.contratos_concluidos,
        "explorados": jogo.explorados.duplicate(),
        "missao": jogo.missoes.indice, "missao_progresso": jogo.missoes.progresso,
        "missao_oferecidas": jogo.missoes.oferecidas.keys(), "missao_fim": jogo.missoes.fim_pendentes.duplicate(),
        "melhorias": jogo.melhorias.nivel.duplicate(),
        "barco": {"x": jogo.barco.global_position.x, "z": jogo.barco.global_position.z, "giro": jogo.barco.rotation.y,
                "combustivel": jogo.barco.combustivel, "saude": jogo.barco.saude, "distancia": jogo.barco.distancia_percorrida},
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
    jogo.clima.dias = maxi(0, int(d.get("dias", 0)))
    jogo.objetivo_cumprido = bool(d.get("objetivo_cumprido", false))
    jogo.ja_vendeu = bool(d.get("ja_vendeu", false))
    jogo.luz_ligada = bool(d.get("luz_ligada", true))
    jogo.clima.definir_clima(int(d.get("clima_modo", 0)))
    jogo.pesca.num_peixes = maxi(0, int(d.get("num_peixes", 0)))
    jogo.pesca.tipo_isca = clampi(int(d.get("isca", 0)), 0, jogo.pesca.ISCAS.size() - 1)
    jogo.pesca.profundidade = clampi(int(d.get("profundidade", 1)), 0, jogo.pesca.PROFUNDIDADES.size() - 1)
    jogo.pesca.iscas_camarao = maxi(0, int(d.get("iscas_camarao", 6)))
    jogo.pesca.iscas_lula = maxi(0, int(d.get("iscas_lula", 4)))
    jogo.pesca.linha_nivel = clampi(int(d.get("linha_nivel", 0)), 0, 3)
    jogo.pesca.desgaste_linha = clampf(float(d.get("desgaste_linha", 0.0)), 0.0, 1.0)
    jogo.pesca.tecnica = clampi(int(d.get("tecnica", 1)), 0, 2)
    jogo.interface.mapa.tem_marcador = bool(d.get("destino_ativo", false))
    jogo.interface.mapa.marcador = Vector2(float(d.get("destino_x", 0.0)), float(d.get("destino_z", 0.0)))
    jogo.economia.indice = maxi(0, int(d.get("contrato_indice", 0)))
    jogo.economia.indice_local = maxi(0, int(d.get("contrato_local", 0)))
    jogo.economia.contratos_concluidos = maxi(0, int(d.get("contratos_concluidos", 0)))
    var descobertas = d.get("explorados", {})
    jogo.explorados = descobertas.duplicate() if typeof(descobertas) == TYPE_DICTIONARY else {}
    if d.has("missao"):
        jogo.missoes.indice = clampi(int(d.missao), 0, jogo.missoes.LISTA.size())
        jogo.missoes.progresso = maxi(0, int(d.get("missao_progresso", 0)))
    else:                                                    # viagem salva antes de existirem as missões novas
        jogo.missoes.indice = 2 if jogo.ja_vendeu else (1 if jogo.objetivo_cumprido else 0)
        jogo.missoes.progresso = 0 if jogo.missoes.indice > 0 else mini(jogo.pesca.num_peixes, 2)
    jogo.missoes.oferecidas.clear()
    for k in d.get("missao_oferecidas", []):
        jogo.missoes.oferecidas[int(k)] = true
    jogo.missoes.fim_pendentes.clear()
    for k in d.get("missao_fim", []):
        jogo.missoes.fim_pendentes.append(int(k))
    var niveis = d.get("melhorias", {})
    if typeof(niveis) == TYPE_DICTIONARY:
        for id in jogo.melhorias.ORDEM:
            jogo.melhorias.nivel[id] = clampi(int(niveis.get(id, 0)), 0, jogo.melhorias.TABELA[id].niveis.size() - 1)
    jogo.melhorias.aplicar(jogo.barco, jogo.porao, jogo.pesca, jogo.interface.hud)
    var b = d.get("barco", {})
    if typeof(b) == TYPE_DICTIONARY:
        var pos := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
        if jogo.bloqueado(pos):
            pos = Vector3.ZERO                                   # arquivo mexido: não deixa o barco em terra
        jogo.barco.global_position = pos
        jogo.barco.rotation = Vector3(0.0, float(b.get("giro", 0.0)), 0.0)
        jogo.barco.combustivel = clampf(float(b.get("combustivel", jogo.barco.tanque)), 0.0, jogo.barco.tanque)
        jogo.barco.saude = clampf(float(b.get("saude", 100.0)), 0.0, 100.0)
        jogo.barco.distancia_percorrida = maxf(0.0, float(b.get("distancia", 0.0)))
        jogo.barco.velocidade = 0.0
    jogo.porao.itens.clear()
    var peixes = d.get("porao", [])
    if typeof(peixes) == TYPE_ARRAY:
        for p in peixes:
            if typeof(p) != TYPE_DICTIONARY or not jogo.porao.FORMAS.has(p.get("especie", "")):
                continue
            var item := {"especie": str(p.especie), "peso": maxf(0.1, float(p.get("peso", 1.0))), "qualidade": String(p.get("qualidade", "Regular")), "x": int(p.get("x", 0)), "y": int(p.get("y", 0)), "rot": posmod(int(p.get("rot", 0)), 4)}
            if jogo.porao.cabe_em(item.especie, item.x, item.y, item.rot):
                jogo.porao.itens.append(item)
            else:
                jogo.porao.guardar(item.especie, item.peso, item.qualidade)          # não cabe onde estava: procura outro lugar
    jogo.porao.mudou.emit()
    jogo.clima.pular_transicoes()
    return true
