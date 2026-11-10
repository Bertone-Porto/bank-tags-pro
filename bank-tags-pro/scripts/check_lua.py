#!/usr/bin/env python3
"""Heuristic static checker for the Bank Tags Pro Lua sources (no Lua interpreter needed).

Run it from the repository root:  python scripts/check_lua.py plugin/bank-tags-pro

It is NOT a full Lua parser. It catches the mistakes that matter most after splitting a
script into modules:
  * unbalanced blocks (function/if/for/while/do/repeat ... end/until)
  * names used but never declared (typos, missing local, missing require)
  * names used before their `local` declaration (a forward reference silently becomes a nil global)
  * `Module.field` / `Module:field` used on a required module that does not export it
  * require() of a missing file and circular requires
  * local variables that are declared but never used
Exit code 0 means no errors (warnings and info lines do not fail the check).
"""
import os, re, sys

KEYWORDS = {"and","break","do","else","elseif","end","false","for","function","goto","if","in",
            "local","nil","not","or","repeat","return","then","true","until","while"}
GLOBALS = {
    # Lua standard library
    "print","pairs","ipairs","tostring","tonumber","type","pcall","xpcall","require","select","next",
    "error","assert","setmetatable","getmetatable","rawget","rawset","rawequal","rawlen","unpack",
    "math","string","table","os","utf8","coroutine","debug","_G","_VERSION",
    # RuneScape Client API globals used by this plugin
    "Event","PersistentDB","ui","id","Vector4","Keyboard","MiniMenuEntryType","config","log",
}

def lex(src):
    toks = []  # (kind, value, line)
    i, n, line = 0, len(src), 1
    def long_bracket(pos):
        m = re.match(r"\[(=*)\[", src[pos:])
        return m
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c in " \t\r":
            i += 1; continue
        if src.startswith("--", i):
            m = long_bracket(i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i + 2 + len(m.group(0)))
                j = n if j < 0 else j + len(close)
                line += src.count("\n", i, j); i = j
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        if c in "\"'":
            q, j = c, i + 1
            while j < n and src[j] != q:
                if src[j] == "\\": j += 1
                if j < n and src[j] == "\n": line += 1
                j += 1
            toks.append(("str", src[i:j+1], line)); i = j + 1; continue
        m = long_bracket(i) if c == "[" else None
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i + len(m.group(0)))
            j = n if j < 0 else j + len(close)
            toks.append(("str", "[[long]]", line)); line += src.count("\n", i, j); i = j; continue
        m = re.match(r"0[xX][0-9a-fA-F.]+(?:[pP][+-]?\d+)?|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?", src[i:])
        if m and (c.isdigit() or (c == "." and i + 1 < n and src[i+1].isdigit())):
            toks.append(("num", m.group(0), line)); i += len(m.group(0)); continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
        if m:
            w = m.group(0)
            toks.append(("kw" if w in KEYWORDS else "name", w, line)); i += len(w); continue
        for op in ("...","..","==","~=","<=",">=","//","::","<<",">>"):
            if src.startswith(op, i):
                toks.append(("op", op, line)); i += len(op); break
        else:
            toks.append(("op", c, line)); i += 1
    return toks

def check_balance(toks, fname, errors):
    stack = []
    skip_do = 0
    for kind, v, line in toks:
        if kind != "kw": continue
        if v in ("function", "if"): stack.append((v, line))
        elif v in ("for", "while"): stack.append((v, line)); skip_do += 1
        elif v == "do":
            if skip_do > 0: skip_do -= 1
            else: stack.append(("do", line))
        elif v == "repeat": stack.append((v, line))
        elif v == "end":
            if not stack or stack[-1][0] == "repeat":
                errors.append(f"{fname}:{line}: unexpected 'end'"); return
            stack.pop()
        elif v == "until":
            if not stack or stack[-1][0] != "repeat":
                errors.append(f"{fname}:{line}: unexpected 'until'"); return
            stack.pop()
    for v, line in stack:
        errors.append(f"{fname}:{line}: block '{v}' is never closed")

def analyse(toks):
    """Returns (decls, uses, field_uses, requires, returned_name).
    decls: name -> list of (index, kind) ; uses: list of (index, name, line)."""
    decls, uses, field_uses, requires = {}, [], [], {}
    declared_positions = set()
    def declare(name, idx, kind):
        decls.setdefault(name, []).append((idx, kind)); declared_positions.add(idx)
    n = len(toks)
    brace = []  # stack of booleans: inside a table constructor
    i = 0
    while i < n:
        kind, v, line = toks[i]
        if v == "{" and kind == "op": brace.append(True)
        elif v == "}" and kind == "op" and brace: brace.pop()
        if kind == "kw" and v == "local":
            j = i + 1
            if j < n and toks[j][1] == "function" and toks[j][0] == "kw":
                if j + 1 < n and toks[j+1][0] == "name":
                    declare(toks[j+1][1], j + 1, "localfunc")
            else:
                while j < n and toks[j][0] == "name":
                    declare(toks[j][1], j, "local")
                    j += 1
                    if j < n and toks[j][1] == "<":  # attribs <const>
                        j += 3
                    if j < n and toks[j][1] == ",": j += 1
                    else: break
        elif kind == "kw" and v == "function":
            j = i + 1
            is_method = False
            if j < n and toks[j][0] == "name":
                # function a.b:c(  -> `a` is a use; plain function name( is a global definition
                k = j
                while k + 2 < n and toks[k+1][1] in (".", ":") and toks[k+2][0] == "name":
                    if toks[k+1][1] == ":": is_method = True
                    k += 2
                if k == j and toks[j-1][1] != "local":
                    declare(toks[j][1], j, "globalfunc")
                j = k + 1
            if j < n and toks[j][1] == "(":
                j += 1
                if is_method: declare("self", j, "param")
                while j < n and toks[j][1] != ")":
                    if toks[j][0] == "name": declare(toks[j][1], j, "param")
                    j += 1
        elif kind == "kw" and v == "for":
            j = i + 1
            while j < n and toks[j][0] == "name":
                declare(toks[j][1], j, "param"); j += 1
                if j < n and toks[j][1] == ",": j += 1
                else: break
        i += 1
    # uses
    for i, (kind, v, line) in enumerate(toks):
        if kind != "name" or i in declared_positions: continue
        prev = toks[i-1][1] if i > 0 else ""
        nxt = toks[i+1][1] if i + 1 < n else ""
        if prev in (".", ":") and toks[i-1][0] == "op": continue          # field / method name
        if toks[i-1][1] == "goto" or prev == "::": continue
        # table constructor key `{ name = value }`
        if nxt == "=" and prev in ("{", ",", ";"):
            continue
        uses.append((i, v, line))
    # Module.field and Module:field uses
    for i in range(n - 2):
        if toks[i][0] == "name" and toks[i+1][1] in (".", ":") and toks[i+2][0] == "name" and toks[i+1][0] == "op":
            if i > 0 and toks[i-1][1] in (".", ":") : continue
            field_uses.append((toks[i][1], toks[i+2][1], toks[i][2]))
    # requires: local Alias = require("path")
    for i in range(n - 6):
        if (toks[i][1] == "local" and toks[i+1][0] == "name" and toks[i+2][1] == "="
                and toks[i+3][1] == "require" and toks[i+4][1] == "(" and toks[i+5][0] == "str"):
            requires[toks[i+1][1]] = toks[i+5][1].strip("\"'")
    returned = None
    for i in range(n - 1, 0, -1):
        if toks[i-1][1] == "return" and toks[i][0] == "name":
            returned = toks[i][1]; break
    return decls, uses, field_uses, requires, returned

def exports_of(toks, returned):
    names = set()
    n = len(toks)
    for i in range(n - 2):
        if toks[i][1] == returned and toks[i+1][1] in (".", ":") and toks[i+2][0] == "name":
            # `Name.field =` assignment, or `function Name.field` / `function Name:field`
            if toks[i+3][1] == "=" if i + 3 < n else False: names.add(toks[i+2][1])
            if i > 0 and toks[i-1][1] == "function": names.add(toks[i+2][1])
    # constructor fields: local Name = { a = 1, ... }
    for i in range(n - 3):
        if toks[i][1] == "local" and toks[i+1][1] == returned and toks[i+2][1] == "=" and toks[i+3][1] == "{":
            depth, j = 1, i + 4
            while j < n and depth > 0:
                if toks[j][1] == "{": depth += 1
                elif toks[j][1] == "}": depth -= 1
                elif depth == 1 and toks[j][0] == "name" and toks[j+1][1] == "=" and toks[j-1][1] in ("{", ",", ";"):
                    names.add(toks[j][1])
                j += 1
    return names

def main(root):
    errors, warnings = [], []
    files = {}
    for dirpath, _, names in os.walk(root):
        for name in names:
            if name.endswith(".lua"):
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, root).replace(os.sep, "/")
                files[rel[:-4]] = path           # module name without extension
    parsed = {}
    for mod, path in sorted(files.items()):
        toks = lex(open(path, encoding="utf-8").read())
        check_balance(toks, mod + ".lua", errors)
        parsed[mod] = (toks,) + analyse(toks)
    exports = {mod: exports_of(p[0], p[5]) for mod, p in parsed.items()}
    graph = {}
    for mod, (toks, decls, uses, field_uses, requires, returned) in sorted(parsed.items()):
        graph[mod] = set()
        # undefined / forward references
        seen = set()
        for idx, name, line in uses:
            if name in GLOBALS: continue
            entries = decls.get(name)
            if not entries:
                key = (name, "undef")
                if key not in seen:
                    errors.append(f"{mod}.lua:{line}: '{name}' is used but never declared"); seen.add(key)
            elif min(e[0] for e in entries) > idx:
                key = (name, "fwd")
                if key not in seen:
                    errors.append(f"{mod}.lua:{line}: '{name}' is used before its declaration (becomes a nil global)"); seen.add(key)
        # requires
        for alias, path in requires.items():
            if path not in files:
                errors.append(f"{mod}.lua: require(\"{path}\") does not match any file")
            else:
                graph[mod].add(path)
        # fields on required modules
        for alias, field, line in field_uses:
            if alias in requires and requires[alias] in exports:
                if field not in exports[requires[alias]]:
                    errors.append(f"{mod}.lua:{line}: {alias}.{field} is not exported by {requires[alias]}")
        # unused locals
        used = {name for _, name, _ in uses} | {a for a, _, _ in field_uses}
        for name, entries in decls.items():
            if any(kind in ("local", "localfunc") for _, kind in entries) and name not in used and name != "_":
                line = toks[min(e[0] for e in entries)][2]
                warnings.append(f"{mod}.lua:{line}: local '{name}' is never used")
    # cycles
    color = {}
    def visit(node, path):
        color[node] = 1
        for nxt in graph.get(node, ()):
            if color.get(nxt) == 1:
                errors.append("circular require: " + " -> ".join(path + [node, nxt]))
            elif nxt not in color:
                visit(nxt, path + [node])
        color[node] = 2
    for node in sorted(graph):
        if node not in color: visit(node, [])
    # unused exports (information)
    used_exports = set()
    for mod, (toks, decls, uses, field_uses, requires, returned) in parsed.items():
        for alias, field, _ in field_uses:
            if alias in requires: used_exports.add((requires[alias], field))
    infos = []
    for mod, names in sorted(exports.items()):
        for name in sorted(names):
            if (mod, name) not in used_exports and mod not in ("main",):
                infos.append(f"{mod}.lua: export '{name}' is not used by any other module")
    for line in errors: print("ERROR  ", line)
    for line in warnings: print("warning", line)
    for line in infos: print("info   ", line)
    print(f"\n{len(files)} files, {len(errors)} error(s), {len(warnings)} warning(s), {len(infos)} info")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
