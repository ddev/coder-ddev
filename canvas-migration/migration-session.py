"""Attach to a dashboard-owned conversation without ever starting Claude."""
import json
import os
from pathlib import Path
import subprocess


def main():
    result = subprocess.run(['tmux', 'list-sessions', '-F', '#{session_name}'],
                            capture_output=True, text=True)
    sessions = sorted(name for name in result.stdout.splitlines()
                      if name.startswith('dashboard-migration-')
                      and name.removeprefix('dashboard-migration-').isdecimal())
    if not sessions:
        print('No migration session is open. Start or retry a migration from the Migration Dashboard.')
        input('Press Enter to close. ')
        return
    titles = []
    for session in sessions:
        path = Path.home()/'.local/state/migration-dashboard'/session.removeprefix('dashboard-migration-')/'session.json'
        try:
            title = json.loads(path.read_text()).get('title', session)
        except (OSError, ValueError):
            title = session
        titles.append(''.join(c for c in str(title) if c.isprintable()))
    selected = 0
    if len(sessions) > 1:
        for index, title in enumerate(titles, 1):
            print(f'{index}) {title} ({sessions[index-1]})')
        while True:
            choice = input('Open migration session (Enter to cancel): ').strip()
            if not choice:
                return
            if choice.isdecimal() and 1 <= int(choice) <= len(sessions):
                selected = int(choice)-1
                break
            print('Choose one of the listed numbers.')
    print('Opening ' + titles[selected], flush=True)
    os.execvp('tmux', ['tmux', 'attach-session', '-t', '=' + sessions[selected]])


if __name__ == '__main__':
    try:
        main()
    except (EOFError, KeyboardInterrupt):
        pass
