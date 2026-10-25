<p align="center">
  <img src="https://i.ibb.co/whQS4hgF/f56f84e7-c9f1-41c5-bb10-195ce00ec984.png" width="260" alt="AlwaysAudioFiles icon">
</p>

<h1 align="center">AlwaysAudioFiles</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ItzMeShadow999/AlwaysAudioFiles?style=flat-square&color=5865F2" alt="License"></a>
  <a href="https://github.com/ItzMeShadow999/AlwaysAudioFiles/stargazers"><img src="https://img.shields.io/github/stars/ItzMeShadow999/AlwaysAudioFiles?style=flat-square&color=5865F2" alt="Stars"></a>
  <a href="https://github.com/ItzMeShadow999/AlwaysAudioFiles/commits/main"><img src="https://img.shields.io/github/last-commit/ItzMeShadow999/AlwaysAudioFiles?style=flat-square&color=5865F2" alt="Last commit"></a>
  <a href="https://github.com/ItzMeShadow999/AlwaysAudioFiles/issues"><img src="https://img.shields.io/github/issues/ItzMeShadow999/AlwaysAudioFiles?style=flat-square&color=5865F2" alt="Issues"></a>
  <a href="https://github.com/Vencord/Vencord"><img src="https://img.shields.io/badge/Vencord-supported-5865F2?style=flat-square" alt="Vencord"></a>
  <a href="https://github.com/Equicord/Equicord"><img src="https://img.shields.io/badge/Equicord-supported-5865F2?style=flat-square" alt="Equicord"></a>
  <a href="#-quick-install"><img src="https://img.shields.io/badge/Installer-Windows-5865F2?style=flat-square&logo=windows&logoColor=white" alt="Installer"></a>
</p>

A [Vencord](https://github.com/Vencord/Vencord) / [Equicord](https://github.com/Equicord/Equicord) plugin that turns audio links into real file uploads.

When you send a message containing a direct link to an audio file, the plugin downloads the file and attaches it to your message, so it shows up with Discord's built-in audio player instead of a plain link.

## ▸ Features

- Detects direct links to common audio formats: mp3, wav, ogg, opus, m4a, aac, flac, wma, aiff, amr, weba, mka, midi, caf, ac3, ape, wv and more.
- Attaches one file per link, so several links in one message work.
- Optionally keeps the original link in the message next to the file.
- Optionally sends the message for you once the file is attached.
- Falls back to sending the plain link if the download fails. Just press Enter again.

## ▸ Settings

| Setting | Default | What it does |
| --- | --- | --- |
| Send link | Off | Keep the original link in the message along with the file |
| Auto send | On | Send the message automatically after attaching the file |

## ▸ Quick install

Windows only. Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/ItzMeShadow999/AlwaysAudioFiles/main/install.ps1 | iex
```

The installer will:

1. Ask whether you use Vencord or Equicord.
2. Install Git, Node.js and pnpm through winget if they are missing.
3. Clone the client, or use a source folder you already have.
4. Download the plugin (`index.tsx` and `native.ts`) into `src/userplugins/alwaysAudioFiles/`.
5. Close Discord, build, inject, enable **AlwaysAudioFiles** and relaunch Discord.

Press Ctrl+R in Discord if the plugin does not show up right away.

For unattended runs, set `AAF_CLIENT` (`vencord` or `equicord`), `AAF_DIR` (source folder) and `AAF_YES=1` before running the command.

## ▸ Install

AlwaysAudioFiles is a user plugin. You need a [Vencord development setup](https://docs.vencord.dev/installing/custom-plugins/).

1. Clone Vencord and go into the folder.
2. Put this plugin at `src/userplugins/alwaysAudioFiles/`, with both `index.tsx` and `native.ts` inside.
3. Build and inject:
   ```
   pnpm install
   pnpm build
   pnpm inject
   ```
4. Restart Discord and enable **AlwaysAudioFiles** in Settings > Plugins.

For Equicord, put it in `src/userplugins/alwaysAudioFiles/` in the Equicord source and build the same way.

## ▸ How it works

The plugin listens for the Enter key in the message box. If the text contains direct audio links, it stops the normal send and asks the native side of the plugin to download each file. The files are then pasted into the message box as attachments, and the message is sent if **Auto send** is on.

The download happens in `native.ts`, which runs in the Electron main process so it is not blocked by CORS. It is locked down on purpose:

- Only `http` and `https` links that end in a known audio extension are allowed.
- Hosts that resolve to private or local addresses are blocked, including after redirects.
- Up to 5 redirects are followed, each one checked again.
- Files larger than 25 MB are rejected.
- Responses that report a text content type are rejected, and a missing audio type is filled in from the file extension.

## ▸ Notes

- Only direct links to audio files are converted. Links to pages that merely contain a player are left alone.
- Discord's own upload size limit still applies to the attached file.
- If a download fails, the error is logged in the console and pressing Enter again sends the plain link.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
