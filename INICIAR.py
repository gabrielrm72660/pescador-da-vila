from pathlib import Path
import runpy
import sys
pasta = Path(__file__).resolve().parent / "jogo"
sys.path.insert(0, str(pasta))
try:
    runpy.run_path(str(pasta / "main.py"), run_name="__main__")
except ImportError as erro:
    print("Dependência ausente:", erro)
    print("Instale com: python -m pip install pygame-ce")
    input("Pressione ENTER para fechar...")
