# CS:GO Standalone Dedicated Server Setup Script

An automated setup script for hosting a dedicated server on the new standalone CS:GO release (App ID 4465480) on Ubuntu Linux.

Valve re-released CS:GO as a separate, unlisted app on Steam on March 3, 2026. There are no official servers, no working server browser, and no updates — community servers are the only way to play online. This script handles the full installation and configuration so players can connect.

## What It Does

- Installs CS:GO dedicated server files via SteamCMD (app 740)
- Fixes the bundled `libgcc_s.so.1` conflict that prevents the server from starting on modern Ubuntu
- Patches `steam_appid.txt` and `csgo/steam.inf` to the new app ID (4465480)
- Installs MetaMod:Source 1.11 and SourceMod 1.11 (correct Source 1 builds)
- Downloads, compiles, and installs the [NoLobbyReservation](https://github.com/eldoradoel/NoLobbyReservation) plugin (required for players to connect)
- Creates a basic `server.cfg`
- Generates a `start.sh` launch script

## Requirements

- Ubuntu 20.04 or later
- ~30 GB free disk space
- Ports 27015 UDP and TCP open
- SteamCMD installed
- A Steam account that owns CS:GO/CS2 (for GSLT generation)

### Install SteamCMD

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steamcmd lib32gcc-s1 lib32stdc++6 -y
```

## Usage

```bash
chmod +x setup_csgo_server.sh
./setup_csgo_server.sh
```

After the script finishes:

1. Generate a GSLT at https://steamcommunity.com/dev/managegameservers using App ID **4465480**
2. Edit `start.sh` and paste your GSLT token into the `GSLT=""` line
3. Change the `rcon_password` in `csgo/cfg/server.cfg`
4. Start the server:

```bash
screen -S csgo
./start.sh
```

Players connect via the CS:GO developer console: `connect YOUR_SERVER_IP:27015`

## Configuring for Your Server

The script defaults to the following paths:

| Variable | Default | Location |
|---|---|---|
| `INSTALL_DIR` | `/home/steam/csgo` | setup_csgo_server.sh, line 9 |
| `STEAMCMD` | `/usr/games/steamcmd` | setup_csgo_server.sh, line 10 |
| `INSTALL_DIR` | `/home/steam/csgo` | start.sh (generated), line 14 |

If you're running as a different user or want to install to a different directory, edit these variables at the top of `setup_csgo_server.sh` **before running it**. The `start.sh` that gets generated will inherit the `INSTALL_DIR` you set.

To find where your SteamCMD is installed:

```bash
which steamcmd
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Server crashes with "GCC_7.0.0 not found" | The script handles this, but if running manually: `mv bin/libgcc_s.so.1 bin/libgcc_s.so.1.bak` |
| Players instantly disconnect | Verify NoLobbyReservation is loaded: type `sm plugins list` in the server console |
| RCON not working remotely | Open TCP port 27015 in your firewall (not just UDP) |

## Credits

- [NoLobbyReservation](https://github.com/eldoradoel/NoLobbyReservation) by vanz666 / eldoradoel
- [MetaMod:Source](https://www.sourcemm.net/) by AlliedModders
- [SourceMod](https://www.sourcemod.net/) by AlliedModders

## License

This script is provided as-is with no warranty. Do whatever you want with it.
