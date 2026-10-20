# Neovim config — offline bundle

Everything this config needs is in the two archives next to this file: the config itself,
every lazy.nvim plugin, every Mason LSP server and debug adapter, and the compiled
treesitter parsers. Installing needs no network and no access to the original GitHub
account.

## Install

```sh
./install.sh
```

It checks this machine against `MANIFEST.txt`, moves anything already at
`~/.config/nvim` and `~/.local/share/nvim/{lazy,mason,site}` to `~/.nvim-backup-<timestamp>/`,
unpacks the archives into place, and reports which supporting tools are missing.

Then start `nvim` and check `:Lazy` (nothing pending), `:Mason` (servers present) and
`:checkhealth`.

## What is not in here, by design

* **Local state** — chat history, harpoon marks, telescope history, JavaQuest/GoQuest
  progress. Those belong to the machine the bundle came from.
* **System tools** — git, node, ripgrep, fd, go, maven, python, the AWS CLI. The installer
  lists which are missing and the `brew` line for each.
* **Two hardcoded paths** this config uses, which the installer checks for:
  * `~/.pyenv/versions/3.13.3/bin/black` — format-on-save for Python
    (`lua/plugins/formatting.lua`)
  * `/opt/homebrew/opt/openjdk@21/...` — jdtls and the Maven test runner
    (`lua/java/{init,jdtls,maven}.lua`)

  Install those, or edit the paths; nothing else in the config depends on them.
* **Sign-ins** — `:Copilot auth` and the `claude` CLI both need the network once.
* **awsdash** — `<leader>A` opens it if it is on PATH, and says so if it is not. It is a
  separate project; the keymap is inert without it.

## Updating later

Re-run the export on the source machine and run `install.sh` again; it backs up what is
there each time. The config keeps its git history, so `git log` works and you can commit
local changes.

The installer **removes the `origin` remote**, so an absent-minded `git push` from a work
machine cannot send anything to a personal account. To put it back:

```sh
git -C ~/.config/nvim remote add origin <url>
```

## If the bundle came from a different Mac architecture

The Mason binaries and the `.so` treesitter parsers are native code. The installer warns
when the platform does not match. If it does: install anyway, then `:Mason` to reinstall
the servers and `:TSEnsure` for the parsers — both need the network, but neither needs the
original GitHub account.
