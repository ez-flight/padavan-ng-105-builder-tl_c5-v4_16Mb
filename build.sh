#!/usr/bin/env bash
# ============================================================
# Локальная сборка прошивки Padavan для TP-Link Archer C5 V4 (16M)
#
# Что делает скрипт:
#   1. Проверяет наличие необходимых команд.
#   2. Читает variables (репозиторий, ветка, закреплённый коммит, toolchain).
#   3. Проверяет build.config (профиль должен быть TL_C5-V4_16M).
#   4. Клонирует/обновляет padavan-ng и переключается на закреплённый коммит.
#   5. Проверяет КАЖДЫЙ патч через git apply --check, затем применяет.
#   6. Копирует файлы-оверлеи (nfqws2, LED-заголовок).
#   7. Скачивает и распаковывает toolchain (если ещё не собран).
#   8. Запускает сборку прошивки.
#
# Запуск (рекомендуется в tmux, см. BUILD-INSTRUCTION-RU.md):
#   ./build.sh
# ============================================================
set -euo pipefail

BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BUILDER_DIR"

log()  { printf '\n[build] %s\n' "$*"; }
die()  { printf '\n[build][ОШИБКА] %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------
# 1. Проверка необходимых команд
# ------------------------------------------------------------
log "Проверка необходимых команд"
for cmd in git wget tar make gcc patch awk sed grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Не найдена обязательная команда: $cmd"
done
command -v tmux >/dev/null 2>&1 || log "Предупреждение: tmux не найден — для длительной сборки лучше запускать ./build.sh внутри tmux (см. BUILD-INSTRUCTION-RU.md)"

# ------------------------------------------------------------
# 2. Чтение variables
# ------------------------------------------------------------
[[ -f variables ]] || die "Файл variables не найден в $BUILDER_DIR"
# shellcheck disable=SC1090
source <(sed 's/\r$//' variables)

: "${PADAVAN_REPO:?В variables не задан PADAVAN_REPO}"
: "${PADAVAN_BRANCH:?В variables не задан PADAVAN_BRANCH}"
: "${PADAVAN_COMMIT:?В variables не задан PADAVAN_COMMIT}"
: "${PADAVAN_TOOLCHAIN_URL:?В variables не задан PADAVAN_TOOLCHAIN_URL}"

[[ "$PADAVAN_COMMIT" != "HEAD" ]] || die "PADAVAN_COMMIT=HEAD в variables — зафиксируйте конкретный коммит (git ls-remote $PADAVAN_REPO HEAD) для воспроизводимости"
log "Источники: $PADAVAN_REPO (ветка $PADAVAN_BRANCH, коммит $PADAVAN_COMMIT)"

# ------------------------------------------------------------
# 3. Проверка build.config
# ------------------------------------------------------------
[[ -f build.config ]] || die "Файл build.config не найден в $BUILDER_DIR"
tr -d '\r' < build.config | grep -q 'CONFIG_FIRMWARE_PRODUCT_ID="TL_C5-V4_16M"' \
    || die "В build.config профиль не TL_C5-V4_16M — сборка остановлена"
tr -d '\r' < build.config | grep -q '^CONFIG_FIRMWARE_INCLUDE_ZAPRET2=y' \
    || die "В build.config не включён CONFIG_FIRMWARE_INCLUDE_ZAPRET2 (nfqws2/Zapret2)"
tr -d '\r' < build.config | grep -q '^CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG=y' \
    || die "В build.config не включён CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG"
log "build.config проверен: профиль TL_C5-V4_16M, ZAPRET2=y, AMNEZIAWG=y"

# ------------------------------------------------------------
# 4. Получение исходников padavan-ng (закреплённый коммит)
# ------------------------------------------------------------
if [[ ! -d padavan-ng/.git ]]; then
    log "Клонирование $PADAVAN_REPO (коммит $PADAVAN_COMMIT)"
    rm -rf padavan-ng
    mkdir padavan-ng
    git -C padavan-ng init -q
    git -C padavan-ng remote add origin "$PADAVAN_REPO"
    git -C padavan-ng fetch --depth 1 origin "$PADAVAN_BRANCH" \
        || die "Не удалось клонировать ветку $PADAVAN_BRANCH из $PADAVAN_REPO"
    git -C padavan-ng checkout -q FETCH_HEAD \
        || die "Не удалось переключиться на коммит $PADAVAN_COMMIT"
elif [[ "$(git -C padavan-ng rev-parse HEAD 2>/dev/null)" == "$PADAVAN_COMMIT" ]]; then
    log "Клон padavan-ng уже на коммите $PADAVAN_COMMIT, повторное скачивание не требуется"
else
    log "Обновление клона padavan-ng до коммита $PADAVAN_COMMIT"
    git -C padavan-ng fetch --depth 1 origin "$PADAVAN_COMMIT" \
        || die "Не удалось получить коммит $PADAVAN_COMMIT из $PADAVAN_REPO"
    git -C padavan-ng checkout -q FETCH_HEAD \
        || die "Не удалось переключиться на коммит $PADAVAN_COMMIT"
fi

[[ "$(git -C padavan-ng rev-parse HEAD)" == "$PADAVAN_COMMIT" ]] \
    || die "HEAD клона ($(git -C padavan-ng rev-parse HEAD)) не совпадает с PADAVAN_COMMIT=$PADAVAN_COMMIT"
log "Исходники на коммите $(git -C padavan-ng rev-parse --short HEAD)"

# ------------------------------------------------------------
# 5. Проверка и применение патчей
# ------------------------------------------------------------
shopt -s nullglob
PATCH_FILES=( patches/*.patch patches/*.diff )
shopt -u nullglob
# Возврат tracked-файлов к HEAD и удаление заголовка, добавляемого патчем,
# чтобы повторный запуск build.sh не ломался о уже применённые патчи.
git -C padavan-ng checkout -q HEAD -- . || die "Не удалось сбросить дерево исходников к HEAD"
rm -f padavan-ng/trunk/user/rc/my_control_led.h
if (( ${#PATCH_FILES[@]} > 0 )); then
    log "Проверка патчей (git apply --check), штук: ${#PATCH_FILES[@]}"
    for p in "${PATCH_FILES[@]}"; do
        git -C padavan-ng apply --check "$BUILDER_DIR/$p" \
            || die "Патч НЕ применяется к коммиту $PADAVAN_COMMIT: $p
Скорректируйте патч или обновите PADAVAN_COMMIT в variables (и пересоздайте патч)."
    done
    log "Все патчи прошли проверку, применяю"
    for p in "${PATCH_FILES[@]}"; do
        git -C padavan-ng apply "$BUILDER_DIR/$p" \
            || die "Ошибка применения патча: $p"
        log "Применён: $p"
    done
else
    log "Каталог patches/ пуст — патчи не применяются"
fi

# ------------------------------------------------------------
# 6. Toolchain (скачивание готового архива, если sysroot отсутствует)
# ------------------------------------------------------------
if ! compgen -G "padavan-ng/toolchain/out/mipsel-linux-uclibc/sysroot/lib/libuClibc-*.so" >/dev/null; then
    log "Скачивание toolchain: $PADAVAN_TOOLCHAIN_URL"
    ARCH_FLAG=""
    case "$PADAVAN_TOOLCHAIN_URL" in
        *.tzst|*.tar.zst) ARCH_FLAG="--zstd" ;;
        *.txz|*.tar.xz)   ARCH_FLAG="--xz" ;;
    esac
    wget -qO- "$PADAVAN_TOOLCHAIN_URL" | tar -C padavan-ng $ARCH_FLAG -xf - \
        || die "Не удалось скачать/распаковать toolchain"
    compgen -G "padavan-ng/toolchain/out/mipsel-linux-uclibc/sysroot/lib/libuClibc-*.so" >/dev/null \
        || die "После распаковки toolchain/sysroot не найден — архив повреждён?"
else
    log "Toolchain уже присутствует, скачивание пропущено"
fi

# ------------------------------------------------------------
# 7. Сборка прошивки
# ------------------------------------------------------------
log "Установка build.config в trunk/.config"
cp -f build.config padavan-ng/trunk/.config
sed -i 's/\r$//g' padavan-ng/trunk/.config

pushd padavan-ng/trunk >/dev/null
log "Очистка дерева (clear_tree.sh)"
./clear_tree.sh >/dev/null 2>&1 || true
log "Запуск build_firmware.sh (длительная операция)"
./build_firmware.sh
popd >/dev/null

# ------------------------------------------------------------
# 8. Поиск готового образа
# ------------------------------------------------------------
FW_IMAGE="$(find padavan-ng/trunk/images -maxdepth 1 -type f \( -name '*.trx' -o -name '*.bin' \) -printf '%T@\t%p\n' 2>/dev/null | sort -n | tail -1 | cut -f2 || true)"
[[ -n "$FW_IMAGE" ]] || die "Сборка завершилась, но образ прошивки не найден в padavan-ng/trunk/images/"
log "Готовый образ прошивки: $FW_IMAGE"
ls -lh "$FW_IMAGE"

log "Сборка успешно завершена"
