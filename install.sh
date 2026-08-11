#!/bin/bash

# =========================================================
# JTG PANEL - Ultimate Installation & Management Script
# Repository: https://github.com/JishnuTheGamer/Jtg
# Default Port: 6767
# =========================================================

set -o pipefail

# =========================================================
# COLORS
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# =========================================================
# CONFIG
# =========================================================

PANEL_NAME="JTG PANEL"
PANEL_DIR="Jtg"
PANEL_PROCESS="jtg-panel"
DEFAULT_PORT="6767"
GITHUB_REPO="https://github.com/JishnuTheGamer/Jtg.git"

# =========================================================
# BASIC HELPERS
# =========================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        echo -e "${RED}Root privileges are required.${NC}"
        return 1
    fi
}

pause_screen() {
    echo
    read -rp "$(echo -e "${GRAY}Press Enter to continue...${NC}")"
}

spinner() {
    local pid=$1
    local text="$2"
    local spin='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%c]${NC} %s" "${spin:i++%4:1}" "$text"
        sleep 0.1
    done

    printf "\r\033[K"
}

progress() {
    local text="$1"
    local duration="${2:-1}"
    local steps=30
    local delay
    delay=$(awk "BEGIN {print $duration/$steps}")

    echo
    echo -ne "  ${CYAN}$text${NC} "

    for ((i=0; i<=steps; i++)); do
        local filled=$((i * 2))
        local empty=$((steps * 2 - filled))

        printf "\r  ${CYAN}$text${NC} ["

        printf "%${filled}s" "" | tr ' ' '█'
        printf "%${empty}s" "" | tr ' ' '░'

        printf "] %3d%%" $((i * 100 / steps))
        sleep "$delay"
    done

    echo
}

log_info() {
    echo -e "  ${BLUE}●${NC} $1"
}

log_success() {
    echo -e "  ${GREEN}✔${NC} $1"
}

log_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "  ${RED}✖${NC} $1"
}

section() {
    echo
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =========================================================
# BANNER
# =========================================================

print_banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       ██╗████████╗ ██████╗     ██████╗  █████╗ ███╗   ██╗   ║
║       ██║╚══██╔══╝██╔════╝    ██╔════╝ ██╔══██╗████╗  ██║   ║
║       ██║   ██║   ██║         ██║  ███╗███████║██╔██╗ ██║   ║
║       ██║   ██║   ██║         ██║   ██║██╔══██║██║╚██╗██║   ║
║       ██║   ██║   ╚██████╗    ╚██████╔╝██║  ██║██║ ╚████║   ║
║       ╚═╝   ╚═╝    ╚═════╝     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝   ║
║                                                              ║
║                 PANEL MANAGEMENT SYSTEM                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "        ${DIM}Zero Shutter • Smooth Like Butter${NC}"
    echo
}

# =========================================================
# PANEL DIRECTORY
# =========================================================

get_panel_dir() {
    if [ -f "package.json" ]; then
        echo "."
    elif [ -d "$PANEL_DIR" ]; then
        echo "$PANEL_DIR"
    else
        echo ""
    fi
}

# =========================================================
# PM2 HELPERS
# =========================================================

pm2_available() {
    command_exists pm2 || npx --yes pm2 -v >/dev/null 2>&1
}

pm2_cmd() {
    if command_exists pm2; then
        pm2 "$@"
    else
        npx --yes pm2 "$@"
    fi
}

panel_exists() {
    pm2_cmd describe "$PANEL_PROCESS" >/dev/null 2>&1
}

panel_status() {
    if !panel_exists; then
        echo "NOT INSTALLED"
        return
    fi

    local status
    status=$(pm2_cmd jlist 2>/dev/null | grep -o '"name":"'"$PANEL_PROCESS"'".*"status":"[^"]*"' | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

    case "$status" in
        online)
            echo "ONLINE"
            ;;
        stopped|stopping)
            echo "OFFLINE"
            ;;
        errored)
            echo "ERROR"
            ;;
        *)
            echo "OFFLINE"
            ;;
    esac
}

# =========================================================
# STATUS DISPLAY
# =========================================================

show_status_line() {
    local status
    status=$(panel_status)

    case "$status" in
        ONLINE)
            echo -e "${GREEN}● ONLINE${NC}"
            ;;
        OFFLINE)
            echo -e "${RED}● OFFLINE${NC}"
            ;;
        ERROR)
            echo -e "${YELLOW}● ERROR${NC}"
            ;;
        *)
            echo -e "${GRAY}● NOT INSTALLED${NC}"
            ;;
    esac
}

show_dashboard_status() {
    local status
    status=$(panel_status)

    echo -e "  ${BOLD}Panel${NC}       : $(show_status_line)"
    echo -e "  ${BOLD}PM2${NC}         : $(
        if pm2_available; then
            echo -e "${GREEN}● READY${NC}"
        else
            echo -e "${RED}● MISSING${NC}"
        fi
    )"

    echo -e "  ${BOLD}Docker${NC}      : $(
        if command_exists docker; then
            if docker info >/dev/null 2>&1; then
                echo -e "${GREEN}● ONLINE${NC}"
            else
                echo -e "${YELLOW}● INSTALLED${NC}"
            fi
        else
            echo -e "${RED}● MISSING${NC}"
        fi
    )"

    echo -e "  ${BOLD}Node.js${NC}     : $(
        if command_exists node; then
            echo -e "${GREEN}● $(node -v)${NC}"
        else
            echo -e "${RED}● MISSING${NC}"
        fi
    )"

    echo -e "  ${BOLD}Port${NC}        : ${CYAN}${DEFAULT_PORT}${NC}"
}

# =========================================================
# SYSTEM INFORMATION
# =========================================================

system_info() {
    print_banner
    section "SYSTEM INFORMATION"

    local hostname_value
    local uptime_value
    local memory
    local disk
    local cpu

    hostname_value=$(hostname 2>/dev/null || echo "Unknown")
    uptime_value=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "Unknown")

    if command_exists free; then
        memory=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    else
        memory="Unavailable"
    fi

    if command_exists df; then
        disk=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
    else
        disk="Unavailable"
    fi

    if command_exists nproc; then
        cpu="$(nproc) cores"
    else
        cpu="Unknown"
    fi

    echo
    echo -e "  ${BOLD}Hostname${NC}    : $hostname_value"
    echo -e "  ${BOLD}CPU${NC}         : $cpu"
    echo -e "  ${BOLD}Memory${NC}      : $memory"
    echo -e "  ${BOLD}Disk${NC}        : $disk"
    echo -e "  ${BOLD}Uptime${NC}      : $uptime_value"
    echo -e "  ${BOLD}Kernel${NC}      : $(uname -r)"
    echo -e "  ${BOLD}Architecture${NC} : $(uname -m)"

    pause_screen
}

# =========================================================
# DEPENDENCY INSTALLATION
# =========================================================

install_dependencies() {
    section "SYSTEM DEPENDENCIES"

    if command_exists apt-get; then
        log_info "Detected Debian/Ubuntu based system."

        run_root dpkg --configure -a || true
        run_root apt-get install -f -y || true
        run_root apt-get update

        run_root apt-get install -y \
            curl \
            git \
            ca-certificates \
            build-essential \
            tar \
            xz-utils \
            gnupg \
            lsb-release \
            procps

    elif command_exists dnf; then
        log_info "Detected Fedora/RHEL based system."

        run_root dnf install -y \
            curl \
            git \
            ca-certificates \
            gcc-c++ \
            make \
            tar \
            xz

    elif command_exists yum; then
        log_info "Detected CentOS/RHEL based system."

        run_root yum install -y \
            curl \
            git \
            ca-certificates \
            gcc-c++ \
            make \
            tar \
            xz

    else
        log_warning "Unknown package manager."
        log_warning "Please make sure curl, git, build tools and tar are installed."
    fi

    log_success "System dependencies checked."
}

# =========================================================
# NODE.JS INSTALLATION
# =========================================================

install_node() {
    section "NODE.JS"

    local need_install=0

    if ! command_exists node; then
        need_install=1
    else
        local major
        local minor

        major=$(node -v | cut -d'.' -f1 | tr -d 'v')
        minor=$(node -v | cut -d'.' -f2)

        if [ "$major" -lt 20 ]; then
            need_install=1
        elif [ "$major" -eq 20 ] && [ "$minor" -lt 19 ]; then
            need_install=1
        fi
    fi

    if [ "$need_install" -eq 0 ]; then
        log_success "Node.js $(node -v) is ready."
        return 0
    fi

    log_info "Installing Node.js 22.x..."

    if command_exists apt-get; then
        if curl -fsSL https://deb.nodesource.com/setup_22.x | run_root bash -; then
            run_root apt-get install -y nodejs || true
        fi
    fi

    if command_exists node; then
        local current_major
        current_major=$(node -v | cut -d'.' -f1 | tr -d 'v')

        if [ "$current_major" -ge 22 ]; then
            log_success "Node.js $(node -v) installed."
            return 0
        fi
    fi

    log_warning "NodeSource installation did not provide Node.js 22."

    local arch
    local node_arch
    local node_version="22.13.1"

    arch=$(uname -m)

    case "$arch" in
        x86_64)
            node_arch="x64"
            ;;
        aarch64|arm64)
            node_arch="arm64"
            ;;
        armv7l)
            node_arch="armv7l"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    local node_dist="node-v${node_version}-linux-${node_arch}"
    local node_url="https://nodejs.org/dist/v${node_version}/${node_dist}.tar.xz"

    log_info "Downloading Node.js binary..."

    if curl -fsSL "$node_url" -o /tmp/node22.tar.xz; then
        run_root tar -xJf /tmp/node22.tar.xz \
            -C /usr/local \
            --strip-components=1

        rm -f /tmp/node22.tar.xz
    else
        log_error "Failed to download Node.js."
        return 1
    fi

    if command_exists node; then
        log_success "Node.js $(node -v) is ready."
    else
        log_error "Node.js installation failed."
        return 1
    fi
}

# =========================================================
# PM2 INSTALLATION
# =========================================================

install_pm2() {
    section "PM2"

    if command_exists pm2; then
        log_success "PM2 $(pm2 -v 2>/dev/null | head -1) is already installed."
        return 0
    fi

    if ! command_exists npm; then
        log_error "npm is not available."
        return 1
    fi

    log_info "Installing PM2 globally..."

    run_root npm install -g pm2

    if command_exists pm2; then
        log_success "PM2 installed successfully."
    else
        log_error "PM2 installation failed."
        return 1
    fi
}

# =========================================================
# DOCKER INSTALLATION
# =========================================================

install_docker() {
    section "DOCKER"

    if command_exists docker; then
        log_success "Docker is already installed."

        if command_exists systemctl; then
            run_root systemctl enable --now docker || true
        fi

        return 0
    fi

    log_info "Installing Docker..."

    if curl -fsSL https://get.docker.com | run_root sh; then
        log_success "Docker installed."
    else
        log_warning "Docker installation failed."
        return 1
    fi

    if command_exists systemctl; then
        run_root systemctl enable --now docker || true
    fi

    if command_exists docker; then
        log_success "Docker service configured."
    fi
}

# =========================================================
# CLONE / UPDATE REPOSITORY
# =========================================================

prepare_repository() {
    section "JTG PANEL SOURCE"

    local work_dir

    work_dir=$(get_panel_dir)

    if [ -n "$work_dir" ]; then
        log_info "Existing JTG panel directory detected: $work_dir"
        echo "$work_dir"
        return 0
    fi

    if [ -d "$PANEL_DIR" ]; then
        log_info "Jtg directory already exists."
        echo "$PANEL_DIR"
        return 0
    fi

    log_info "Cloning JTG Panel from GitHub..."

    if git clone "$GITHUB_REPO" "$PANEL_DIR"; then
        log_success "Repository cloned successfully."
        echo "$PANEL_DIR"
        return 0
    fi

    log_error "Failed to clone repository."
    return 1
}

# =========================================================
# ENVIRONMENT SETUP
# =========================================================

setup_environment() {
    local dir="$1"

    cd "$dir" || return 1

    section "ENVIRONMENT"

    if [ ! -f ".env" ]; then
        log_info "Creating .env file..."

        if [ -f ".env.example" ]; then
            cp ".env.example" ".env"
        else
            cat > .env <<EOF
PORT=${DEFAULT_PORT}
JWT_SECRET=$(head -c 48 /dev/urandom | base64 | tr -d '\n')
NODE_ENV=production
EOF
        fi

        log_success ".env created."
    else
        log_success ".env already exists."
    fi

    # Ensure port exists
    if ! grep -q '^PORT=' .env 2>/dev/null; then
        echo "PORT=${DEFAULT_PORT}" >> .env
    fi
}

# =========================================================
# PM2 ECOSYSTEM
# =========================================================

create_pm2_config() {
    local dir="$1"

    cd "$dir" || return 1

    if [ -f "ecosystem.config.cjs" ]; then
        log_success "PM2 configuration already exists."
        return 0
    fi

    log_info "Creating PM2 configuration..."

    cat > ecosystem.config.cjs <<'EOF'
module.exports = {
  apps: [
    {
      name: "jtg-panel",
      script: "npm",
      args: "start",
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",
      restart_delay: 3000,
      kill_timeout: 5000,
      env: {
        NODE_ENV: "production",
        PORT: process.env.PORT || 6767
      }
    }
  ]
};
EOF

    log_success "PM2 configuration created."
}

# =========================================================
# PANEL INSTALLATION
# =========================================================

install_panel() {
    print_banner

    section "FULL PANEL INSTALLATION"

    if [ "$EUID" -ne 0 ] && ! command_exists sudo; then
        log_error "sudo is required when running as a non-root user."
        pause_screen
        return
    fi

    log_info "Starting automatic installation..."
    echo

    install_dependencies || {
        log_error "Dependency installation failed."
        pause_screen
        return
    }

    install_node || {
        log_error "Node.js setup failed."
        pause_screen
        return
    }

    install_pm2 || {
        log_error "PM2 setup failed."
        pause_screen
        return
    }

    install_docker || true

    local work_dir
    work_dir=$(prepare_repository) || {
        pause_screen
        return
    }

    # prepare_repository prints logs, so get actual path separately
    if [ -d "$PANEL_DIR" ]; then
        work_dir="$PANEL_DIR"
    elif [ -f "package.json" ]; then
        work_dir="."
    fi

    setup_environment "$work_dir" || {
        log_error "Environment setup failed."
        pause_screen
        return
    }

    create_pm2_config "$work_dir" || {
        log_error "PM2 configuration failed."
        pause_screen
        return
    }

    cd "$work_dir" || return

    section "NODE DEPENDENCIES"

    log_info "Installing npm dependencies..."

    if npm install; then
        log_success "Dependencies installed."
    else
        log_error "npm install failed."
        pause_screen
        return
    fi

    section "BUILD"

    log_info "Building JTG Panel..."

    if npm run build; then
        log_success "Panel build completed."
    else
        log_error "Panel build failed."
        pause_screen
        return
    fi

    section "ADMIN USER"

    if npm run createuser; then
        log_success "Admin user creation completed."
    else
        log_warning "Admin user command returned an error."
        log_warning "You can create the admin later from the menu."
    fi

    section "STARTING PANEL"

    pm2_cmd delete "$PANEL_PROCESS" >/dev/null 2>&1 || true

    if pm2_cmd start ecosystem.config.cjs; then
        pm2_cmd save >/dev/null 2>&1 || true

        if command_exists systemctl; then
            pm2_cmd startup systemd -u "${SUDO_USER:-$USER}" --hp "${HOME}" >/tmp/jtg_pm2_startup.txt 2>&1 || true
        fi

        log_success "JTG Panel started successfully."
    else
        log_error "Failed to start panel."
        pause_screen
        return
    fi

    sleep 2

    echo
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  INSTALLATION COMPLETE                       ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                                                              ║"
    printf "║  Panel Status : %-42s ║\n" "$(panel_status)"
    printf "║  Port         : %-42s ║\n" "$DEFAULT_PORT"
    printf "║  URL          : %-42s ║\n" "http://<SERVER-IP>:${DEFAULT_PORT}"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    pause_screen
}

# =========================================================
# START PANEL
# =========================================================

start_panel() {
    print_banner
    section "START PANEL"

    local dir
    dir=$(get_panel_dir)

    if [ -z "$dir" ]; then
        log_error "JTG Panel is not installed."
        pause_screen
        return
    fi

    if ! pm2_available; then
        log_error "PM2 is not installed."
        pause_screen
        return
    fi

    if panel_exists; then
        pm2_cmd start "$PANEL_PROCESS" >/dev/null 2>&1 || true
    else
        cd "$dir" || return

        if [ ! -f "ecosystem.config.cjs" ]; then
            create_pm2_config "."
        fi

        pm2_cmd start ecosystem.config.cjs
    fi

    pm2_cmd save >/dev/null 2>&1 || true

    sleep 2

    if [ "$(panel_status)" = "ONLINE" ]; then
        log_success "Panel is now ONLINE."
    else
        log_error "Panel did not start correctly."
        log_info "Use View Logs to inspect the problem."
    fi

    pause_screen
}

# =========================================================
# STOP PANEL
# =========================================================

stop_panel() {
    print_banner
    section "STOP PANEL"

    if !panel_exists; then
        log_warning "Panel process does not exist."
        pause_screen
        return
    fi

    log_info "Stopping panel..."

    if pm2_cmd stop "$PANEL_PROCESS"; then
        pm2_cmd save >/dev/null 2>&1 || true
        sleep 1
        log_success "Panel stopped successfully."
        echo
        echo -e "  Status: ${RED}● OFFLINE${NC}"
    else
        log_error "Failed to stop panel."
    fi

    pause_screen
}

# =========================================================
# RESTART PANEL
# =========================================================

restart_panel() {
    print_banner
    section "RESTART PANEL"

    if !panel_exists; then
        log_warning "Panel is not registered with PM2."
        log_info "Attempting to start it..."

        start_panel
        return
    fi

    log_info "Restarting panel..."

    if pm2_cmd restart "$PANEL_PROCESS"; then
        sleep 2

        if [ "$(panel_status)" = "ONLINE" ]; then
            log_success "Panel restarted successfully."
        else
            log_error "Panel restart completed but process is not ONLINE."
        fi
    else
        log_error "Failed to restart panel."
    fi

    pause_screen
}

# =========================================================
# PANEL STATUS
# =========================================================

panel_status_page() {
    print_banner
    section "PANEL STATUS"

    show_dashboard_status

    echo

    if panel_exists; then
        echo -e "${CYAN}${BOLD}PM2 PROCESS${NC}"
        echo
        pm2_cmd show "$PANEL_PROCESS" 2>/dev/null || true
    else
        log_warning "No PM2 process named '$PANEL_PROCESS' found."
    fi

    pause_screen
}

# =========================================================
# LOGS
# =========================================================

view_logs() {
    print_banner
    section "PANEL LOGS"

    if !panel_exists; then
        log_error "Panel process not found."
        pause_screen
        return
    fi

    echo -e "${GRAY}Showing the latest logs. Press Ctrl+C to exit.${NC}"
    echo

    pm2_cmd logs "$PANEL_PROCESS" --lines 100
}

# =========================================================
# UPDATE PANEL
# =========================================================

update_panel() {
    print_banner
    section "UPDATE JTG PANEL"

    local dir
    dir=$(get_panel_dir)

    if [ -z "$dir" ]; then
        log_error "JTG Panel is not installed."
        pause_screen
        return
    fi

    cd "$dir" || return

    log_info "Creating a temporary backup of .env..."

    if [ -f ".env" ]; then
        cp .env /tmp/jtg-panel-env.backup
    fi

    log_info "Fetching latest changes..."

    if git stash push -u -m "JTG auto update $(date +%s)" >/dev/null 2>&1 || true; then
        :
    fi

    if git pull --rebase; then
        log_success "Source code updated."
    else
        log_error "Git update failed."
        pause_screen
        return
    fi

    if [ -f "/tmp/jtg-panel-env.backup" ]; then
        cp /tmp/jtg-panel-env.backup .env
        rm -f /tmp/jtg-panel-env.backup
        log_success ".env preserved."
    fi

    section "UPDATING DEPENDENCIES"

    if npm install; then
        log_success "Dependencies updated."
    else
        log_error "npm install failed."
        pause_screen
        return
    fi

    section "REBUILDING"

    if npm run build; then
        log_success "Build completed."
    else
        log_error "Build failed."
        pause_screen
        return
    fi

    section "RESTARTING"

    if panel_exists; then
        pm2_cmd restart "$PANEL_PROCESS"
    else
        pm2_cmd start ecosystem.config.cjs
    fi

    pm2_cmd save >/dev/null 2>&1 || true

    sleep 2

    if [ "$(panel_status)" = "ONLINE" ]; then
        log_success "Panel successfully updated and restarted."
    else
        log_warning "Update completed but panel is not ONLINE."
    fi

    pause_screen
}

# =========================================================
# CREATE ADMIN
# =========================================================

create_admin_user() {
    print_banner
    section "CREATE ADMIN USER"

    local dir
    dir=$(get_panel_dir)

    if [ -z "$dir" ]; then
        log_error "JTG Panel is not installed."
        pause_screen
        return
    fi

    cd "$dir" || return

    log_info "Launching admin creation..."

    if npm run createuser; then
        log_success "Admin user process completed."
    else
        log_error "Admin user creation failed."
    fi

    pause_screen
}

# =========================================================
# DOCKER STATUS
# =========================================================

docker_status() {
    print_banner
    section "DOCKER STATUS"

    if !command_exists docker; then
        log_error "Docker is not installed."
        pause_screen
        return
    fi

    if command_exists systemctl; then
        echo -e "  ${BOLD}Service${NC}:"

        if systemctl is-active --quiet docker; then
            echo -e "  ${GREEN}● Docker service is ACTIVE${NC}"
        else
            echo -e "  ${RED}● Docker service is INACTIVE${NC}"
        fi

        echo
    fi

    echo -e "  ${BOLD}Docker Version${NC}:"
    docker --version

    echo
    echo -e "  ${BOLD}Containers${NC}:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true

    pause_screen
}

# =========================================================
# PM2 STATUS
# =========================================================

pm2_status_page() {
    print_banner
    section "PM2 PROCESS MANAGER"

    if !pm2_available; then
        log_error "PM2 is not installed."
        pause_screen
        return
    fi

    pm2_cmd status

    pause_screen
}

# =========================================================
# SETTINGS
# =========================================================

settings_page() {
    print_banner
    section "PANEL SETTINGS"

    echo -e "  ${BOLD}Current Port:${NC} ${CYAN}${DEFAULT_PORT}${NC}"
    echo
    echo -e "  ${GRAY}The current installer keeps the panel port at ${DEFAULT_PORT}.${NC}"
    echo -e "  ${GRAY}To change the application's port, edit the PORT value in .env.${NC}"
    echo

    local dir
    dir=$(get_panel_dir)

    if [ -n "$dir" ] && [ -f "$dir/.env" ]; then
        echo -e "${BOLD}.env location:${NC} $dir/.env"
    else
        log_warning ".env file not found."
    fi

    pause_screen
}

# =========================================================
# UNINSTALL
# =========================================================

uninstall_panel() {
    print_banner
    section "UNINSTALL JTG PANEL"

    echo -e "${RED}${BOLD}WARNING${NC}"
    echo
    echo "This will remove the JTG PM2 process."
    echo "The GitHub source directory can also be removed."
    echo

    read -rp "Type REMOVE to continue: " confirmation

    if [ "$confirmation" != "REMOVE" ]; then
        log_info "Uninstall cancelled."
        pause_screen
        return
    fi

    if panel_exists; then
        log_info "Stopping PM2 process..."
        pm2_cmd delete "$PANEL_PROCESS" || true
        pm2_cmd save >/dev/null 2>&1 || true
    fi

    echo
    read -rp "Delete the Jtg source directory too? [y/N]: " delete_dir

    if [[ "$delete_dir" =~ ^[Yy]$ ]]; then
        if [ -d "$PANEL_DIR" ]; then
            rm -rf "$PANEL_DIR"
            log_success "Jtg directory removed."
        fi
    fi

    log_success "JTG Panel has been uninstalled."

    pause_screen
}

# =========================================================
# QUICK REFRESH
# =========================================================

refresh_status() {
    print_banner
    show_dashboard_status
    sleep 2
}

# =========================================================
# MAIN MENU
# =========================================================

main_menu() {
    while true; do
        print_banner

        echo -e "  ${BOLD}SYSTEM STATUS${NC}"
        echo -e "  ────────────────────────────────────────────────────────────"

        show_dashboard_status

        echo
        echo -e "${CYAN}${BOLD}  PANEL CONTROLS${NC}"
        echo -e "  ────────────────────────────────────────────────────────────"

        echo -e "  ${GREEN}[1]${NC} 🚀 Start Panel"
        echo -e "  ${RED}[2]${NC} 🛑 Stop Panel"
        echo -e "  ${YELLOW}[3]${NC} 🔄 Restart Panel"
        echo -e "  ${CYAN}[4]${NC} 📊 Panel Status"
        echo -e "  ${BLUE}[5]${NC} 📋 View Logs"

        echo
        echo -e "${CYAN}${BOLD}  MANAGEMENT${NC}"
        echo -e "  ────────────────────────────────────────────────────────────"

        echo -e "  ${MAGENTA}[6]${NC} ⬆ Update Panel"
        echo -e "  ${MAGENTA}[7]${NC} 👤 Create Admin"
        echo -e "  ${BLUE}[8]${NC} 🐳 Docker Status"
        echo -e "  ${BLUE}[9]${NC} ⚙ Settings"

        echo
        echo -e "${CYAN}${BOLD}  SYSTEM${NC}"
        echo -e "  ────────────────────────────────────────────────────────────"

        echo -e "  ${WHITE}[10]${NC} 🖥 System Information"
        echo -e "  ${WHITE}[11]${NC} 📦 PM2 Status"
        echo -e "  ${YELLOW}[12]${NC} 🔃 Refresh Dashboard"
        echo -e "  ${RED}[13]${NC} 🗑 Uninstall Panel"
        echo -e "  ${GRAY}[0]${NC} ❌ Exit"

        echo
        echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        read -rp "$(echo -e "  ${BOLD}Select an option:${NC} ")" choice

        case "$choice" in
            1)
                start_panel
                ;;
            2)
                stop_panel
                ;;
            3)
                restart_panel
                ;;
            4)
                panel_status_page
                ;;
            5)
                view_logs
                ;;
            6)
                update_panel
                ;;
            7)
                create_admin_user
                ;;
            8)
                docker_status
                ;;
            9)
                settings_page
                ;;
            10)
                system_info
                ;;
            11)
                pm2_status_page
                ;;
            12)
                refresh_status
                ;;
            13)
                uninstall_panel
                ;;
            0)
                clear
                echo
                echo -e "${CYAN}${BOLD}  Thanks for using JTG PANEL.${NC}"
                echo -e "${GRAY}  Goodbye!${NC}"
                echo
                exit 0
                ;;
            *)
                log_error "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# =========================================================
# START
# =========================================================

if [ "${1:-}" = "--install" ]; then
    install_panel
    exit 0
fi

if [ "${1:-}" = "--status" ]; then
    show_dashboard_status
    exit 0
fi

if [ "${1:-}" = "--start" ]; then
    start_panel
    exit 0
fi

if [ "${1:-}" = "--stop" ]; then
    stop_panel
    exit 0
fi

if [ "${1:-}" = "--restart" ]; then
    restart_panel
    exit 0
fi

main_menu
```
