"""Shared isolated semantic-mutation execution. No working source is modified."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import uuid


def classify(exit_code, output, suite, expected, baseline_exit=0, expected_case_line=None):
    if baseline_exit != 0 or exit_code is None:
        return "INVALID"
    if exit_code == 0:
        return "SURVIVED"
    # Only the FIRST error, from the named test assertion, may prove detection.
    # A later stack frame or a marker echoed in stdout is not an assertion.
    lines = output.replace('\\', '/').splitlines()
    errors = [s for s in lines if re.search(r':\d+: ', s)]
    if not errors:
        return "INVALID"
    first = errors[0]
    if any(s in first for s in ('SyntaxError', 'attempt to call', 'attempt to index', 'Failed to resolve', 'error parsing')):
        return "INVALID"
    if expected_case_line is not None:
        sites = re.findall(r"tests/" + re.escape(suite) + r"/run(?:\.luau)?', Line (\d+)", output.replace('\\', '/'))
        if not sites or int(sites[-1]) != expected_case_line:
            return "INVALID"
    return "KILLED" if re.search(r'tests/' + re.escape(suite) + r'/run(?:\.luau)?:\d+: ', first) and expected in first else "INVALID"


def execute(lune, workspace, suite, timeout):
    command = [str(lune), 'run', f'tests/{suite}/run.luau']
    try:
        result = subprocess.run(command, cwd=workspace, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=timeout)
        return {'command': command, 'exitCode': result.returncode, 'output': result.stdout + result.stderr}
    except subprocess.TimeoutExpired as exc:
        return {'command': command, 'exitCode': None, 'output': 'TIMEOUT: ' + str(exc)}


def source_hashes(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((root / 'src').rglob('*.luau'))}


def run_mutations(root, cases, report_name, timeout=180):
    root = Path(root).resolve()
    manifest = json.loads((root / 'tools/toolchain.json').read_text(encoding='utf-8'))
    lune = root / '.tools' / ('lune-' + manifest['lune']['version']) / 'lune.exe'
    assert lune.is_file(), 'Manifest-selected Lune is missing'
    assert hashlib.sha256(lune.read_bytes()).hexdigest() == manifest['lune']['executableSha256'], 'Lune checksum mismatch'
    before = source_hashes(root)
    base = root / 'build' / (report_name + '-' + uuid.uuid4().hex[:8])
    base.mkdir(parents=True)
    rows = []
    for case in cases:
        target = base / case['name']
        for directory in ('src', 'tests', 'docs/reference_data'):
            shutil.copytree(root / directory, target / directory, ignore=shutil.ignore_patterns('__pycache__'))
        (target / 'build').mkdir()
        baseline = execute(lune, target, case['suite'], timeout)
        originals, fault_error = {}, None
        for relative, old, new in case['faults']:
            path = target / relative
            original = path.read_bytes()
            originals.setdefault(path, original)
            text = path.read_text(encoding='utf-8')
            if text.count(old) != 1:
                fault_error = f'INVALID_FAULT_ANCHOR: {relative}: {text.count(old)}'
                break
            path.write_text(text.replace(old, new), encoding='utf-8')
        negative = execute(lune, target, case['suite'], timeout) if not fault_error else {'exitCode': None, 'output': fault_error, 'command': []}
        for path, original in originals.items():
            path.write_bytes(original)
        # The same test AND fixture must pass after the fault is removed.
        corrected = execute(lune, target, case['suite'], timeout)
        state = classify(negative['exitCode'], negative['output'], case['suite'], case['expectedFailure'], baseline['exitCode'], case.get('expectedCaseLine'))
        if corrected['exitCode'] != 0:
            state = 'INVALID'
        for label, result in (('baseline', baseline), ('mutant', negative), ('corrected', corrected)):
            log = target / 'build' / (label + '.txt')
            log.write_text(result.pop('output'), encoding='utf-8')
            result['log'] = str(log.relative_to(root))
        text = (root / negative['log']).read_text(encoding='utf-8')
        failure = next((s for s in text.splitlines() if re.search(r':\d+: ', s)), None)
        row = {**case, 'state': state, 'baseline': baseline, 'mutant': negative, 'corrected': corrected,
               'failingAssertion': failure,
               'testSha256': hashlib.sha256((root / f"tests/{case['suite']}/run.luau").read_bytes()).hexdigest(),
               'sourceSha256': {p: hashlib.sha256((root/p).read_bytes()).hexdigest() for p,_,_ in case['faults']}}
        rows.append(row)
        print(case['name'] + ': ' + state, flush=True)
        report = {'status': 'PASS' if all(r['state'] == 'KILLED' for r in rows) else 'FAIL',
                  'complete': len(rows) == len(cases), 'toolchain': manifest['lune'],
                  'scope': f'{len(cases)} selected semantic mutations; not exhaustive coverage', 'mutants': rows}
        (root / 'build' / (report_name + '.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    assert source_hashes(root) == before, 'Working source changed during mutation execution'
    assert report['status'] == 'PASS' and report['complete'], 'Mutation evidence incomplete: ' + report_name
    return report
