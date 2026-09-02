# Terminal multiplexers: Screen tmux

The Terminal multiplexers such as `Screen` and `tmux` allow you run `multiple terminal sessions` inside a single 
terminal window (or SSH connection), and **most importantly** `detach from them so the programs keep running even after you disconnect`.

Think of them as a way to:

- Have several “virtual terminals” inside one window
- Switch between them instantly
- Leave long-running processes alive after you close your laptop or lose the SSH connection
- Come back later and pick up exactly where you left off

## Why people use them

- `Long-running tasks`: Compiling large projects, training ML models, data processing, package upgrades, backups, etc. You can start the job, detach, and come back hours (or days) later.
- `Unstable connections`: Working over flaky Wi-Fi, mobile data, or long-distance SSH. Disconnecting no longer kills your work.
- `Multiple concurrent tasks`: Monitor logs in one pane, edit code in another, run tests in a third — all inside one terminal window.
- `Server administration`: Keep persistent monitoring sessions, interactive shells, or debug environments running 24/7.
- `Pair programming / collaboration`: (Especially Screen) Multiple people can attach to the same session and see the same terminal.

## Screen quick start

```shell
sudo apt update
sudo apt install screen

screen --version

# create a new session
screen -S longjob
# run your commands...
# Ctrl+a d   ← detach
# later:

# re-attach to a session
screen -r longjob
```

full command list of Screen

| Action                     | Command / Keybinding             |
|----------------------------|----------------------------------|
| Start a new session        | screen                           |
| Start a named session      | screen -S mysession              |
| List sessions              | screen -ls                       |
| Attach to a session        | screen -r or screen -r mysession |
| Detach (leave running)     | Ctrl+a then d                    |
| Create new window          | Ctrl+a then c                    |
| Next / previous window     | Ctrl+a then n / p                |
| Switch to window by number | Ctrl+a then 0–9                  |
| List windows               | "Ctrl+a then """                 |
| Kill current window        | Ctrl+a then k                    |
| Split horizontally         | Ctrl+a then S                    |
| Split vertically           | Ctrl+a then `                    |
| Switch between regions     | Ctrl+a then Tab                  |
| Help (all keybindings)     | Ctrl+a then ?                    |
| Quit everything            | Ctrl+a then \|                   |

> Pro tip: Always name your sessions (-S). It makes life much easier when you have several.
> 

## Tmux quick start

```shell
sudo apt install tmux
tmux                    # start
tmux new -s mysession   # named session
tmux ls
tmux attach -t mysession
```

Keybindings (default prefix is Ctrl+b):

- Ctrl+b d → detach
- Ctrl+b c → new window
- Ctrl+b % → vertical split
- Ctrl+b " → horizontal split
- Ctrl+b arrow keys → move between panes