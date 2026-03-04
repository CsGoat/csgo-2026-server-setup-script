#!/bin/bash
# =============================================================================
# CS:GO Dedicated Server Setup Script (for new standalone CS:GO - App 4465480)
# Run as the 'steam' user on Ubuntu
# =============================================================================

set -e

INSTALL_DIR="/home/steam/csgo"
STEAMCMD="/usr/games/steamcmd"  # adjust if your steamcmd is elsewhere

# --- CONFIGURATION ---
SERVER_PORT="27015"
# ---------------------

echo "============================================"
echo " CS:GO Dedicated Server Setup"
echo " Install dir: $INSTALL_DIR"
echo "============================================"

# -----------------------------------------------
# Step 1: Install CS:GO Dedicated Server via SteamCMD
# -----------------------------------------------
echo ""
echo "[Step 1/7] Installing CS:GO dedicated server files (app 740)..."
$STEAMCMD +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 740 validate +quit

# -----------------------------------------------
# Step 1b: Fix libgcc conflict
# -----------------------------------------------
echo ""
echo "[Step 1b] Fixing bundled libgcc_s.so.1 conflict..."
if [ -f "$INSTALL_DIR/bin/libgcc_s.so.1" ]; then
    mv "$INSTALL_DIR/bin/libgcc_s.so.1" "$INSTALL_DIR/bin/libgcc_s.so.1.bak"
    echo "  -> Renamed bin/libgcc_s.so.1 to .bak (system lib will be used instead)"
else
    echo "  -> bin/libgcc_s.so.1 not found, skipping"
fi

# -----------------------------------------------
# Step 2: Patch App IDs for new standalone CS:GO
# -----------------------------------------------
echo ""
echo "[Step 2/7] Patching app IDs for standalone CS:GO (4465480)..."

# Patch steam_appid.txt in root
echo "4465480" > "$INSTALL_DIR/steam_appid.txt"
echo "  -> steam_appid.txt set to 4465480"

# Patch steam.inf in csgo/ folder
STEAM_INF="$INSTALL_DIR/csgo/steam.inf"
if [ -f "$STEAM_INF" ]; then
    sed -i 's/^appID=.*/appID=4465480/' "$STEAM_INF"
    echo "  -> csgo/steam.inf appID set to 4465480"
else
    echo "  !! WARNING: csgo/steam.inf not found"
fi

# -----------------------------------------------
# Step 3: Install MetaMod:Source 1.11 (Source 1, Linux)
# -----------------------------------------------
echo ""
echo "[Step 3/7] Installing MetaMod:Source 1.11..."
cd /tmp
wget -q -O mmsource.tar.gz "https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1148-linux.tar.gz"
tar -xzf mmsource.tar.gz -C "$INSTALL_DIR/csgo/"
rm mmsource.tar.gz
echo "  -> MetaMod installed to $INSTALL_DIR/csgo/addons/metamod/"

# -----------------------------------------------
# Step 4: Install SourceMod 1.11 (Source 1, Linux)
# -----------------------------------------------
echo ""
echo "[Step 4/7] Installing SourceMod 1.11..."
cd /tmp
wget -q -O sourcemod.tar.gz "https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6934-linux.tar.gz"
tar -xzf sourcemod.tar.gz -C "$INSTALL_DIR/csgo/"
rm sourcemod.tar.gz
echo "  -> SourceMod installed to $INSTALL_DIR/csgo/addons/sourcemod/"

# -----------------------------------------------
# Step 5: Install NoLobbyReservation plugin
# -----------------------------------------------
echo ""
echo "[Step 5/7] Installing NoLobbyReservation plugin..."
cd /tmp
wget -q -O nolobby.zip "https://github.com/eldoradoel/NoLobbyReservation/archive/refs/heads/master.zip"
unzip -q -o nolobby.zip -d /tmp/nolobby

# Copy plugin files into the sourcemod directory structure
cp -r /tmp/nolobby/NoLobbyReservation-master/csgo/addons/sourcemod/* "$INSTALL_DIR/csgo/addons/sourcemod/"
rm -rf /tmp/nolobby /tmp/nolobby.zip

# Compile the plugin (repo only ships source .sp, not compiled .smx)
cd "$INSTALL_DIR/csgo/addons/sourcemod/scripting"
./spcomp nolobbyreservation.sp -o ../plugins/nolobbyreservation.smx
echo "  -> NoLobbyReservation plugin compiled and installed"

# -----------------------------------------------
# Step 6: Create server.cfg
# -----------------------------------------------
echo ""
echo "[Step 6/7] Creating server.cfg..."
mkdir -p "$INSTALL_DIR/csgo/cfg"
cat > "$INSTALL_DIR/csgo/cfg/server.cfg" << 'EOF'
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
echo "  -> server.cfg created (CHANGE YOUR RCON PASSWORD)"

# -----------------------------------------------
# Step 7: Create start script
# -----------------------------------------------
echo ""
echo "[Step 7/7] Creating start script..."
cat > "$INSTALL_DIR/start.sh" << STARTEOF
#!/bin/bash
# =============================================================================
# CS:GO Dedicated Server Start Script
# =============================================================================

# ---- PASTE YOUR GSLT TOKEN BETWEEN THE QUOTES BELOW ----
# Generate at: https://steamcommunity.com/dev/managegameservers
# Use App ID: 4465480
GSLT=""
# ---------------------------------------------------------

INSTALL_DIR="$INSTALL_DIR"
SERVER_PORT="27015"
MAP="de_dust2"
GAME_TYPE="0"    # 0=classic, 1=gungame
GAME_MODE="0"    # 0=casual, 1=competitive (when type=0)

cd "\$INSTALL_DIR"

if [ -z "\$GSLT" ]; then
    echo "========================================"
    echo " WARNING: No GSLT set!"
    echo " Server will be LAN-only."
    echo " Edit start.sh and paste your GSLT token"
    echo " at the top of the file."
    echo "========================================"
    echo ""
fi

GSLT_ARG=""
if [ -n "\$GSLT" ]; then
    GSLT_ARG="+sv_setsteamaccount \$GSLT -net_port_try 1"
fi

./srcds_run \\
    -game csgo \\
    -console \\
    -usercon \\
    -port \$SERVER_PORT \\
    +game_type \$GAME_TYPE \\
    +game_mode \$GAME_MODE \\
    +mapgroup mg_active \\
    +map \$MAP \\
    \$GSLT_ARG
STARTEOF
chmod +x "$INSTALL_DIR/start.sh"
echo "  -> start.sh created"

# -----------------------------------------------
# Done
# -----------------------------------------------
echo ""
echo "============================================"
echo " SETUP COMPLETE"
echo "============================================"
echo ""
echo " Install location:  $INSTALL_DIR"
echo ""
echo " BEFORE YOU START:"
echo "  1. Generate a GSLT at https://steamcommunity.com/dev/managegameservers"
echo "     Use App ID: 4465480"
echo ""
echo "  2. Edit $INSTALL_DIR/csgo/cfg/server.cfg"
echo "     Change rcon_password from 'changeme'"
echo ""
echo "  3. Edit $INSTALL_DIR/start.sh"
echo "     Paste your GSLT token into the GSLT variable"
echo ""
echo "  4. Start the server:"
echo "     cd $INSTALL_DIR"
echo "     ./start.sh"
echo ""
echo "  5. Players connect via console:"
echo "     connect YOUR_SERVER_IP:$SERVER_PORT"
echo ""
echo "  6. Verify plugins loaded in server console:"
echo "     meta list"
echo "     sm plugins list"
echo "============================================"
