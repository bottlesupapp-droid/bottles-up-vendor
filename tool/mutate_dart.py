#!/usr/bin/env python3
"""Mutation check for Dart code: does the test suite notice when the code is made wrong?

For every mutant (one small text change to a source file) this runs the given tests against a throwaway COPY of the app and reports
KILLED (a test failed: good), SURVIVED (every test still passed: the tests do not cover that line, or the change does not matter),
or INVALID (the change did not compile: it says nothing). The real tree is never touched. Each worker has its own copy, next to the
app (apps/<app>-mutN, so the relative paths to ../../packages/shared and ../bottles-up-website-main still work), deleted at the end.

  python3 tool/mutate_dart.py SPEC.py [--jobs 4] [--only 3,7] [--keep] [--count]

SPEC.py defines
  TESTS   = ['test/table_service']                        what to run for every mutant (paths for `flutter test`)
  MUTANTS = [(id, 'lib/x.dart', 'exact old text', 'new text'), ...]   (the old text must occur exactly once in that file;
            an old text of '@57' means: replace the whole of line 57)
  GENERATE = {'lib/x.dart': ['relational', 'logical', 'boolean']}      (optional) mutants made automatically from operators
The baseline (no change) runs first in every copy and must pass, otherwise nothing is reported. Each run has a hard timeout and is
killed with its whole process group, so a hung test cannot leave stray processes.

Lessons from earlier runs: a run killed halfway used to leave a mutated file behind in the real tree, which the "does the original text
still exist" check could not see. Working on copies removes that failure. Mutants that survive are read one by one: some are
equivalent (the change cannot be seen from outside), the rest mean a missing test.
"""
import atexit
import concurrent.futures
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
APPS = os.path.dirname(APP)
NAME = os.path.basename(APP)
TIMEOUT = int(os.environ.get('MUTATE_TIMEOUT', '240'))
EXCLUDES = ['.git', 'build', 'ios', 'android', 'macos', 'windows', 'linux', 'web', '_archive', '.idea', 'coverage']

OPERATORS = {
    'relational': [(' > ', ' >= '), (' >= ', ' > '), (' < ', ' <= '), (' <= ', ' < '), (' == ', ' != '), (' != ', ' == ')],
    'logical': [(' && ', ' || '), (' || ', ' && ')],
    'boolean': [('true', 'false'), ('false', 'true')],
}


LIVE = set()


def kill_all(*_):
    """Kill every test run still going, with its whole process group (the test processes live in their own sessions, so killing this
    script alone would leave them running and loading the machine)."""
    for p in list(LIVE):
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
    if _:
        os._exit(130)


signal.signal(signal.SIGINT, kill_all)
signal.signal(signal.SIGTERM, kill_all)
atexit.register(kill_all)


def run(cmd, cwd, timeout=TIMEOUT):
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    LIVE.add(p)
    try:
        out, _ = p.communicate(timeout=timeout)
        return p.returncode, out
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(p.pid), signal.SIGKILL)
        out, _ = p.communicate()
        return 124, (out or '') + '\nTIMEOUT'
    finally:
        LIVE.discard(p)
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)   # nothing the run started may outlive it
        except (ProcessLookupError, PermissionError):
            pass


def make_copy(i):
    dst = os.path.join(APPS, f'{NAME}-mut{i}')
    if os.path.exists(dst):
        shutil.rmtree(dst)
    ignore = shutil.ignore_patterns(*EXCLUDES)
    shutil.copytree(APP, dst, ignore=ignore, symlinks=True)
    return dst


def generated(files):
    """Automatic mutants from operators, on code lines only (not comments), one per occurrence."""
    out = []
    for rel, kinds in files.items():
        lines = open(os.path.join(APP, rel)).read().split('\n')
        for n, line in enumerate(lines):
            if line.lstrip().startswith(('//', '///', '*', '/*', 'import ', 'export ', 'part ')):
                continue
            for kind in kinds:
                for (a, b) in OPERATORS[kind]:
                    for m in re.finditer(re.escape(a), line):
                        # skip operators that sit inside a string literal on this line
                        before = line[:m.start()]
                        if before.count("'") % 2 == 1 or before.count('"') % 2 == 1:
                            continue
                        if kind == 'boolean' and not re.search(r'(?<![A-Za-z0-9_])' + a + r'(?![A-Za-z0-9_])', line[m.start() - 1:m.end() + 1]):
                            continue
                        mutated = line[:m.start()] + b + line[m.end():]
                        out.append((rel, n + 1, line, mutated))
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    spec = {}
    exec(open(args[0]).read(), spec)
    tests = spec['TESTS']
    hand = spec.get('MUTANTS', [])
    gen = spec.get('GENERATE', {})
    jobs = int(args[args.index('--jobs') + 1]) if '--jobs' in args else 4
    only = {int(x) for x in args[args.index('--only') + 1].split(',')} if '--only' in args else None
    keep = '--keep' in args

    mutants = []   # (id, rel, label, apply(text)->text or None)
    originals = {}

    def source(rel):
        if rel not in originals:
            originals[rel] = open(os.path.join(APP, rel)).read()
        return originals[rel]

    next_id = 1
    for (_, rel, old, new) in hand:
        if old.startswith('@'):
            # '@57' replaces the whole of line 57 (keeping its indentation) with `new`: for a statement that is awkward to quote.
            n = int(old[1:])
            line = source(rel).split('\n')[n - 1]
            indent = line[: len(line) - len(line.lstrip())]
            mutants.append((next_id, rel, f'{rel}:{n}: {line.strip()[:60]!r} -> {new[:40]!r}', ('LINE', n, indent + new)))
            next_id += 1
            continue
        n = source(rel).count(old)
        if n != 1:
            sys.exit(f'mutant for {rel}: old text found {n} times (must be exactly once): {old[:80]!r}')
        mutants.append((next_id, rel, f'{old[:60]!r} -> {new[:40]!r}', (old, new)))
        next_id += 1
    for (rel, n, line, mutated) in generated(gen):
        text = source(rel)
        lines = text.split('\n')
        lines[n - 1] = mutated
        mutants.append((next_id, rel, f'{rel}:{n}: {line.strip()[:70]!r} -> {mutated.strip()[:70]!r}', ('LINE', n, mutated)))
        next_id += 1
    if only:
        mutants = [m for m in mutants if m[0] in only]

    if '--count' in args:
        from collections import Counter
        print(len(mutants), 'mutants', dict(Counter(m[1] for m in mutants)))
        return

    work = queue.Queue()
    for m in mutants:
        work.put(m)
    results = {}
    lock = threading.Lock()
    copies = []

    def worker(i):
        dst = make_copy(i)
        copies.append(dst)
        code, out = run(['flutter', 'test', '--no-pub', *tests], dst)
        if code != 0:
            with lock:
                results['baseline-%d' % i] = out[-1500:]
            return
        while True:
            try:
                mid, rel, label, how = work.get_nowait()
            except queue.Empty:
                return
            path = os.path.join(dst, rel)
            original = originals[rel]
            try:
                if how[0] == 'LINE':
                    lines = original.split('\n')
                    lines[how[1] - 1] = how[2]
                    mutated = '\n'.join(lines)
                else:
                    mutated = original.replace(how[0], how[1], 1)
                open(path, 'w').write(mutated)
                code, out = run(['flutter', 'test', '--no-pub', *tests], dst)
            finally:
                open(path, 'w').write(original)
            if code == 0:
                status = 'SURVIVED'
            elif re.search(r'Error: |Compilation failed|Failed to load', out) and 'Some tests failed' not in out and 'Expected:' not in out:
                status = 'INVALID'
            elif code == 124:
                status = 'KILLED'   # a hang is noticed too, but say so
                label += '  (timeout)'
            else:
                status = 'KILLED'
            with lock:
                results[mid] = (status, label)
                if len(results) % 10 == 0:
                    print(f'  ... {len(results)} of {len(mutants)} done', flush=True)
                if status != 'KILLED':
                    print(f'  {mid:>4} {status:<8} {label}', flush=True)

    print(f'{len(mutants)} mutants, {jobs} workers; building copies and the baseline ...', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        list(pool.map(worker, range(1, jobs + 1)))

    bad = {k: v for k, v in results.items() if isinstance(k, str)}
    if bad:
        for k, v in bad.items():
            print(k, 'baseline failed:\n', v)
    if not keep:
        for c in copies:
            shutil.rmtree(c, ignore_errors=True)
    done = {k: v for k, v in results.items() if not isinstance(k, str)}
    killed = sum(1 for v in done.values() if v[0] == 'KILLED')
    survived = sorted(k for k, v in done.items() if v[0] == 'SURVIVED')
    invalid = sorted(k for k, v in done.items() if v[0] == 'INVALID')
    print(f'\n{len(done)} of {len(mutants)} run: {killed} killed, {len(survived)} survived {survived}, {len(invalid)} did not compile {invalid}')
    sys.exit(1 if bad or survived else 0)


if __name__ == '__main__':
    main()
