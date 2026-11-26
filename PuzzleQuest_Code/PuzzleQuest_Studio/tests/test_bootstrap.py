"""Startup regression tests that do not require pip network access."""
from pathlib import Path
import subprocess

import bootstrap


def test_missing_pillow_triggers_install_into_same_venv(monkeypatch, tmp_path):
    interpreter = tmp_path / '.venv' / 'bin' / 'python'
    calls = []
    probes = iter([False, True])
    monkeypatch.setattr(bootstrap, 'venv_python', lambda: interpreter)
    monkeypatch.setattr(bootstrap, 'create_environment', lambda exe: calls.append(('create', exe)))
    monkeypatch.setattr(bootstrap, 'dependencies_available', lambda exe: next(probes))
    monkeypatch.setattr(bootstrap, 'run_checked', lambda cmd, reason: calls.append(('install', cmd, reason)))
    assert bootstrap.ensure_ready() == interpreter
    assert calls[0] == ('create', interpreter)
    assert calls[1][0] == 'install'
    assert calls[1][1][0] == str(interpreter)
    assert calls[1][1][1:4] == ['-m', 'pip', 'install']
    assert calls[1][1][-1] == str(bootstrap.REQUIREMENTS)


def test_packages_already_present_skip_pip(monkeypatch, tmp_path):
    interpreter = tmp_path / '.venv' / 'bin' / 'python'
    monkeypatch.setattr(bootstrap, 'venv_python', lambda: interpreter)
    monkeypatch.setattr(bootstrap, 'create_environment', lambda exe: None)
    monkeypatch.setattr(bootstrap, 'dependencies_available', lambda exe: True)
    monkeypatch.setattr(bootstrap, 'run_checked', lambda *args: (_ for _ in ()).throw(AssertionError('unexpected pip')))
    assert bootstrap.ensure_ready() == interpreter


def test_failed_dependency_install_returns_error_and_does_not_launch(monkeypatch, tmp_path):
    interpreter = tmp_path / '.venv' / 'bin' / 'python'
    monkeypatch.setattr(bootstrap, 'venv_python', lambda: interpreter)
    monkeypatch.setattr(bootstrap, 'create_environment', lambda exe: None)
    monkeypatch.setattr(bootstrap, 'dependencies_available', lambda exe: False)
    def fail_install(*args):
        raise bootstrap.StartupError('Dependency installation failed')
    monkeypatch.setattr(bootstrap, 'run_checked', fail_install)
    monkeypatch.setattr(subprocess, 'call', lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError('GUI must not open')))
    assert bootstrap.main([]) == 1


def test_partial_venv_does_not_get_silently_overwritten(monkeypatch, tmp_path):
    env = tmp_path / '.venv'
    env.mkdir()
    monkeypatch.setattr(bootstrap, 'ENV_DIR', env)
    try:
        bootstrap.create_environment(env / 'bin' / 'python')
    except bootstrap.StartupError as exc:
        assert 'Rename or delete ONLY' in str(exc)
    else:
        raise AssertionError('Partial environment should be rejected')
