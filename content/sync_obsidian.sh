#!/usr/bin/env bash
set -eu

# Переходим в корень репозитория
cd "$(dirname "$0")"

# Добавляем все изменения в индекс Git
git add -A

# Проверяем, есть ли изменения для коммита
if git diff --cached --quiet; then
    echo "Нет изменений для синхронизации."
    exit 0
fi

# Получаем список изменений с учётом переименований
CHANGES=$(git diff --cached --name-status --find-renames)

# Определяем изменённые учебные предметы
SUBJECTS=$(
    printf '%s\n' "$CHANGES" |
        awk -F '\t' '
            {
                path = ($1 ~ /^[RC]/ ? $3 : $2)

                if (path ~ /^\.obsidian\//) next
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

SUBJECT_ARRAY=()
while IFS= read -r subject; do
    if [[ -n "$subject" ]]; then
        SUBJECT_ARRAY+=("$subject")
    fi
done <<< "$SUBJECTS"

SUBJECT_COUNT=${#SUBJECT_ARRAY[@]}

# Формируем заголовок коммита
if [[ "$SUBJECT_COUNT" -eq 0 ]]; then
    SUBJECT_TITLE="quartz-system"
elif [[ "$SUBJECT_COUNT" -eq 1 ]]; then
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]}"
elif [[ "$SUBJECT_COUNT" -eq 2 ]]; then
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]} и ${SUBJECT_ARRAY[1]}"
elif [[ "$SUBJECT_COUNT" -eq 3 ]]; then
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]}, ${SUBJECT_ARRAY[1]} и ${SUBJECT_ARRAY[2]}"
else
    SUBJECT_TITLE="${SUBJECT_ARRAY[0]}, ${SUBJECT_ARRAY[1]}, ${SUBJECT_ARRAY[2]} и ещё $((SUBJECT_COUNT - 3))"
fi

# Получаем дату, время и день недели
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

# Формируем описание, сгруппированное по предметам и темам
DESCRIPTION=$(
    printf '%s\n' "$CHANGES" |
        awk -F '\t' '
            function group_for(path, parts, n, i, result) {
                n = split(path, parts, "/")

                if (parts[1] == "content") {
                    if (n == 2) return "Прочее"

                    result = parts[2]
                    for (i = 3; i < n; i++) {
                        result = result "/" parts[i]
                    }
                    return result
                }

                if (n == 1) return "Служебные файлы"

                result = parts[1]
                for (i = 2; i < n; i++) {
                    result = result "/" parts[i]
                }
                return result
            }

            {
                status = $1
                old_path = $2
                path = ($1 ~ /^[RC]/ ? $3 : $2)

                # Исключаем служебные файлы из описания
                if (path ~ /^\.obsidian\//) next
                if (path ~ /^content\/src\//) next
                if (path == "content/sync_obsidian.sh") next

                if (status == "A") action = "Добавлен"
                else if (status == "M") action = "Изменён"
                else if (status == "D") action = "Удалён"
                else if (status ~ /^R/) action = "Переименован"
                else if (status ~ /^C/) action = "Скопирован"
                else action = "Изменён"

                # Убираем content/ из путей
                display_path = path
                sub(/^content\//, "", display_path)

                display_old_path = old_path
                sub(/^content\//, "", display_old_path)

                n = split(display_path, parts, "/")

                if (n == 1) {
                    subject = "Прочее"
                    topic = ""
                    file = parts[1]
                } else {
                    subject = parts[1]
                    topic = ""

                    for (i = 2; i < n; i++) {
                        if (topic != "") topic = topic "/"
                        topic = topic parts[i]
                    }

                    file = parts[n]
                }

                if (status ~ /^R/) {
                    old_file = display_old_path
                    sub(/^.*\//, "", old_file)
                    file = old_file " → " file
                }

                print subject "\t" topic "\t" action "\t" file
            }
        ' |
        sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3 -k4,4 |
        awk -F '\t' '
            BEGIN {
                print "___"
                previous_subject = ""
                previous_topic = ""
            }

            {
                subject = $1
                topic = $2
                action = $3
                file = $4

                # Заголовок учебного предмета
                if (subject != previous_subject) {
                    print ""
                    print "## " subject ":"
                    previous_subject = subject
                    previous_topic = ""
                }

                # Отдельный заголовок для каждой темы и подтемы
                if (topic != previous_topic && topic != "") {
                    count = split(topic, parts, "/")
                    path = ""

                    for (i = 1; i <= count; i++) {
                        if (path != "") path = path "/"
                        path = path parts[i]

                        indent = ""
                        for (j = 1; j < i; j++) {
                            indent = indent "  "
                        }

                        print indent "### (" parts[i] ")"
                    }

                    previous_topic = topic
                }

                # Файл под соответствующей темой
                indent = ""
                if (topic != "") {
                    count = split(topic, parts, "/")
                    for (i = 1; i < count; i++) {
                        indent = indent "  "
                    }
                }

                print indent "#### - " action ": " file
            }
        '
)

# Отбираем файлы, которые отображаются в описании
VISIBLE_CHANGES=$(printf '%s\n' "$CHANGES" |
    awk -F '\t' '
        {
            path = ($1 ~ /^[RC]/ ? $3 : $2)

            if (path ~ /^\.obsidian\//) next
            if (path ~ /^content\/src\//) next
            if (path == "content/sync_obsidian.sh") next

            print
        }
    ')

# Статистика только по отображаемым файлам
ADDED=$(printf '%s\n' "$VISIBLE_CHANGES" |
    awk -F '\t' '$1 == "A" {n++} END {print n+0}')

MODIFIED=$(printf '%s\n' "$VISIBLE_CHANGES" |
    awk -F '\t' '$1 == "M" {n++} END {print n+0}')

DELETED=$(printf '%s\n' "$VISIBLE_CHANGES" |
    awk -F '\t' '$1 == "D" {n++} END {print n+0}')

RENAMED=$(printf '%s\n' "$VISIBLE_CHANGES" |
    awk -F '\t' '$1 ~ /^R/ {n++} END {print n+0}')

DESCRIPTION="$DESCRIPTION

Итого: добавлено $ADDED, изменено $MODIFIED, удалено $DELETED, переименовано $RENAMED."

# Показываем результат перед созданием коммита
echo
echo "Заголовок: $COMMIT_MSG"
echo
echo "$DESCRIPTION"
echo

# Создаём коммит и отправляем его в master
git commit -m "$COMMIT_MSG" -m "$DESCRIPTION"
git push origin master
