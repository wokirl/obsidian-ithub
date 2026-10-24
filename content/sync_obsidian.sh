
#!/bin/bash
set -e

# Переходим в корень репозитория
cd "$(dirname "$0")"

# Добавляем все изменения в индекс Git
git add -A

# Не создаём пустой коммит
if git diff --cached --quiet; then
    echo "Нет изменений для синхронизации."
    exit 0
fi

# Определяем предмет с наибольшим количеством изменённых файлов
MAIN_DIR=$(git diff --cached --name-only |
    grep '^content/' |
    grep -vE '^content/src/|^content/sync_obsidian\.sh$' |
    awk -F/ '{
        if (NF < 3) {
            print "content"
        } else {
            print $2
        }
    }' |
    sort |
    uniq -c |
    sort -nr |
    head -n 1 |
    awk '{print $2}')

# Если изменения касаются не заметок, используем системную категорию
if [ -z "$MAIN_DIR" ]; then
    MAIN_DIR="quartz-system"
fi

# Получаем текущую дату и время
CURRENT_TIME=$(date "+%d.%m.%y %H:%M")

# Определяем день недели на русском языке
WEEKDAY_NUMBER=$(date "+%u")

case "$WEEKDAY_NUMBER" in
    1) WEEKDAY="понедельник" ;;
    2) WEEKDAY="вторник" ;;
    3) WEEKDAY="среда" ;;
    4) WEEKDAY="четверг" ;;
    5) WEEKDAY="пятница" ;;
    6) WEEKDAY="суббота" ;;
    7) WEEKDAY="воскресенье" ;;
esac

# Формируем заголовок коммита
COMMIT_MSG="Sync: $MAIN_DIR $CURRENT_TIME $WEEKDAY"

echo "Отправка изменений: $COMMIT_MSG"

# Создаём коммит и отправляем его в master
git commit -m "$COMMIT_MSG"
git push origin master

