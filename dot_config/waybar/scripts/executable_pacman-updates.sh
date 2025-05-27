#!/bin/bash

count=$(checkupdates 2>/dev/null | wc -l)

# Не показывать, если <= 5 обновлений
if [ "$count" -le 5 ]; then
  echo ""
  exit 0
fi

# Определение класса по порогам
if [ "$count" -lt 20 ]; then
  class="low"
elif [ "$count" -lt 50 ]; then
  class="medium"
elif [ "$count" -lt 100 ]; then
  class="high"
else
  class="critical"
fi

# Вывод текста и класса
echo "{\"text\": \"$count 󰅢\", \"class\": \"$class\"}"
