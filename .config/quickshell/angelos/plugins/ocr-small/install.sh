#!/bin/bash
# ocr-small — установка зависимости (идемпотентно). Всё лежит рядом в папке плагина, копирование — только в systemd/niri.
set -euo pipefail
PLUGIN_DIR="$HOME/.config/angelos/plugins/ocr-small"
MODEL="$PLUGIN_DIR/ct2-en-ru"

for cmd in python3 slurp grim wl-copy ollama; do
  command -v "$cmd" >/dev/null || { echo "❌ Нет команды: $cmd"; exit 1; }
done

if [ ! -x "$PLUGIN_DIR/translate-venv/bin/python" ]; then
  if command -v uv >/dev/null; then
    uv venv "$PLUGIN_DIR/translate-venv" --python 3.14
    uv pip install --python "$PLUGIN_DIR/translate-venv/bin/python" ctranslate2 sentencepiece
  else
    python3 -m venv "$PLUGIN_DIR/translate-venv"
    "$PLUGIN_DIR/translate-venv/bin/pip" install ctranslate2 sentencepiece
  fi
else echo "скип: venv перевода (210 МБ)"; fi

if [ ! -f "$MODEL/model.bin" ]; then
  mkdir -p "$MODEL"
  for f in config.json model.bin shared_vocabulary.json source.spm target.spm; do
    curl -fsSL -A Mozilla "https://huggingface.co/jiangzhuo9357/opus-mt-en-ru-ct2/resolve/main/$f" -o "$MODEL/$f"
  done
  echo "f5ae1da30bcb61e877c549be8fb5a434193893eb97509ccd0b954465f9a8f80c  $MODEL/model.bin" | sha256sum -c -
else echo "скип: CT2-модель EN→RU (79 МБ)"; fi

SVC="$HOME/.config/systemd/user/ollama-ocr.service"
if [ ! -f "$SVC" ]; then
  cp "$PLUGIN_DIR/ollama-ocr.service" "$SVC"
  systemctl --user daemon-reload
  systemctl --user enable --now ollama-ocr.service
else echo "скип: ollama-ocr.service (OLLAMA_KEEP_ALIVE=10m)"; fi

if ! grep -q "Mod+Shift+T" "$HOME/.config/niri/cfg/user.kdl" 2>/dev/null; then
  printf '\n// Region OCR: select a rectangle and copy its text using local Ollama GLM-OCR.\nbinds {\n    Mod+Shift+T repeat=false hotkey-overlay-title="OCR GLM: область → буфер" { spawn-sh "exec ~/.config/angelos/plugins/ocr-small/ocr-region-local"; }\n}\n' >> "$HOME/.config/niri/cfg/user.kdl"
  echo "бинда Mod+Shift+T добавлена — перелогинься или systemctl --user reload niri.service"
fi
echo "Готово. Проверь: ollama ps, niri validate, Mod+Shift+T"
