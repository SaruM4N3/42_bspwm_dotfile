# 42_bspwm_dotfile

A different way to see the world in 42 cluster, everyone’s hate gnome.

## Credits

This dotfile setup was originally taken from [gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles) and then modified almost completely to work on a 42-based machine, especially on Ubuntu GNOME.

## About

This repository contains my personal desktop configuration, installer scripts, and cleanup tools for a customized Linux setup.

It is no longer a direct copy of the original project: most parts were adapted, rewritten, or replaced to fit my workflow and system requirements on Ubuntu GNOME.

## Notes

- Original inspiration: [gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles).
- Using junest to avoid any sudo issues(it's fakeroot system) [fsquillace/junest](https://github.com/fsquillace/junest).
- This version has been heavily modified for my own use.
- It is designed around the 42Lyon Ubuntu GNOME environment and related setup scripts(you may have to modify it a lot to make it work on your machine).

## Install

From a GNOME terminal, run `./install.sh`. A window opens: pick install,
update, fresh reinstall or uninstall, choose your terminal / editor / browser /
rice, check the summary, and the install runs in a terminal inside the window
with a progress bar (log saved to `~/.BspwmLogs/install.log`).

The window uses the host's python3 with GTK 3 + VTE (Ubuntu ships both). Without
a display or without them, or with `./install.sh --cli`, the same questions are
asked in the terminal instead.

## Update

Already installed? Quit bspwm (back to GNOME), then run `./install.sh --update`
(or plain `./install.sh` and pick "Update"). It pulls the latest version,
deploys the new dotfiles and scripts, keeps your settings (Rice Settings,
keybinds, picom, wallpaper, browser/editor choices) and installs only the
packages the new version adds. No junest setup, no package upgrade.

## Uninstall

Use the provided `uninstall_all.sh` script to remove the installed configuration and related files.
