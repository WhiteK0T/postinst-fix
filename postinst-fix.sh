#!/usr/bin/env bash
set -euo pipefail

# ================= НАСТРОЙКИ =================
LOGFILE="$HOME/postinst_fix.log"
TARGET_PATTERN="systemd-sysusers"
SUFFIX=" || true"
DRY_RUN=false
BACKUP_DIR="/tmp/postinst_backups_$(date +%Y%m%d_%H%M%S)"

# ================= ПАРСИНГ АРГУМЕНТОВ =================
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n) DRY_RUN=true; shift ;;
        *) echo "Использование: $0 [--dry-run]"; exit 1 ;;
    esac
done

# ================= ПРОВЕРКА ПРАВ =================
if [[ $EUID -ne 0 ]]; then
    echo "❌ Ошибка: скрипт должен быть запущен от root (или через sudo)." >&2
    exit 1
fi

# ================= ИНИЦИАЛИЗАЦИЯ =================
: > "$LOGFILE"
exec >> "$LOGFILE" 2>&1

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "🚀 Запуск обработки..."

shopt -s nullglob
files=(/var/lib/dpkg/info/*.postinst)

if [[ ${#files[@]} -eq 0 ]]; then
    log "⚠️ Файлы .postinst не найдены."
    exit 0
fi

modified_count=0

# ================= ОБРАБОТКА ФАЙЛОВ =================
for f in "${files[@]}"; do
    # Ищем строки с паттерном, которые ещё не содержат " || true"
    # || true предотвращает падение скрипта при отсутствии совпадений (set -e)
    mapfile -t matches < <(grep -F "$TARGET_PATTERN" "$f" 2>/dev/null | grep -v "|| true" || true)

    [[ ${#matches[@]} -eq 0 ]] && continue

    log "📄 === $f ==="
    log "📝 --- ИЗМЕНЕНИЯ ---"

    for line in "${matches[@]}"; do
        if [[ "$line" =~ \.conf$ ]]; then
            log "  ➜ Старая: $line"
            log "  ➜ Новая:  ${line}${SUFFIX}"
        else
            log "  ⏭ Пропущена (не заканчивается на .conf): $line"
        fi
    done

    if [[ "$DRY_RUN" == true ]]; then
        log "🧪 Статус: РЕЖИМ ПРОБЕГА (файлы не изменены)"
    else
        # Создаём директорию для бэкапов один раз
        mkdir -p "$BACKUP_DIR"
        cp -p "$f" "$BACKUP_DIR/$(basename "$f")"

        # Применяем изменение только к строкам, содержащим паттерн и заканчивающимся на .conf
        if sed -i "/${TARGET_PATTERN}/ s/\.conf$/\.conf${SUFFIX}/" "$f"; then
            log "✅ Статус: Успешно изменен (бэкап: $BACKUP_DIR/$(basename "$f"))"
            ((modified_count++)) || true
        else
            log "❌ Статус: ОШИБКА при изменении"
        fi
    fi
    log ""
done

log "🏁 Готово. Изменено файлов: $modified_count. Подробности в $LOGFILE"
