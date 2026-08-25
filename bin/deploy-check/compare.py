#!/usr/bin/env python3
"""Diff two snapshot.rb captures and report what a deploy changed.

    python3 compare.py before.json after.json

Exit status is 1 when anything in the "must not change" set moved, so this can
gate a deploy in CI. Counts are reported but never fail the run - content changes
while a deploy is in flight.
"""
import json
import sys

# Keys where any change is a regression signal, not normal drift.
CRITICAL = ['available_works', 'consortia', 'profile_path', 'themes',
            'schema_classes', 'features']
# Reported for awareness; expected to move on their own.
INFORMATIONAL = ['counts', 'vocabularies', 'schema_version', 'sample_works',
                 'allowed_by_consortium', 'pending_migrations']


# Intended to move when the submodule is bumped.
EXPECTED_GLOBAL_CHANGES = ['hyrax_version', 'puma_version']


def errored(value):
    """A key the previous version could not even report cannot have regressed."""
    return isinstance(value, str) and value.startswith('ERROR:')


def main(before_path, after_path):
    before = json.load(open(before_path))
    after = json.load(open(after_path))
    problems, notes = [], []

    for key, bval in before.get('global', {}).items():
        aval = after.get('global', {}).get(key)
        if bval == aval:
            continue
        if key in EXPECTED_GLOBAL_CHANGES or errored(bval):
            notes.append(f'global.{key}: {bval!r} -> {aval!r}')
        else:
            problems.append(f'global.{key}: {bval!r} -> {aval!r}')

    btenants, atenants = before.get('tenants', {}), after.get('tenants', {})
    missing = sorted(set(btenants) - set(atenants))
    added = sorted(set(atenants) - set(btenants))
    if missing:
        problems.append(f'tenants disappeared: {missing}')
    if added:
        notes.append(f'tenants added: {added}')

    for name in sorted(set(btenants) & set(atenants)):
        b, a = btenants[name], atenants[name]
        if 'ERROR' in a and 'ERROR' not in b:
            problems.append(f'{name}: now erroring - {a["ERROR"]}')
            continue
        for key in CRITICAL:
            if b.get(key) == a.get(key):
                continue
            if errored(b.get(key)):
                notes.append(f'{name}.{key}: was unreadable before, now {a.get(key)!r}')
            else:
                problems.append(f'{name}.{key}: {b.get(key)!r} -> {a.get(key)!r}')
        for key in INFORMATIONAL:
            if b.get(key) != a.get(key):
                notes.append(f'{name}.{key} changed')
        # A work that had a thumbnail before and lost it is a derivative regression.
        bsamples = {s['id']: s for s in (b.get('sample_works') or []) if isinstance(s, dict)}
        asamples = {s['id']: s for s in (a.get('sample_works') or []) if isinstance(s, dict)}
        for wid, bs in bsamples.items():
            as_ = asamples.get(wid)
            if as_ and bs.get('has_thumbnail') and not as_.get('has_thumbnail'):
                problems.append(f'{name}: work {wid} lost its thumbnail')

    print(f'=== REGRESSIONS ({len(problems)}) ===')
    for p in problems:
        print('  FAIL', p)
    if not problems:
        print('  none - nothing in the must-not-change set moved')
    print(f'\n=== INFORMATIONAL ({len(notes)}) ===')
    for n in notes[:40]:
        print('  note', n)
    if len(notes) > 40:
        print(f'  ... and {len(notes) - 40} more')
    return 1 if problems else 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
