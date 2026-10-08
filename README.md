# phone-preview

Lets your phone reach a local dev server over the same Wi-Fi, for a limited
time, then closes everything automatically.

## Use

1. **Arm** (once per boot): press **Super+Shift+Ctrl+P**, then confirm with your
   fingerprint. Press it again to disarm.
2. **Run** a server through phone-preview:

   ```bash
   phone-preview prototype-receipt-map -u '/?variant=A'   # static folder
   phone-preview -p 5173 -- vite --host --port 5173 --strictPort
   ```

   Scan the QR code, or open the printed URL on your phone.
3. **Stop** with Ctrl+C. The port closes when the server stops, and after
   2 hours at most (`-m` to shorten).

Other commands: `--status`, `--close [PORT]`, `--disarm`, `--help`.

## Add it to a project

phone-preview is installed once per machine. A project doesn't contain it;
it only calls it. Pick the mode that matches how the project is served.

**Static files** (plain HTML, a build output folder). Run it from the project
and pass the folder, never the repo root (it refuses folders containing `.git`):

```bash
phone-preview prototype-receipt-map            # serves that folder on port 8123
phone-preview -p 8200 dist -u '/about.html'    # other port, URL path to print
```

**A dev server** (Vite, Next, Astro, ...). Put the real command after `--`.
The server must listen on all interfaces (Vite: `--host`) and on exactly the
port given with `-p` (Vite: `--port N --strictPort`, so it fails instead of
silently picking another port). Add a script to `package.json` next to `dev`:

```json
"scripts": {
  "dev": "vite",
  "dev:phone": "phone-preview -p 5173 -- vite --host --port 5173 --strictPort"
}
```

Then `npm run dev` stays laptop-only and `npm run dev:phone` opens to the phone.
Other servers follow the same pattern, for example
`phone-preview -p 3000 -- next dev -H 0.0.0.0 -p 3000`.

Optional: add a line to the project's README so collaborators know that
`dev:phone` needs this tool, e.g. "`dev:phone` requires
[phone-preview](https://github.com/mibbo/phone-preview); others can use
`vite --host` and their own firewall setup."

## What is exposed

The firewall opens one TCP port, and only to devices in the subnet you're
on when you start it (for example `192.168.1.0/24`). What the phone can then
see is whatever the server on that port serves:

- static mode serves only the given folder. It refuses folders that contain
  `.git` or symlinks, and refuses `/` and `$HOME`;
- command mode serves what the dev server serves (Vite: the project, minus
  `.env` and certificate files by default).

When nothing is listening on the port, an open rule exposes nothing.

## Guardrails

| Situation | What closes the port |
|---|---|
| Ctrl+C, terminal closed, server exits | the script's exit trap |
| Forgotten | the 2 h time limit (with a warning 5 minutes before) |
| Script killed (`kill -9`) or frozen | a systemd timer, set when the port opens, at the expiry time |
| Laptop suspended past the deadline | the timer uses clock time, so it fires right after resume |
| Crash or power loss | `phone-preview-cleanup.service` at the next boot |
| Not armed / after a reboot | `phone-preview-fw open` refuses |

Every rule is tagged `phone-preview exp=<time>` in ufw. The helpers never
touch other rules.

## Parts

| File | Installed to | Runs as |
|---|---|---|
| `bin/phone-preview` | `~/.local/bin` (symlink) | you |
| `sbin/phone-preview-fw` | `/usr/local/sbin` (copy) | root, passwordless via sudoers; `open` only works when armed |
| `sbin/phone-preview-arm` | `/usr/local/sbin` (copy) | root via pkexec; always asks for authentication |
| `system/local.phone-preview.policy` | `/usr/share/polkit-1/actions` | text of the auth popup |
| `system/phone-preview-cleanup.service` | `/etc/systemd/system` | root, at boot |

The root parts are **copies** owned by root. If sudo ran a file your user can
edit, anything running as you could become root.

The remaining risk: while armed, a program running as your user (for example a
malicious npm package) could also open a port on your LAN for up to 2 h.
It gets nothing more than that.

## Install on a new Omarchy machine

Needs ufw (Omarchy default), python3, qrencode, and systemd. Fingerprint
arming needs `omarchy setup security fingerprint`; otherwise the popup asks
for your password.

```bash
git clone git@github.com:mibbo/phone-preview.git ~/sync/git/phone-preview
cd ~/sync/git/phone-preview
./install-user.sh        # command in ~/.local/bin + hotkey; no sudo
sudo ./install.sh        # root parts; read it first
phone-preview --status   # should print "armed: no", "ufw: active"
```

`install-user.sh` symlinks the command (so `git pull` updates it) and adds the
hotkey to `~/.config/hypr/bindings.lua`, with a backup. Running it again is
safe. `install.sh` writes your user name into the sudoers rule, so it works
for any account.

**After `git pull`:** if anything in `sbin/` or `system/` changed, run
`sudo ./install.sh` again. The root copies don't update themselves, on purpose.

**Uninstall:** `sudo ./uninstall.sh`, then remove `~/.local/bin/phone-preview`
and the hotkey lines from `~/.config/hypr/bindings.lua`.
