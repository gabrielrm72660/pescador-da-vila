[app]

# ---- identidade do app ------------------------------------------------------------------------
title = Náufrago
package.name = naufrago
package.domain = br.gabriel
version = 1.0

# ---- arquivos que entram no APK ---------------------------------------------------------------
source.dir = .
source.include_exts = py,png,ttf,txt,ogg,json
source.exclude_dirs = bin, build, .buildozer, __pycache__, venv, .git

# pygame (SDL2) + o Python que o python-for-android compila para o celular
requirements = python3,pygame
p4a.bootstrap = sdl2

# ---- aparência --------------------------------------------------------------------------------
icon.filename = %(source.dir)s/icon.png
presplash.filename = %(source.dir)s/presplash.png
android.presplash_color = #081532
orientation = landscape
fullscreen = 1

# ---- Android ----------------------------------------------------------------------------------
android.api = 33
android.minapi = 24
# só arm64 (praticamente todo celular dos últimos anos); deixa o primeiro build bem mais rápido.
# Para aparelhos antigos de 32 bits use:  android.archs = arm64-v8a, armeabi-v7a
android.archs = arm64-v8a
android.accept_sdk_license = True
# mantém a tela acesa enquanto joga
android.wakelock = True
android.permissions =
android.logcat_filters = *:S python:D

[buildozer]
log_level = 2
warn_on_root = 1
