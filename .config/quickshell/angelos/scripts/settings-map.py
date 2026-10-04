#!/usr/bin/env python3
"""The map of the settings: "was → now", from the tree (modules/settings/tree.json) and the
pages' QML (scripts/settings-inventory.py). Writes Markdown to stdout.

  settings-map.py > docs/SETTINGS-MAP.md

The tree is data: move a group by moving its "file/name" in tree.json, then rebuild this map.
"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TREE = json.loads((ROOT / "modules/settings/tree.json").read_text())
spec = importlib.util.spec_from_file_location("inventory", ROOT / "scripts/settings-inventory.py")
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)
INV = inventory.inventory(ROOT / "modules/settings/pages")

# the old tree (before 2026-10-04): section › page file, as the sidebar showed it
OLD = {
    "account": "Аккаунт", "network": "Wi-Fi и сеть", "bluetooth": "Bluetooth", "notifications": "Уведомления",
    "sound": "Звук", "sfx": "Звук › Звуки системы", "appearance": "Внешний вид", "fonts": "Внешний вид › Шрифты",
    "cursor": "Внешний вид › Курсор", "wallpaper": "Обои и стол", "widgets": "Обои и стол › Виджеты",
    "deskmenu": "Обои и стол › ПКМ-меню", "bar": "Панель и «Пуск»", "lyrics": "Лирика", "y2k": "Ангелочек ✧",
    "monitor": "Экран", "windows": "Окна и столы", "workspaces": "Окна и столы › Воркспейсы",
    "keyboard": "Клавиатура", "shortcuts": "Клавиатура › Горячие клавиши", "mouse": "Мышь и геймпад › Мышь и лупа",
    "gamepad": "Мышь и геймпад › Геймпад", "lock": "Блокировка и заставка", "capture": "Скриншоты и запись",
    "defaults": "Приложения", "plugins": "Плагины", "studio": "Плагины › Мастер плагинов", "updates": "Обновления",
    "system": "Система",
}
# what changed besides moving: the duplicates resolved (one place for every setting, links elsewhere)
NOTES = [
    ("Ангелочек › Звуки", "дубль «Звуков системы» (звуки angelOS, набор, громкость, милые мелочи, голос) — "
     "теперь ссылка на «Система › Звуки системы»"),
    ("Аккаунт › Частое", "кнопки «Светлая/Тёмная тема», «Крупнее», «Мельче» меняли настройки темы и размера "
     "пикселя второй раз — теперь ссылка «Тема и размер ›»; ссылки на обои, обновления и частые страницы остались"),
    ("Мышь и лупа › Фокус следует за мышью", "дубль «Окна › Размещение» — теперь ссылка туда"),
    ("Экран › Главный экран: «У ангела свой экран», «У сайдбара свой экран»", "меняли экран помощницы и сайдбара "
     "второй раз — теперь ссылки на «Помощница › В углу» и «Панель задач › Сайдбар»"),
    ("Внешний вид › Стекло и пиксели › Масштаб шрифтов", "переехал в «Персонализация › Шрифты › Интерфейс»: всё про шрифты вместе"),
    ("Система › Программы (терминал, файловый менеджер)", "встали рядом с приложениями по умолчанию: «Приложения › Приложения по умолчанию»"),
    ("Окна › Закрытие окон", "это про кнопки окон на панели — теперь в «Персонализация › Панель задач»"),
    ("Панель и «Пуск» › Кнопка «Пуск», тонкая настройка, логотип", "отдельная страница «Персонализация › «Пуск»»: вид меню, его кнопка и тонкая настройка вместе"),
    ("Ангелочек › Блёстки", "это курсор — теперь в «Персонализация › Курсор»"),
    ("Ангелочек › Загрузочный экран", "в «Персонализация › Блокировка и заставка»"),
    ("Ангелочек › Стрим-режим", "своя страница «Система › Стрим-режим»"),
    ("Звук › Голосовой ввод (VoxType)", "в «Bluetooth и устройства › Клавиатура и ввод»"),
    ("Система › Игра", "в «Ангелочек › Игра»"),
]


def label(o, hell=False):
    return o.get("ru", "")


def pages():
    yield dict(TREE["account"], id=TREE["account"]["page"]), None
    for c in TREE["categories"]:
        for p in c["pages"]:
            yield p, c


def where(src, name):
    for p, c in pages():
        for b in p["blocks"]:
            s, _, n = b.partition("/")
            if s == src and (not n or n == name):
                sub = ""
                g = next((g for g in INV if g["page"] == src and g["name"] == name), None)
                if g and g["advanced"]:
                    sub = " (раскрывается)"
                return (c["ru"] + " › " if c and len(c["pages"]) > 1 else "") + p["ru"] + sub
    return "—"


def main():
    out = ["# Настройки: карта «было → стало»", "",
           "Собрана из данных: дерево — `modules/settings/tree.json`, настройки — группы `PxGroup { name: … }` "
           "в `modules/settings/pages/*.qml`. Перенести группу — передвинуть её `\"файл/имя\"` в tree.json и "
           "пересобрать карту: `python3 scripts/settings-map.py > docs/SETTINGS-MAP.md`. "
           "Тест `tests/settings/test_tree.py` следит, чтобы каждая группа была ровно на одной странице и ни одна "
           "настройка не пропала.", "", "## Новое дерево", ""]
    acc = TREE["account"]
    out.append(f"- **{acc['ru']}** (карточка сверху слева) — " + ", ".join(blk(b) for b in acc["blocks"]))
    for c in TREE["categories"]:
        out.append(f"- **{c['ru']}**")
        for p in c["pages"]:
            flag = " _(режим разработчика)_" if p.get("developer") else " _(только автору)_" if p.get("owner") else ""
            out.append(f"  - {p['ru']}{flag} — " + ", ".join(blk(b) for b in p["blocks"]))
    out += ["", "## Было → стало", "", "| было (раздел › страница › группа) | стало |", "|---|---|"]
    for g in INV:
        if g["page"] in TREE.get("skinHomes", []) or g["name"] == "(page)":
            continue
        old = OLD.get(g["page"], g["page"]) + " › " + (g["title"]["ru"] or g["name"]).strip('"')
        out.append(f"| {old} | {where(g['page'], g['name'])} |")
    out += ["", "## Что изменилось кроме переездов", ""]
    out += [f"- **{a}** — {b}" for a, b in NOTES]
    out += ["", "## Старые адреса", "",
            "Старые id страниц (`angelos settings bar`, ссылки мастера, тура, помощницы) ведут на новые места "
            "(`legacy` в tree.json, `SettingsTree.resolve`): " +
            ", ".join(f"`{k}` → `{v['page']}`" for k, v in TREE.get("legacy", {}).items()) + "."]
    print("\n".join(out))


def blk(b):
    if b.startswith("@owner/"):
        return "страница автора"
    s, _, n = b.partition("/")
    if not n:
        return f"всё со страницы «{OLD.get(s, s).split(' › ')[-1]}»"
    g = next((g for g in INV if g["page"] == s and g["name"] == n), None)
    return f"«{(g['title']['ru'] if g else n).strip(chr(34))}»"


if __name__ == "__main__":
    main()
