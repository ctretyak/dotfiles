# Global Rules

## Communication
- The user speaks English and Russian. Prefer Russian for all responses unless the user writes in English.

- Do NOT add `Co-Authored-By` lines to commit messages
- Do NOT commit or push to git unless explicitly asked by the user. Each commit/push requires separate explicit permission — authorization does NOT carry over from previous tasks in the same conversation

## Projects
- Рабочие проекты лежат в `~/git/x`. Если задача затрагивает несколько проектов, искать их там.

## Obsidian
- Vault name: `Core`
- Для управления заметками использовать Obsidian CLI (`obsidian`). Перед первым использованием в сессии — `obsidian help` для актуального списка команд
- При создании заметок из чатов форматировать в Markdown для Obsidian (`[[wikilinks]]`, `#tags`, заголовки)
- CLI выводит loading-сообщения в stderr — фильтровать при парсинге вывода
- Новые заметки всегда создавать в `00 INBOX`. Не создавать заметки в корне волта или других папках — сортировка при триаже через `/pkm-inbox`.

## Quality
- Do NOT state facts (performance improvements, feature claims, library capabilities, etc.) without verifying them first. Check changelogs, docs, or source code before making claims in specs, proposals, commit messages, or any artifacts.
