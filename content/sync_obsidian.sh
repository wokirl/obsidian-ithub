#!/bin/bash
set -euo pipefail

# Переходим в корень репозитория
cd "$(dirname "$0")"

# Добавляем все изменения в индекс Git
git add -A

# Проверяем, есть ли изменения для коммита
if git diff --cached --quiet; then
    echo "Нет изменений для синхронизации."
    exit 0
fi

# Получаем список изменённых файлов
CHANGED_FILES=$(git diff --cached --name-only)

# Определяем предметы, в которых есть изменения.
# Исключаем служебные файлы и content/src.
SUBJECTS=$(
    printf '%s\n' "$CHANGED_FILES" |
        awk -F/ '
            /^content\/src\// { next }
            /^content\/sync_obsidian\.sh$/ { next }
            /^content\// {
                if (NF >= 3) {
                    print $2
                } else {
                    print "content"
                }
                next
            }
        ' |
        sort -u
)

# Формируем заголовок из названий предметов
if [[ -n "$SUBJECTS" ]]; then
    MAIN_DIR=$(printf '%s\n' "$CHANGED_FILES" |
        awk -F/ '
            /^content\/src\// { next }
            /^content\/sync_obsidian\.sh$/ { next }
            /^content\// {
                if (NF >= 3) print $2
                else print "content"
            }
        ' |
        sort |
        uniq -c |
        sort -k1,1nr -k2,2 |
        head -n 1 |
        awk '{$1=""; sub(/^ /, ""); print}')

    SUBJECT_COUNT=$(printf '%s\n' "$SUBJECTS" | wc -l | tr -d ' ')

    if [[ "$SUBJECT_COUNT" -eq 1 ]]; then
        SUBJECT_TITLE="$SUBJECTS"
    elif [[ "$SUBJECT_COUNT" -eq 2 ]]; then
        SUBJECT_TITLE=$(printf '%s\n' "$SUBJECTS" | paste -sd ' ' - | sed 's/ / и /')
    else
        SUBJECT_TITLE=$(printf '%s\n' "$SUBJECTS" | head -n 3 | paste -sd ', ' -)
        if [[ "$SUBJECT_COUNT" -gt 3 ]]; then
            SUBJECT_TITLE="$SUBJECT_TITLE и ещё $((SUBJECT_COUNT - 3))"
        fi
    fi
else
    MAIN_DIR="quartz-system"
    SUBJECT_TITLE="$MAIN_DIR"
fi

# Текущие дата и время
CURRENT_TIME=$(date "+%d.%m.%y %H:%M")

# День недели на русском
case "$(date "+%u")" in
    1) WEEKDAY="понедельник" ;;
    2) WEEKDAY="вторник" ;;
    3) WEEKDAY="четверг" ;;
    4) WEEKDAY="среда" ;;
    5) WEEKDAY="пятница" ;;
    6) WEEKDAY="суббота" ;;
    7) WEEKDAY="воскресенье" ;;
esac

# Заголовок коммита
COMMIT_MSG="Sync: $SUBJECT_TITLE $CURRENT_TIME $WEEKDAY"

# Формируем подробное описание изменений
DESCRIPTION="Изменения:"

ADDED=$(git diff --cached --name-status | awk '$1 == "A" {print $2}')
MODIFIED=$(git diff --cached --name-status | awk '$1 == "M" {print $2}')
DELETED=$(git diff --cached --name-status | awk '$1 == "D" {print $2}')
RENAMED=$(git diff --cached --name-status | awk '$1 ~ /^R/ {print $2 " -> " $3}')
if [[ -n "$ADDED" ]]; then
    DESCRIPTION+=$'\n\nДобавлены:\n'
    DESCRIPTION+=$(printf '%s\n' "$ADDED" | sed 's/^/- /')
fi

if [[ -n "$MODIFIED" ]]; then
    DESCRIPTION+=$'\n\nИзменены:\n'
    DESCRIPTION+=$(printf '%s\n' "$MODIFIED" | sed 's/^/- /')
fi

if [[ -n "$DELETED" ]]; then
    DESCRIPTION+=$'\n\nУдалены:\n'
    DESCRIPTION+=$(printf '%s\n' "$DELETED" | sed 's/^/- /')
fi

if [[ -n "$RENAMED" ]]; then
    DESCRIPTION+=$'\n\nПереименованы:\n'
    DESCRIPTION+=$(printf '%s\n' "$RENAMED" | sed 's/^/- /')
fi

echo
echo "Заголовок: $COMMIT_MSG"
echo
echo "$DESCRIPTION"
echo

# Создаём коммит и отправляем изменения в master
git commit -m "$COMMIT_MSG" -m "$DESCRIPTION"
git push origin master

