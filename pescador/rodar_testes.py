"""Roda os testes do Pescador da Vila no Godot sem abrir janela.

Uso:  python rodar_testes.py [caminho_do_godot]
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
    sys.exit("Godot não encontrado. Passe o caminho: python rodar_testes.py C:\\Godot\\Godot_v4.7-stable_win64.exe")


def main():
    godot = achar_godot()
    subprocess.run([godot, "--headless", "--path", PASTA, "--import"], stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
    try:
        r = subprocess.run([godot, "--headless", "--path", PASTA, "--script", "res://testes/rodar_testes.gd"],
                           stdin=subprocess.DEVNULL, timeout=600)
    except subprocess.TimeoutExpired:
        sys.exit("Os testes passaram de 10 minutos e foram interrompidos.")
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
