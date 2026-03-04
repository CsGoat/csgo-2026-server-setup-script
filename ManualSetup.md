# How to Host a Dedicated Server on the New Standalone CS:GO (App 4465480)

Valve quietly re-released Counter-Strike: Global Offensive as a standalone app on Steam (App ID 4465480) on March 3, 2026. This is the frozen 2023 build — no official matchmaking, no server browser, no updates. The only way to play online is through community servers.

This guide walks you through setting up a fully working dedicated server on Ubuntu Linux from scratch, including the fixes needed to get players connected.

---

## Prerequisites

- An Ubuntu server (20.04 or later) with root or sudo access
- At least 30 GB of free disk space
- Ports **27015 UDP and TCP** open in your firewall
- A Steam account that owns CS:GO / CS2
- SteamCMD installed

### Install SteamCMD if you haven't already

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steamcmd lib32gcc-s1 lib32stdc++6 -y
```

### Create a steam user (if you don't have one)

```bash
sudo useradd -m -s /bin/bash steam
sudo su - steam
```

---

## Step 1: Install the CS:GO Dedicated Server Files

The dedicated server is still downloaded using the original app ID 740 via SteamCMD.

```bash
steamcmd +force_install_dir /home/steam/csgo +login anonymous +app_update 740 validate +quit
```

This will download approximately 25 GB of server files.

---

## Step 2: Fix the libgcc Conflict

The server ships a bundled `libgcc_s.so.1` that conflicts with modern Ubuntu's system libraries. Without this fix, the server will fail to start with a `GCC_7.0.0 not found` error.

```bash
mv /home/steam/csgo/bin/libgcc_s.so.1 /home/steam/csgo/bin/libgcc_s.so.1.bak
```

---

## Step 3: Patch the App IDs for Standalone CS:GO

The server files ship with the old app IDs (730/740). You need to change them to **4465480** so the new standalone CS:GO client can connect.

### Patch steam_appid.txt

```bash
echo "4465480" > /home/steam/csgo/steam_appid.txt
```

### Patch steam.inf

```bash
sed -i 's/^appID=.*/appID=4465480/' /home/steam/csgo/csgo/steam.inf
```

---

## Step 4: Install MetaMod:Source

The NoLobbyReservation plugin (required for players to connect) needs MetaMod and SourceMod. You **must** use the Source 1 builds (1.11 branch), not the Source 2 / CS2 builds.

**Important:** The CS:GO dedicated server is a 32-bit process. You may see an `ELFCLASS64` error for the linux64 path in the server logs — this is normal. MetaMod still loads correctly via the 32-bit path.

```bash
cd /tmp
wget -O mmsource.tar.gz "https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1148-linux.tar.gz"
tar -xzf mmsource.tar.gz -C /home/steam/csgo/csgo/
rm mmsource.tar.gz
```

---

## Step 5: Install SourceMod

Again, use the Source 1 stable build (1.11 branch).

```bash
cd /tmp
wget -O sourcemod.tar.gz "https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6934-linux.tar.gz"
tar -xzf sourcemod.tar.gz -C /home/steam/csgo/csgo/
rm sourcemod.tar.gz
```

---

## Step 6: Install and Compile NoLobbyReservation

Without this plugin, players will be instantly disconnected when trying to connect. The new standalone CS:GO client tries to request a lobby reservation from Steam, which fails because there are no official servers. This plugin bypasses that check.

### Download the plugin source

```bash
cd /tmp
wget -O nolobby.zip "https://github.com/eldoradoel/NoLobbyReservation/archive/refs/heads/master.zip"
unzip -q -o nolobby.zip -d /tmp/nolobby
cp -r /tmp/nolobby/NoLobbyReservation-master/csgo/addons/sourcemod/* /home/steam/csgo/csgo/addons/sourcemod/
rm -rf /tmp/nolobby /tmp/nolobby.zip
```

### Compile the plugin

The repository only includes the `.sp` source code, not the compiled `.smx` plugin file. SourceMod includes a compiler, so compile it on the server.

```bash
cd /home/steam/csgo/csgo/addons/sourcemod/scripting
./spcomp nolobbyreservation.sp -o ../plugins/nolobbyreservation.smx
```

You should see a clean output with no errors — something like:

```
SourcePawn Compiler 1.11.0.6934
Code size:         7564 bytes
Data size:         7076 bytes
Stack/heap size:      17004 bytes
Total requirements:   31644 bytes
```

---

## Step 7: Generate a Game Server Login Token (GSLT)

A GSLT is required for players to connect from outside your local network.

1. Go to [https://steamcommunity.com/dev/managegameservers](https://steamcommunity.com/dev/managegameservers)
2. Enter App ID: **4465480**
3. Enter a memo (e.g. "csgo server")
4. Click **Create**
5. Copy the token — you'll need it for the start script

Your Steam account must own CS:GO/CS2 and have a phone number linked.

---

## Step 8: Create a server.cfg

```bash
cat > /home/steam/csgo/csgo/cfg/server.cfg << 'EOF'
hostname "CS:GO Server"
sv_password ""
rcon_password "changeme"
sv_cheats 0
sv_lan 0
sv_pure 0

// Rates
sv_minrate 128000
sv_maxrate 0
sv_mincmdrate 64
sv_maxcmdrate 128
sv_minupdaterate 64
sv_maxupdaterate 128

// Logging
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1

// Server behavior
mp_autoteambalance 1
mp_limitteams 2
sv_alltalk 0
mp_friendlyfire 0
mp_tkpunish 0
EOF
```

**Change `rcon_password` from `changeme` to something secure.**

---

## Step 9: Create a Start Script

```bash
cat > /home/steam/csgo/start.sh << 'EOF'
#!/bin/bash
# =============================================================================
# CS:GO Dedicated Server Start Script
# =============================================================================

# ---- PASTE YOUR GSLT TOKEN BETWEEN THE QUOTES BELOW ----
# Generate at: https://steamcommunity.com/dev/managegameservers
# Use App ID: 4465480
GSLT=""
# ---------------------------------------------------------

INSTALL_DIR="/home/steam/csgo"
SERVER_PORT="27015"
MAP="de_dust2"
GAME_TYPE="0"    # 0=classic, 1=gungame
GAME_MODE="0"    # 0=casual, 1=competitive (when type=0)

cd "$INSTALL_DIR"

if [ -z "$GSLT" ]; then
    echo "========================================"
    echo " WARNING: No GSLT set!"
    echo " Server will be LAN-only."
    echo " Edit start.sh and paste your GSLT token"
    echo " at the top of the file."
    echo "========================================"
    echo ""
fi

GSLT_ARG=""
if [ -n "$GSLT" ]; then
    GSLT_ARG="+sv_setsteamaccount $GSLT -net_port_try 1"
fi

./srcds_run \
    -game csgo \
    -console \
    -usercon \
    -port $SERVER_PORT \
    +game_type $GAME_TYPE \
    +game_mode $GAME_MODE \
    +mapgroup mg_active \
    +map $MAP \
    $GSLT_ARG
EOF

chmod +x /home/steam/csgo/start.sh
```

Open `start.sh` and paste your GSLT token into the `GSLT=""` line.

---

## Step 10: Start the Server

Use `screen` so the server keeps running after you disconnect from SSH.

```bash
screen -S csgo
cd /home/steam/csgo
./start.sh
```

To detach from screen without stopping the server: press `Ctrl+A` then `D`

To reattach later: `screen -r csgo`

---

## Step 11: Verify Everything is Working

Once the server finishes starting, type these commands in the server console:

```
meta list
```

You should see SourceMod listed.

```
sm plugins list
```

You should see "No Lobby Reservation" by vanz in the plugin list. If it's missing, something went wrong with the compile or file placement.

---

## How Players Connect

The in-game server browser does not work for the standalone CS:GO. Players must connect via the developer console.

1. Launch CS:GO (App 4465480)
2. Open the developer console (press `~`)
3. Type: `connect YOUR_SERVER_IP:27015`

---

## Troubleshooting

### Server crashes on start with "GCC_7.0.0 not found"
You missed Step 2. Rename the bundled libgcc: `mv /home/steam/csgo/bin/libgcc_s.so.1 /home/steam/csgo/bin/libgcc_s.so.1.bak`

### Players get instantly disconnected
Check that NoLobbyReservation is loaded with `sm plugins list` in the server console. If it's not listed, re-do Step 6.

### After one failed connect, the player can't connect to any server
This is a known CS:GO client bug. The lobby reservation cookie doesn't get cleared after a failed connection. The player needs to fully restart CS:GO and try again.

### "wrong ELF class: ELFCLASS64" in server logs
This is normal and harmless. The CS:GO server is 32-bit and ignores the 64-bit MetaMod binary. MetaMod loads correctly via the 32-bit path.

### Server shows "[META] Loaded 0 plugins"
You installed the wrong version of MetaMod or SourceMod. Make sure you're using the **1.11 branch** (Source 1), not the 2.0 branch (Source 2 / CS2).

### RCON doesn't work remotely
Make sure TCP port 27015 is open in your firewall, not just UDP. Also verify you set an `rcon_password` in `server.cfg`.

---

## Credits

- **NoLobbyReservation plugin** by [vanz666](https://github.com/vanz666/NoLobbyReservation), fork by [eldoradoel](https://github.com/eldoradoel/NoLobbyReservation) with updated signatures for the 2023 CS:GO build
- **MetaMod:Source** by [AlliedModders](https://www.sourcemm.net/)
- **SourceMod** by [AlliedModders](https://www.sourcemod.net/)
