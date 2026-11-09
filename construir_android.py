#!/usr/bin/env python3
"""Gera o APK do Náufrago (Android) com o Buildozer.

O Buildozer só roda em Linux. No Windows use o Ubuntu do WSL2 (veja o LEIAME.md, seção "APK"):
abra o Ubuntu, vá até esta pasta e rode:

    python3 construir_android.py

O que o script faz, sozinho:
  1. instala os pacotes do Ubuntu que o Buildozer precisa (pede a senha do sudo);
  2. cria um ambiente Python isolado com as versões que funcionam (Cython<3, setuptools<71);
  3. copia o projeto para o disco do Linux (muito mais rápido que /mnt/c) e compila;
  4. devolve o APK na pasta "apk" ao lado deste script.

A PRIMEIRA compilação baixa o SDK e o NDK do Android (alguns GB) e leva de 20 a 40 minutos.
As seguintes levam poucos minutos, porque o cache fica guardado em ~/naufrago_apk.

Opções:
    --pular-apt     não mexe nos pacotes do sistema (já instalados)
    --so-preparar   faz tudo menos a compilação (para conferir o ambiente)
    --limpar        apaga a compilação anterior antes de compilar (use se algo ficar estranho)
"""
import glob
import os
import platform
import shutil
import subprocess
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))
JOGO = os.path.join(PASTA, "jogo")
SAIDA = os.path.join(PASTA, "apk")
TRABALHO = os.path.expanduser("~/naufrago_apk")                 # cópia de trabalho (disco Linux)
VENV = os.path.expanduser("~/.venv-naufrago-apk")

PACOTES_APT = [
    "git", "zip", "unzip", "openjdk-17-jdk", "python3-venv", "python3-pip", "build-essential",
    "autoconf", "automake", "libtool", "pkg-config", "zlib1g-dev", "libncurses-dev", "cmake",
    "libffi-dev", "libssl-dev", "ccache",
]
PACOTES_PIP = ["buildozer", "Cython<3.0", "setuptools<71", "wheel", "virtualenv"]
IGNORAR = shutil.ignore_patterns("bin", "build", ".buildozer", "__pycache__", "*.pyc", "venv", ".git")


def sh(cmd, **kw):
    print("\n+ " + " ".join(cmd), flush=True)
    return subprocess.check_call(cmd, **kw)


def avisar_windows():
    print(__doc__.split("O que o script faz")[0])
    print("Você está no Windows. Passos rápidos (PowerShell, uma vez só):")
    print("    wsl --install -d Ubuntu          (reinicie o PC se pedir)")
    print("Depois abra o app 'Ubuntu' e rode:")
    print('    cd "/mnt/c/CAMINHO/ATÉ/naufrago_mobile"')
    print("    python3 construir_android.py")
    sys.exit(1)


def instalar_pacotes():
    faltando = [p for p in PACOTES_APT
                if subprocess.call(["dpkg", "-s", p], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0]
    if not faltando:
        print("Pacotes do sistema: ok.")
        return
    sudo = [] if os.geteuid() == 0 else ["sudo"]
    print("Instalando pacotes do sistema (pode pedir a senha do Ubuntu): " + " ".join(faltando))
    sh(sudo + ["apt-get", "update"])
    sh(sudo + ["apt-get", "install", "-y"] + faltando)


def achar_python():
    for nome in ("python3.11", "python3.10", "python3.12", "python3.9", "python3"):
        exe = shutil.which(nome)
        if exe:
            versao = subprocess.check_output([exe, "-c", "import sys; print('%d.%d' % sys.version_info[:2])"],
                                             text=True).strip()
            if tuple(int(x) for x in versao.split(".")) >= (3, 13):
                print("Aviso: Python %s é novo demais para o Buildozer; se der erro, instale o 3.11 "
                      "(sudo apt install python3.11 python3.11-venv, ou 'uv python install 3.11')." % versao)
            print("Python do ambiente: %s (%s)" % (exe, versao))
            return exe
    sys.exit("Python 3 não encontrado. Instale com: sudo apt install python3 python3-venv")


def preparar_ambiente():
    py_bin = os.path.join(VENV, "bin", "python")
    if not os.path.exists(py_bin):
        sh([achar_python(), "-m", "venv", VENV])
    sh([py_bin, "-m", "pip", "install", "--upgrade", "pip"])
    sh([py_bin, "-m", "pip", "install", "--upgrade"] + PACOTES_PIP)
    return py_bin


def copiar_projeto():
    """Copia jogo/ para o disco do Linux, sem apagar o cache do Buildozer (.buildozer)."""
    shutil.copytree(JOGO, TRABALHO, dirs_exist_ok=True, ignore=IGNORAR)
    if os.geteuid() == 0:                           # como root o Buildozer pergunta "continuar?"
        spec = os.path.join(TRABALHO, "buildozer.spec")
        with open(spec, encoding="utf-8") as f:
            txt = f.read().replace("warn_on_root = 1", "warn_on_root = 0")
        with open(spec, "w", encoding="utf-8") as f:
            f.write(txt)
    print("Projeto copiado para %s" % TRABALHO)


def main():
    if sys.platform == "win32":
        avisar_windows()
    if not sys.platform.startswith("linux"):
        sys.exit("O Buildozer só funciona em Linux (no Windows, use o Ubuntu do WSL2).")
    if not os.path.isfile(os.path.join(JOGO, "main.py")):
        sys.exit("Não achei jogo/main.py. Rode este script de dentro da pasta naufrago_mobile.")
    args = sys.argv[1:]

    if "--pular-apt" not in args:
        instalar_pacotes()
    preparar_ambiente()
    copiar_projeto()
    if "--so-preparar" in args:
        print("\nAmbiente pronto (nada foi compilado).")
        return

    env = dict(os.environ)
    # o Buildozer procura 'cython' no PATH, então o bin do ambiente isolado vai na frente
    env["PATH"] = os.path.join(VENV, "bin") + os.pathsep + env.get("PATH", "")
    env["VIRTUAL_ENV"] = VENV                       # equivale a "ativar" o ambiente (o Buildozer olha isso)
    jdk = "/usr/lib/jvm/java-17-openjdk-amd64"
    if os.path.isdir(jdk):
        env["JAVA_HOME"] = jdk                      # o Gradle do Android não gosta de outros JDKs
        env["PATH"] = os.path.join(jdk, "bin") + os.pathsep + env["PATH"]
    buildozer = os.path.join(VENV, "bin", "buildozer")
    if "--limpar" in args:
        sh([buildozer, "android", "clean"], cwd=TRABALHO, env=env)

    print("\nCompilando. A primeira vez baixa o SDK/NDK do Android e demora; é normal.")
    try:
        sh([buildozer, "-v", "android", "debug"], cwd=TRABALHO, env=env)
    except subprocess.CalledProcessError:
        print("\nA compilação falhou. Leia as últimas linhas acima (procure por 'Error' ou 'FAILED').")
        print("Se o erro for estranho, tente:  python3 construir_android.py --limpar")
        sys.exit(1)

    apks = sorted(glob.glob(os.path.join(TRABALHO, "bin", "*.apk")), key=os.path.getmtime)
    if not apks:
        sys.exit("O Buildozer terminou, mas não achei nenhum .apk em %s/bin" % TRABALHO)
    os.makedirs(SAIDA, exist_ok=True)
    destino = os.path.join(SAIDA, os.path.basename(apks[-1]))
    shutil.copy2(apks[-1], destino)

    print("\n" + "=" * 66)
    print(" APK pronto: %s" % destino)
    if "microsoft" in platform.release().lower():
        try:
            win = subprocess.check_output(["wslpath", "-w", SAIDA], text=True).strip()
            print(" No Windows, a pasta é:  %s" % win)
        except (OSError, subprocess.CalledProcessError):
            pass
    print(" Passe o arquivo para o celular (cabo USB, Drive, WhatsApp...) e abra-o.")
    print(" O Android vai pedir para permitir 'instalar apps desconhecidos' desta origem.")
    print(" Com o celular em modo depuração USB e o adb no PC:  adb install -r <arquivo.apk>")
    print("=" * 66)


if __name__ == "__main__":
    main()
