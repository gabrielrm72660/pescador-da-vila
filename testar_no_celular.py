#!/usr/bin/env python3
"""Testa o Náufrago no celular, pelo navegador, sem instalar nada nele.

O PC vira um servidor na sua rede Wi-Fi; o celular (na MESMA rede) abre o endereço que este
script mostra. O jogo roda dentro do navegador do celular via pygbag (Python -> WebAssembly),
então serve para sentir o toque, a escala de tela e o desempenho. O APK de verdade (mais rápido)
sai do construir_android.py.

Uso:
    python testar_no_celular.py              # abre o servidor e mostra o endereço para o celular
    python testar_no_celular.py --publicar   # só gera a versão web em jogo/build/web (para hospedar)

Na primeira vez o pygbag baixa o "runtime" da internet (uns 30 MB). O celular também baixa na
primeira abertura, então ele precisa de internet; depois fica no cache do navegador.
"""
import importlib.util
import os
import socket
import subprocess
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))
JOGO = os.path.join(PASTA, "jogo")
PORTA = 8000
# "1" = o navegador pede um toque na tela antes de iniciar. É o que libera o SOM: navegadores
# bloqueiam áudio até a primeira interação. Com "0" o jogo abre direto, mas pode ficar mudo.
UME_BLOCK = "1"


def ip_da_rede():
    """IP do PC na rede local (o que o celular precisa digitar)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))        # não envia nada; só descobre a rota de saída
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def garantir_pygbag():
    if importlib.util.find_spec("pygbag") is None:
        print("Instalando o pygbag (só na primeira vez)...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pygbag"])


def main():
    if not os.path.isfile(os.path.join(JOGO, "main.py")):
        sys.exit("Não achei jogo/main.py. Rode este script de dentro da pasta naufrago_mobile.")
    garantir_pygbag()
    base = [sys.executable, "-m", "pygbag"]

    if "--publicar" in sys.argv[1:]:
        subprocess.check_call(base + ["--build", JOGO])
        print("\nPronto. Os arquivos da versão web estão em:\n  %s" % os.path.join(JOGO, "build", "web"))
        print("Envie o CONTEÚDO dessa pasta para qualquer hospedagem de site estático (itch.io, Vercel...).")
        return

    ip = ip_da_rede()
    print("=" * 66)
    print(" No celular (na mesma rede Wi-Fi), abra o navegador e digite:")
    print()
    print("     http://%s:%d" % (ip, PORTA))
    print()
    print(" No próprio PC:  http://localhost:%d" % PORTA)
    print(" Se o Windows perguntar sobre o firewall, permita em 'redes privadas'.")
    print(" Deixe esta janela aberta; Ctrl+C encerra o servidor.")
    print(" Dica: no jogo, toque no painel de dia/hora (canto superior direito) para ver os fps.")
    print("=" * 66)
    subprocess.call(base + ["--bind", "0.0.0.0", "--port", str(PORTA), "--ume_block", UME_BLOCK, JOGO])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
