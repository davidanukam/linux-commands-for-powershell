# Linux commands in PowerShell

`ls -la` fails in PowerShell because `ls` is an alias for `Get-ChildItem`. That cmdlet has no `-la` parameter. The same thing happens to `rm`, `cp`, `grep`, `curl`, and the rest of the usual names. An alias can rename a command. It cannot teach a PowerShell cmdlet the flags of the Unix program.

This folder's `LinuxCommands.ps1` loads the real programs instead:

- [Coreutils for Windows](https://github.com/microsoft/coreutils) supplies `ls`, `cp`, `mv`, `rm`, `mkdir`, `cat`, `grep`, `find`, `xargs`, `head`, `tail`, `wc`, `cut`, `sort`, `uniq`, `tr`, `tee`, `touch`, and the other everyday utilities. Each one accepts its normal `--help` and flags.
- If MSYS2 is installed, `sed`, `awk`, and `less` come from there.
- If Git for Windows is installed, `diff` comes from `Git\usr\bin`.

The script puts Coreutils ahead of `C:\Windows\System32`, then removes a PowerShell alias only when a real program with that name is available. `grep -n`, `mkdir -p`, `rm -r`, and `ls -la` then run the Unix tools.

## Setup

Clone the repo and run the installer. It installs [Coreutils](https://github.com/microsoft/coreutils) and [Glow](https://github.com/charmbracelet/glow) with winget, then adds this clone to your Windows PowerShell 5.1 and PowerShell 7 profiles.

```powershell
git clone <repo-url>
cd linux-commands-for-powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Open a new PowerShell window after that. The installer changes your user `PATH` and profile, and an already-open window keeps the old ones.

```powershell
ls -la
glow README.md
```

PowerShell 7 is the better host. Coreutils' own startup hook, added when that package is installed, keeps quotes and globs intact and turns on `ls --color=auto`. Windows PowerShell 5.1 runs the same flags. It does not get that quoting hook.

To reload the profile in the current window:

```powershell
. $PROFILE
```

## Check

```powershell
Get-Command ls, grep, find, sed, diff
ls -la
grep -n pattern file.txt
mkdir -p some\nested\dir
```

`Get-Command ls` should point at `C:\Program Files\coreutils\cmd\ls.cmd`.

```powershell
pwsh -NoProfile -File .\Test-LinuxCommands.ps1
```

## Read Markdown in the terminal

`cat` and `less` print the file as it is stored, asterisks and backticks included. A Markdown renderer parses the file and draws headings, tables, and highlighted code in the terminal.

### Glow

[Glow](https://github.com/charmbracelet/glow) is the reader `Install.ps1` sets up on Windows. It can print one file or open a small browser for local Markdown. It can also fetch a README from GitHub.

Install on other systems:

- macOS or Linux, with Homebrew: `brew install glow`
- Ubuntu or Debian: add [Charm's APT repository](https://github.com/charmbracelet/glow#installation), then `sudo apt update && sudo apt install glow`
- Windows, if you are not using `Install.ps1`: `winget install charmbracelet.glow` or `scoop install glow`

```powershell
glow README.md
glow -p README.md
glow github.com/charmbracelet/glow
```

`glow README.md` prints the file. `glow -p` leaves it in a pager you can scroll.

### Leaf

[Leaf](https://leaf.rivolink.mg/) is a terminal previewer for longer reading. It draws Unicode tables, a table of contents, and full-text search, and it renders LaTeX math and Mermaid diagrams in the terminal.

```powershell
brew install leaf-markdown-viewer
npm install -g @rivolink/leaf
leaf README.md
```

### Already in the terminal

[Warp](https://docs.warp.dev/terminal/more-features/markdown-viewer/) opens `.md` and `.markdown` files as a rendered document in a split pane. A code block in that pane has a button that runs it in the active terminal.

PowerShell 6.1 and later includes `Show-Markdown`, which prints the file with VT100 formatting. Windows PowerShell 5.1 does not have this cmdlet.

```powershell
Show-Markdown README.md
```

### Which reader

| Tool | Style | Best for | What it adds |
| --- | --- | --- | --- |
| Glow | CLI and TUI | A quick look, including a remote README | GitHub fetch and its own styles |
| Leaf | Full-screen viewer | Long local documents | Mermaid diagrams and LaTeX math |
| Warp | Built into the app | Runbooks and scripts | Runs a code block from the preview |

## Commands that stay PowerShell

| You type | Still runs | Why |
| --- | --- | --- |
| `cd` | `Set-Location` | A separate program cannot change this shell's directory |
| `dir` | `Get-ChildItem` | Leaves a Windows listing next to Unix `ls` |
| `where` | `Where-Object` | `where { ... }` is PowerShell syntax. Windows `where.exe` is still there |
| `ps` | `Get-Process` | There is no useful `ps aux` in Coreutils |
| `kill` | `Stop-Process` | Windows has no POSIX signals. Use `Stop-Process` |
| `clear` | `Clear-Host` | Same job, already works |

`Sort-Object`, `Tee-Object`, `Start-Sleep`, `Invoke-WebRequest`, and `Compare-Object` are still there under those names. `sort`, `tee`, `sleep`, `curl`, and `diff` are the Unix programs.

## Limits

- `chmod`, `chown`, and `sudo` are not available. Windows uses ACLs, not Unix permission bits.
- PowerShell's escape character is a backtick, not a backslash. A literal quote inside a search is `` `" ``.
- Text files from Windows often use CRLF. `sort -u` and `uniq` can treat the trailing `\r` as part of the line. Save the file as LF, or strip `\r`, when that happens.
- Piping a PowerShell object into these programs sends text, not the original object. `Get-ChildItem | sort Name` is not Unix `sort`. Use `Sort-Object Name` for objects.
- `rm` is Unix `rm`. `rm -r` removes a directory. `rm -Recurse` is the old PowerShell flag and will not work.
