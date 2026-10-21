#!/usr/bin/env bash
# Executa toda a validação headless do projeto.
# Uso: GODOT=/caminho/para/godot tools/run_tests.sh
set -u
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

step() { printf '\n\033[1m### %s\033[0m\n' "$1"; }

step "Importação / cache de classes"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || { echo "falha na importação"; fail=1; }

step "Testes unitários"
"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee /tmp/deepforge_unit.log
[ "${PIPESTATUS[0]}" -eq 0 ] || fail=1

step "Teste de integração (cena + toque)"
"$GODOT" --headless --path . --fixed-fps 60 res://tests/scene_test.tscn 2>&1 | tee /tmp/deepforge_scene.log
[ "${PIPESTATUS[0]}" -eq 0 ] || fail=1

step "Sessão automática (30 s simulados)"
"$GODOT" --headless --path . --fixed-fps 60 -- --seed=42 --autotest=30 2>&1 | tee /tmp/deepforge_auto.log
[ "${PIPESTATUS[0]}" -eq 0 ] || fail=1

step "Erros de script no log"
if grep -hE "SCRIPT ERROR|Parse Error|Compile Error" /tmp/deepforge_unit.log /tmp/deepforge_scene.log /tmp/deepforge_auto.log; then
	echo "erros encontrados"; fail=1
else
	echo "nenhum"
fi

echo
[ "$fail" -eq 0 ] && echo "TUDO PASSOU" || echo "HOUVE FALHAS"
exit "$fail"
