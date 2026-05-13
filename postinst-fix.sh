#!/bin/bash

# Настройки
logfile="$HOME/postinst_fix.log"
target_pattern="systemd-sysusers"
replacement_suffix=".conf || true"

# Очистка лога
: > "$logfile"

# Проверка, существуют ли файлы вообще
shopt -s nullglob
files=(/var/lib/dpkg/info/*.postinst)

if [ ${#files[@]} -eq 0 ]; then
    echo "No .postinst files found." | tee -a "$logfile"
    exit 0
fi

echo "Starting processing at $(date)" >> "$logfile"

for f in "${files[@]}"; do
    # Ищем строки, где есть systemd-sysusers, но НЕТ уже добавленного || true
    # Это предотвращает повторную модификацию одного и того же файла
    mapfile -t matches < <(grep "$target_pattern" "$f" | grep -v "|| true")

    if [ ${#matches[@]} -gt 0 ]; then
        echo "=== $f ===" >> "$logfile"
        echo "--- CHANGING ---" >> "$logfile"
        
        for line in "${matches[@]}"; do
            echo "Old: $line" >> "$logfile"
            echo "New: $(echo "$line" | sed "s/\.conf$/$replacement_suffix/")" >> "$logfile"
        done

        # Выполняем замену только в тех строках, где есть паттерн
        sudo sed -i "/$target_pattern/s/\.conf$/$replacement_suffix/" "$f";
        
        echo "Status: Modified" >> "$logfile"
        echo "" >> "$logfile"
    fi
done

echo "Done. Check $logfile for details."
