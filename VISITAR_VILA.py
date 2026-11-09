from pathlib import Path
import runpy
import sys
sys.argv.append("--visitar-vila")
runpy.run_path(str(Path(__file__).resolve().parent / "INICIAR.py"), run_name="__main__")
