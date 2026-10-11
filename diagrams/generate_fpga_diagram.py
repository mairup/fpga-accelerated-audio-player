#!/usr/bin/env python3
"""Deterministically extract the FPGA module graph from the Chisel sources.

Reads fpga/src/main/scala/**/*.scala and emits:
  diagrams/fpga-design.json  - canonical graph: modules, ports (with types),
                               hierarchy, and module-to-module connections
  diagrams/fpga-design.md    - Mermaid multi-level diagram, data types on edges

Deterministic: identical sources -> identical output. The JSON is the baseline
to diff any later hand-polished diagram against.

Run:  python3 diagrams/generate_fpga_diagram.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "fpga", "src", "main", "scala")
OUT = os.path.dirname(os.path.abspath(__file__))

MODULE_KINDS = ("Module", "RawModule", "BlackBox")

# class Name  (params)  extends Kind   -- [^)]* spans newlines for multi-line params
CLASS_RE = re.compile(r'class\s+(\w+)\s*(?:\(([^)]*)\))?\s*extends\s+([\w.]+)')
PKG_RE = re.compile(r'package\s+([\w.]+)')
# port:  val name = Input/Output(type)   (type may contain nested parens; one per line)
PORT_RE = re.compile(r'val\s+(\w+)\s*=\s*(Input|Output)\s*\((.*)\)\s*$', re.MULTILINE)
# instantiation:  val inst = Module(new Cls(args))
INST_RE = re.compile(r'val\s+(\w+)\s*=\s*Module\(\s*new\s+([\w.]+)\s*(?:\(([^)]*)\))?\s*\)')
# connection:  dstInst.io.dstPort := RHS   (single-line statements)
CONN_RE = re.compile(r'(\w+)\.io\.(\w+)\s*:=\s*(.+)$', re.MULTILINE)
# IO construction:  val io = IO(new BundleName(args))  or  IO(new Bundle { ... })
IO_RE = re.compile(r'IO\s*\(\s*new\s+([\w.]+)\s*(?:\(([^)]*)\))?\s*\)')
IO_INLINE_RE = re.compile(r'IO\s*\(\s*new\s+Bundle\s*\{')


def braced_block(text, start):
    """Return (body, end_index) of the balanced {...} starting at/after start."""
    i = text.find('{', start)
    if i < 0:
        return None, start
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[i + 1:j], j
    return None, start


def read_expr(body, start):
    """Read an expression from start, crossing lines until parentheses balance."""
    i = start
    depth = 0
    seen = False
    buf = []
    while i < len(body):
        c = body[i]
        buf.append(c)
        if c == '(':
            depth += 1
            seen = True
        elif c == ')':
            depth -= 1
        i += 1
        if seen and depth <= 0 and c == '\n':
            break
        if seen and depth <= 0 and i == len(body):
            break
    return ''.join(buf).strip()


def parse_params(params_str):
    """'val a: Int = 1, val b: Int = 2' -> [('a','1'), ('b','2')]; '' -> []"""
    out = []
    for part in (params_str or '').split(','):
        part = part.strip()
        if not part:
            continue
        m = re.match(r'(?:val\s+)?(\w+)\s*:\s*[^=]*?(?:=\s*(\S+))?$', part)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


def arg_value(arg, ctx):
    """Resolve an instantiation argument to a concrete value string, or None."""
    a = arg.strip()
    if not a:
        return None
    if re.fullmatch(r'[-+]?\d+(_\d+)*', a):
        return a.replace('_', '')
    if re.fullmatch(r'[-+]?\d*\.\d+', a):
        return a
    if a in ('true', 'false'):
        return a
    if a in ctx:
        return ctx[a]
    return a  # symbolic (e.g. VisualizerConfig.X, delayBufferSize)


def wire_sources(body, wire):
    """Resolve a bare wire name to [(inst, port)] module refs in its definition."""
    m = re.search(r'\bval\s+' + re.escape(wire) + r'\s*=\s*', body)
    if not m:
        return []
    expr = read_expr(body, m.end())
    return [(r[0], r[1]) for r in re.findall(r'(\w+)\.io\.(\w+)', expr) if r[0] != 'io']


def scan_file(path):
    with open(path) as f:
        text = f.read()
    rel = os.path.relpath(path, ROOT)
    pkg = ''
    m = PKG_RE.search(text)
    if m:
        pkg = m.group(1)

    modules = []       # {name, kind, pkg, file, params: [(name,default)]}
    bundles = {}       # bundleName -> [ {name, dir, type} ]
    bundle_params = {} # bundleName -> [(name, default)]
    io_of = {}         # moduleName -> ('bundle', bundleName, [args]) | ('inline', [ports])
    insts = []         # {parent, inst, cls, args: [str]}
    conns = []         # {dst_inst, dst_port, srcs: [(inst,port)]}

    for cm in CLASS_RE.finditer(text):
        name, params_str, kind = cm.group(1), cm.group(2) or '', cm.group(3)
        body, _ = braced_block(text, cm.end())
        if body is None:
            continue
        if kind in MODULE_KINDS:
            modules.append({
                'name': name, 'kind': kind, 'pkg': pkg, 'file': rel,
                'params': parse_params(params_str),
            })
            im = IO_INLINE_RE.search(body)
            if im:
                # im.end()-1 is the '{' position (the regex consumed it)
                iblk, _ = braced_block(body, im.end() - 1)
                ports = []
                if iblk:
                    for pm in PORT_RE.finditer(iblk):
                        ports.append({'name': pm.group(1), 'dir': pm.group(2),
                                      'type': pm.group(3).strip()})
                io_of[name] = ('inline', ports)
            else:
                im = IO_RE.search(body)
                if im:
                    io_bundle = im.group(1).split('.')[-1]
                    args = [a.strip() for a in (im.group(2) or '').split(',') if a.strip()]
                    io_of[name] = ('bundle', io_bundle, args)
            for ix in INST_RE.finditer(body):
                args = [a.strip() for a in (ix.group(3) or '').split(',') if a.strip()]
                insts.append({'parent': name, 'inst': ix.group(1),
                              'cls': ix.group(2).split('.')[-1], 'args': args})
            for cx in CONN_RE.finditer(body):
                dst_inst, dst_port, rhs = cx.group(1), cx.group(2), cx.group(3)
                srcs = [s for s in re.findall(r'(\w+)\.io\.(\w+)', rhs) if s[0] != 'io']
                if not srcs:
                    wire = rhs.strip()
                    if re.fullmatch(r'\w+', wire):
                        srcs = wire_sources(body, wire)
                if srcs:
                    conns.append({'dst_inst': dst_inst, 'dst_port': dst_port,
                                  'srcs': srcs})
        elif kind == 'Bundle':
            bundle_params[name] = parse_params(params_str)
            ports = []
            for pm in PORT_RE.finditer(body):
                ports.append({'name': pm.group(1), 'dir': pm.group(2),
                              'type': pm.group(3).strip()})
            bundles[name] = ports

    return {'modules': modules, 'bundles': bundles, 'bundle_params': bundle_params,
            'io_of': io_of, 'insts': insts, 'conns': conns}


def resolve_params(modules, insts):
    """Map instance name -> {param name: value}, resolving parent params first."""
    mod_params = {m['name']: m['params'] for m in modules}
    children_of = {}
    for i in insts:
        children_of.setdefault(i['parent'], []).append(i)
    inst_of_class = {i['cls']: i['inst'] for i in insts}
    resolved = {}
    for _ in range(6):
        for parent_cls, children in children_of.items():
            pinst = inst_of_class.get(parent_cls)
            ctx = resolved.get(pinst, {}) if pinst else {}
            for c in children:
                vals = {}
                for (pname, pdefault), arg in zip(mod_params.get(c['cls'], []), c['args']):
                    v = arg_value(arg, ctx)
                    vals[pname] = v if v is not None else pdefault
                resolved[c['inst']] = vals
    return resolved


def resolve_port_types(bundles, bundle_params, io_of, insts, resolved):
    """Return instance name -> {port name: type} with params substituted."""
    inst_cls = {i['inst']: i['cls'] for i in insts}
    result = {}
    for inst_name, cls in inst_cls.items():
        entry = io_of.get(cls)
        if not entry:
            continue
        ctx = resolved.get(inst_name, {})
        ports = {}
        if entry[0] == 'inline':
            for p in entry[1]:
                ports[p['name']] = subst_type(p['type'], ctx)
        else:
            _, bname, args = entry
            bctx = {}
            for (qname, qdefault), arg in zip(bundle_params.get(bname, []), args):
                v = arg_value(arg, ctx)
                bctx[qname] = v if v is not None else qdefault
            for p in bundles.get(bname, []):
                ports[p['name']] = subst_type(p['type'], bctx)
        result[inst_name] = ports
    return result


def subst_type(t, ctx):
    for k, v in ctx.items():
        if v is None:
            continue
        t = re.sub(r'\b' + re.escape(k) + r'\b', str(v), t)
    return t


def build_graph():
    all_modules, all_bundles, all_bparams, all_io, all_insts, all_conns = [], {}, {}, {}, [], []
    for dirpath, _, files in os.walk(SRC):
        for fn in sorted(files):
            if fn.endswith('.scala'):
                d = scan_file(os.path.join(dirpath, fn))
                all_modules.extend(d['modules'])
                all_bundles.update(d['bundles'])
                all_bparams.update(d['bundle_params'])
                all_io.update(d['io_of'])
                all_insts.extend(d['insts'])
                all_conns.extend(d['conns'])

    resolved = resolve_params(all_modules, all_insts)
    inst_ports = resolve_port_types(all_bundles, all_bparams, all_io, all_insts, resolved)

    mods = [{'name': m['name'], 'kind': m['kind'], 'pkg': m['pkg'], 'file': m['file']}
            for m in all_modules]
    mods.sort(key=lambda m: m['name'])

    hier = [{'parent': i['parent'], 'inst': i['inst'], 'cls': i['cls'], 'args': i['args']}
            for i in all_insts]
    hier.sort(key=lambda h: (h['parent'], h['inst']))

    edges = []
    for c in all_conns:
        for (sinst, sport) in c['srcs']:
            edges.append({
                'from': sinst, 'from_port': sport,
                'to': c['dst_inst'], 'to_port': c['dst_port'],
                'type': inst_ports.get(sinst, {}).get(sport, ''),
            })
    edges.sort(key=lambda e: (e['from'], e['from_port'], e['to'], e['to_port']))

    return {
        'modules': mods,
        'hierarchy': hier,
        'connections': edges,
        'inst_ports': {k: inst_ports[k] for k in sorted(inst_ports)},
    }


def mermaid(graph):
    inst_cls = {h['inst']: h['cls'] for h in graph['hierarchy']}
    cls_inst = {h['cls']: h['inst'] for h in graph['hierarchy']}
    children = {}   # parent CLASS -> [child instances]
    for h in graph['hierarchy']:
        children.setdefault(h['parent'], []).append(h['inst'])

    L = ['flowchart TB']

    def emit(parent_cls, depth):
        ind = '    ' * depth
        for inst in sorted(children.get(parent_cls, [])):
            cls = inst_cls[inst]
            if cls in children:
                L.append(f'{ind}subgraph S_{inst}["{cls}"]')
                emit(cls, depth + 1)
                L.append(f'{ind}end')
            else:
                L.append(f'{ind}{inst}["{cls}"]')

    root_classes = sorted({h['parent'] for h in graph['hierarchy']
                           if h['parent'] not in cls_inst})
    for rc in root_classes:
        L.append(f'subgraph S_{rc}["{rc}"]')
        emit(rc, 1)
        L.append('end')

    for e in graph['connections']:
        typ = e['type'] or ''
        L.append(f'{e["from"]} -- "{typ}" --> {e["to"]}')
    return '\n'.join(L)


def main():
    graph = build_graph()
    json_path = os.path.join(OUT, 'fpga-design.json')
    md_path = os.path.join(OUT, 'fpga-design.md')
    with open(json_path, 'w') as f:
        json.dump(graph, f, indent=2)
        f.write('\n')
    with open(md_path, 'w') as f:
        f.write('# FPGA design (deterministic)\n\n')
        f.write('> Auto-generated from the Chisel sources by `generate_fpga_diagram.py`.\n')
        f.write('> Do not edit by hand; re-run the script to regenerate.\n\n')
        f.write('```mermaid\n' + mermaid(graph) + '\n```\n')
    print(f'wrote {json_path}')
    print(f'wrote {md_path}')
    print(f'modules: {len(graph["modules"])}')
    print(f'instances: {len(graph["hierarchy"])}')
    print(f'connections: {len(graph["connections"])}')


if __name__ == '__main__':
    main()
