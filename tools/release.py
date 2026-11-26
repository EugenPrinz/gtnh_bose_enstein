#!/usr/bin/env python3
"""Манифест версии bec/version.lua: номер, дата и список файлов с размерами.

  python3 tools/release.py           — пересчитать размеры, версию не менять
  python3 tools/release.py patch     — 0.3.0 → 0.3.1   (minor, major — так же)

install-bec качает version.lua первым, затем файлы из списка и сверяет размер: несовпадение значит, что GitHub
отдал старую копию из кеша, — такой файл не ставится. Запускать перед каждым коммитом, меняющим bec/ (тест следит).
"""
import datetime
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bec")
VER = os.path.join(ROOT, "version.lua")
SKIP = {"version.lua", "install.lua"}


def current():
    try:
        m = re.search(r'version = "(\d+)\.(\d+)\.(\d+)"', open(VER, encoding="utf-8").read())
        return [int(x) for x in m.groups()]
    except (OSError, AttributeError):
        return [0, 3, 0]


def main():
    v = current()
    bump = sys.argv[1] if len(sys.argv) > 1 else None
    if bump == "major":
        v = [v[0] + 1, 0, 0]
    elif bump == "minor":
        v = [v[0], v[1] + 1, 0]
    elif bump == "patch":
        v = [v[0], v[1], v[2] + 1]
    elif bump:
        sys.exit("bump: major | minor | patch")
    files = []
    for d, _, names in os.walk(ROOT):
        for n in names:
            if n.endswith(".lua"):
                rel = os.path.relpath(os.path.join(d, n), ROOT).replace(os.sep, "/")
                if rel not in SKIP:
                    files.append((rel, os.path.getsize(os.path.join(d, n))))
    files.sort(key=lambda f: (f[0].count("/"), f[0]))
    date = datetime.date.today().isoformat()
    body = ["-- Генерируется tools/release.py — не править руками.",
            "return {", f'  version = "{v[0]}.{v[1]}.{v[2]}", date = "{date}",', "  files = {"]
    body += [f'    {{"{f}", {s}}},' for f, s in files]
    body += ["  },", "}", ""]
    open(VER, "w", encoding="utf-8", newline="\n").write("\n".join(body))
    print(f"{v[0]}.{v[1]}.{v[2]} · {len(files)} файлов")


main()
