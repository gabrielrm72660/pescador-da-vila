"""Gera o mapa do arquipélago (cenas/Mapa.tscn) a partir de dados/mundo.json, sem abrir janela.

Uso:  python gerar_mapa.py [caminho_do_godot]
Também aceita a variável de ambiente GODOT ou um `godot` no PATH.
"""
import os
import shutil
import subprocess
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))


def achar_godot():
    if len(sys.argv) > 1:
        return sys.argv[1]
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    for nome in ("godot", "godot4", "Godot"):
        achado = shutil.which(nome)
        if achado:
            return achado
    sys.exit("Godot não encontrado. Passe o caminho: python gerar_mapa.py C:\\Godot\\Godot_v4.7-stable_win64.exe")


def main():
    godot = achar_godot()
    subprocess.run([godot, "--headless", "--path", PASTA, "--import"], stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
    try:
        r = subprocess.run([godot, "--headless", "--path", PASTA, "--script", "res://ferramentas/gerar_arquipelago.gd"],
                           stdin=subprocess.DEVNULL, timeout=600)
    except subprocess.TimeoutExpired:
        sys.exit("A geração passou de 10 minutos e foi interrompida.")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
