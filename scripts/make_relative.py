#!/usr/bin/env python3
import os
import re
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit


REPO_ROOT = Path(__file__).resolve().parents[1]


ALLOWED_ROOTS = (
    'content/', 'modules/', 'misc/', 'sites/', 'files/',
    'index.html', 'home.html', 'calendars.html'
)


def is_local_abs(path: str) -> bool:
    if not path.startswith('/'):
        return False
    p = path.lstrip('/')
    return any(p.startswith(prefix) for prefix in ALLOWED_ROOTS)


def to_relative(from_rel: str, abs_url: str) -> str:
    """Convert an absolute repo-rooted URL ('/...') to a path relative to from_rel.
    Preserves query and fragment.
    """
    parts = urlsplit(abs_url)
    abs_path = parts.path.lstrip('/')
    base_dir = (REPO_ROOT / from_rel).parent
    target = (REPO_ROOT / abs_path)
    try:
        rel = os.path.relpath(target, start=base_dir)
    except Exception:
        # Fallback to original if something unexpected happens
        return abs_url
    rel = rel.replace('\\', '/')
    if rel == '.':
        rel = os.path.basename(abs_path) or '.'
    return urlunsplit(('', '', rel, parts.query, parts.fragment))


ATTR_RE = re.compile(r"(?i)(\b(?:href|src|data|background)\s*=\s*([\"']))(/[^\"']*)(\2)")
CSS_URL_RE = re.compile(r"(?i)url\(\s*([\"']?)(/[^)\'\"]+)(\1)\s*\)")


def process_html(rel_path: str) -> bool:
    fp = REPO_ROOT / rel_path
    original = fp.read_text(encoding='utf-8', errors='ignore')
    content = original

    def attr_repl(m):
        prefix, quote, value, _ = m.groups()
        if is_local_abs(value):
            newv = to_relative(rel_path, value)
            return f"{prefix}{newv}{quote}"
        return m.group(0)

    def css_repl(m):
        q, value, _ = m.groups()
        if is_local_abs(value):
            newv = to_relative(rel_path, value)
            return f"url({q}{newv}{q})"
        return m.group(0)

    content = ATTR_RE.sub(attr_repl, content)
    content = CSS_URL_RE.sub(css_repl, content)

    if content != original:
        fp.write_text(content, encoding='utf-8')
        return True
    return False


def process_css(rel_path: str) -> bool:
    fp = REPO_ROOT / rel_path
    original = fp.read_text(encoding='utf-8', errors='ignore')
    content = original

    def css_repl(m):
        q, value, _ = m.groups()
        if is_local_abs(value):
            newv = to_relative(rel_path, value)
            return f"url({q}{newv}{q})"
        return m.group(0)

    content = CSS_URL_RE.sub(css_repl, content)

    if content != original:
        fp.write_text(content, encoding='utf-8')
        return True
    return False


def main():
    changed = 0
    for p in REPO_ROOT.rglob('*'):
        if not p.is_file():
            continue
        rel = p.relative_to(REPO_ROOT).as_posix()
        if p.suffix.lower() in {'.html', '.htm'}:
            if process_html(rel):
                changed += 1
        elif p.suffix.lower() == '.css':
            if process_css(rel):
                changed += 1
    print(f"Files updated: {changed}")


if __name__ == '__main__':
    main()

