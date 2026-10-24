#!/usr/bin/env bash
set -eu

# Переходим в корень репозитория
cd "$(dirname "$0")"

# Добавляем все изменения в индекс
git add -A

# Не создаём пустой коммит
if git diff --cached --quiet; then
    echo "Нет изменений для синхронизации."
    exit 0
fi

# Получаем изменения с учётом переименований
CHANGES=$(git diff --cached --name-status --find-renames)

# Извлекаем предметы, в которых есть изменения
SUBJECTS=$(
    printf '%s\n' "$CHANGES" |
        awk -F '\t' '
            {
                path = ($1 ~ /^R/ ? $3 : $2)

                if (path !~ /^content\//) next
                if (path ~ /^content\/src\//) next
                if (path == "content/sync_obsidian.sh") next

                n = split(path, parts, "/")

                if (n >= 3) print parts[2]
                else print "content"
            }
        ' |
        sort -u
)

# Собираем список предметов в массив
SUBJECT_ARRAY=()
while IFS= read -r subject; do
    if [[ -n "$subject" ]]; then
        SUBJECT_ARRAY+=("$subject")
    fi
done <<< "$SUBJECTS"

SUBJECT_COUNT=${#SUBJECT_ARRAY[@]}

# Формируем заголовок из всех изменённых предметов
if [[ "$SUBJECT_COUNT" -eq 0 ]]; then
    SUBJECT_TITLE="quartz-system"
elif [[ "$SUBJECT_COUNT" -eq 1 ]]; then
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]}"
elif [[ "$SUBJECT_COUNT" -eq 2 ]]; then
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]} и ${SUBJECT_ARRAY[1]}"
else
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]}, ${SUBJECT_ARRAY[1]}, ${SUBJECT_ARRAY[2]}"
    if [[ "$SUBJECT_COUNT" -gt 3 ]]; then
        SUBJECT_TITLE="$SUBJECT_TITLE и ещё $((SUBJECT_COUNT - 3))"
    fi
fi

# Дата, время и день недели
CURRENT_TIME=$(date "+%d.%m.%y %H:%M")

case "$(date "+%u")" in
    1) WEEKDAY="понедельник" ;;
    2) WEEKDAY="вторник" ;;
    3) WEEKDAY="среда" ;;
    4) WEEKDAY="четверг" ;;
    5) WEEKDAY="пятница" ;;
    6) WEEKDAY="суббота" ;;
    7) WEEKDAY="воскресенье" ;;
esac

COMMIT_MSG="Sync: $SUBJECT_TITLE $CURRENT_TIME $WEEKDAY"

# Группируем изменения по директориям любой глубины
DESCRIPTION=$(
    printf '%s\n' "$CHANGES" |
        awk -F '\t' '
            function group_for(path, parts, n, i, result) {
                n = split(path, parts, "/")

                if (parts[1] == "content") {
                    if (n == 2) return "content (корень)"

                    result = parts[2]

                    for (i = 3; i < n; i++) {
                        result = result "/" parts[i]
                    }

                    return result
                }

                if (n == 1) return "служебные файлы"

                result = parts[1]
                for (i = 2; i < n; i++) {
                    result = result "/" parts[i]
                }

                return result
            }

            {
                status = $1
                old_path = $2
                path = ($1 ~ /^R/ ? $3 : $2)

                if (status == "A") action = "Добавлен"
                else if (status == "M") action = "Изменён"
                else if (status == "D") action = "Удалён"
                else if (status ~ /^R/) action = "Переименован"
                else if (status ~ /^C/) action = "Скопирован"
                else action = "Изменён"

                group = group_for(path)

                if (status ~ /^R/) {
                    file = old_path " → " path
                } else {
                    file = path
                }

                print group "\t" action "\t" file
            }
        ' |
        sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3 |
        awk -F '\t' '
            BEGIN {
                print "Изменения по темам:"
            }

            $1 != previous_group {
                previous_group = $1
                print ""
                print previous_group ":"
            }

            {
                print "  - " $2 ": " $3
            }
        '
)

# Статистика по типам изменений
ADDED=$(printf '%s\n' "$CHANGES" | awk -F '\t' '$1 == "A" {n++} END {print n+0}')
MODIFIED=$(printf '%s\n' "$CHANGES" | awk -F '\t' '$1 == "M" {n++} END {print n+0}')
DELETED=$(printf '%s\n' "$CHANGES" | awk -F '\t' '$1 == "D" {n++} END {print n+0}')
RENAMED=$(printf '%s\n' "$CHANGES" | awk -F '\t' '$1 ~ /^R/ {n++} END {print n+0}')

DESCRIPTION="$DESCRIPTION

Итого: добавлено $ADDED, изменено $MODIFIED, удалено $DELETED, переименовано $RENAMED."

# Показываем итог перед коммитом
echo
echo "Заголовок: $COMMIT_MSG"
echo
echo "$DESCRIPTION"
echo

# Создаём коммит и отправляем изменения
git commit -m "$COMMIT_MSG" -m "$DESCRIPTION"
git push origin master

