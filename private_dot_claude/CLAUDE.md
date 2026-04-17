# Global Rules

## Git
- Do NOT commit or push to git unless explicitly asked by the user. Each commit/push requires separate explicit permission — authorization does NOT carry over from previous tasks in the same conversation

## Projects
- Рабочие проекты лежат в `~/git/x`. Если задача затрагивает несколько проектов, искать их там.

## Chezmoi
- Source: `~/.local/share/chezmoi`. Системные конфиги (dotfiles, ansible-задачи, пакеты) редактируются в source, не напрямую в `~/`.
- Исключение: GUI-настроенные приложения и бинарные plist — редактировать целевой файл, затем сразу `chezmoi add <path>`.
- После изменений в source: `chezmoi diff` для превью, `chezmoi apply` для применения (apply также триггерит ansible при изменениях в `dot_ansible/`).
- При добавлении новых файлов проверять `.chezmoiignore` на предмет OS-специфичности — без фильтрации файл развернётся на всех системах.
- Правило применяется из ЛЮБОЙ директории, не только при работе внутри source.

## Obsidian
- Vault: `Core` at `~/Documents/Core`
- При любой работе с vault (создание/чтение/поиск заметок, `/pkm-*` команды, упоминания Obsidian, "заметки", "vault") — сначала прочитать `~/Documents/Core/CLAUDE.md` и нужные команды из `~/Documents/Core/system/claude/commands/`. Это **единственный источник правил** для vault.
- Правило применяется из ЛЮБОЙ директории, не только при работе внутри `~/Documents/Core`.
- НЕ дублировать и НЕ переопределять правила vault в этом файле, в локальных `.claude/CLAUDE.md` или где-либо ещё — только единый источник гарантирует консистентность между personal/work тенантами и локальным Claude Code.
- Все операции с vault — через Obsidian CLI (`obsidian help` для списка команд). НЕ редактировать файлы vault напрямую.

## Workflow

### opsx:apply
- Выполнять скоупы задач (1, 2, 3, ...) последовательно, каждый скоуп — через отдельного субагента
- Не выполнять отдельные подзадачи (1.2, 1.3) в основном контексте — это засоряет контекст
- Основной контекст только координирует: запускает субагента на скоуп, получает результат, запускает следующий

## Quality
- Do NOT state facts (performance improvements, feature claims, library capabilities, etc.) without verifying them first. Check changelogs, docs, or source code before making claims in specs, proposals, commit messages, or any artifacts.
