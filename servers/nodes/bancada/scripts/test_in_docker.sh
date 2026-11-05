#!/bin/bash
# ==============================================================================
# LPS / UFRJ - test_in_docker.sh
# Automated Test Runner for Workstation Setup on Ubuntu 26 (amd64) via Docker
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_IMAGE="${DOCKER_IMAGE:-ubuntu:rolling}"

# Color codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"
C_BLUE="\033[34m"

# ------------------------------------------------------------------------------
# HOST EXECUTION DISPATCHER
# If running outside container, launch Docker container and re-enter inside
# ------------------------------------------------------------------------------
if [ ! -f /.dockerenv ] && [ "${1:-}" != "--inside" ]; then
    TARGET_CMD="${1:-all}"
    shift || true

    echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}🐳 Launching Workstation Test in Docker ($DOCKER_IMAGE - linux/amd64)${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"

    if [ "$TARGET_CMD" = "shell" ]; then
        exec docker run --rm -it \
            --platform linux/amd64 \
            --privileged \
            -v "$WORK_DIR:/workspace" \
            -w /workspace \
            "$DOCKER_IMAGE" bash -c "
                echo -e '${C_BLUE}ℹ️ Preparing test shell environment (sudo, iproute2, procps, curl)...${C_RESET}'
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -qq && apt-get install -qq -y sudo iproute2 procps ca-certificates curl >/dev/null
                echo -e '${C_GREEN}🚀 Environment ready! You are in Ubuntu 26 (amd64).${C_RESET}'
                echo -e '💡 Available commands in this workspace:'
                echo -e '   make network | make base | make docker | make singularity | make all'
                echo -e '   or run scripts directly: bash ./scripts/01_setup_network.sh\n'
                exec bash
            "
    fi

    exec docker run --rm \
        --platform linux/amd64 \
        --privileged \
        -v "$WORK_DIR:/workspace" \
        -w /workspace \
        "$DOCKER_IMAGE" bash -c "./scripts/test_in_docker.sh --inside $TARGET_CMD $*"
fi

# ------------------------------------------------------------------------------
# CONTAINER EXECUTION LOGIC
# ------------------------------------------------------------------------------
if [ "${1:-}" = "--inside" ]; then
    shift
fi

STEP="${1:-all}"

# Ensure minimal testing utilities inside blank container
echo -e "${C_BLUE}ℹ️ Preparing container testing environment (apt-get update & basic tools)...${C_RESET}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
apt-get install -qq -y sudo iproute2 procps ca-certificates curl >/dev/null

TEST_RESULTS=()

run_step_01() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 01: Network & Hostname Configuration${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/01_setup_network.sh 146.164.147.201 bancada01; then
        if [ -f /etc/netplan/01-netcfg.yaml ] && grep -q "146.164.147.201" /etc/netplan/01-netcfg.yaml; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 01: Network & Hostname Configuration .......... PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 01: Network & Hostname Configuration .......... FAILED${C_RESET}")
    return 1
}

run_step_02() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 02: Base System Utilities & Authentication${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/02_install_base.sh; then
        if grep -q "vm.panic_on_oom" /etc/sysctl.conf && dpkg -s nfs-common &>/dev/null && [ -x /etc/update-motd.d/00-main-message ]; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 02: Base Utilities & Kerberos/LDAP Config ..... PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 02: Base Utilities & Kerberos/LDAP Config ..... FAILED${C_RESET}")
    return 1
}

run_step_03() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 03: Docker CE & Daemon Configuration${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/03_install_docker.sh; then
        if [ -f /etc/docker/daemon.json ] && command -v docker &>/dev/null; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 03: Docker CE & Log-Rotation Daemon Config .... PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 03: Docker CE & Log-Rotation Daemon Config .... FAILED${C_RESET}")
    return 1
}

run_step_04() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 04: SingularityCE & Fakeroot Helper${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/04_install_singularity.sh; then
        if command -v singularity &>/dev/null && singularity --version | grep -iq "singularity"; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 04: SingularityCE & Fakeroot Integration ...... PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 04: SingularityCE & Fakeroot Integration ...... FAILED${C_RESET}")
    return 1
}

run_step_05() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 05: Custom LPS Login Screen (GDM)${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/05_custom_login_screen.sh; then
        if [ -f /etc/dconf/profile/gdm ] && [ -f /etc/dconf/db/gdm.d/00-login-screen ]; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 05: Custom LPS Login Screen & Branding ........ PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 05: Custom LPS Login Screen & Branding ........ FAILED${C_RESET}")
    return 1
}

run_step_06() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 06: CUDA & NVIDIA Drivers (Conditional)${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/06_install_cuda.sh; then
        TEST_RESULTS+=("${C_YELLOW}[!] Step 06: CUDA Drivers & Toolkit (No GPU) ........... SKIPPED (PASSED)${C_RESET}")
        return 0
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 06: CUDA Drivers & Toolkit .................... FAILED${C_RESET}")
    return 1
}

run_step_07() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 07: NVIDIA Container Toolkit (Conditional)${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/07_configure_docker_gpu_toolkit.sh; then
        TEST_RESULTS+=("${C_YELLOW}[!] Step 07: NVIDIA Docker Toolkit (No GPU) ............ SKIPPED (PASSED)${C_RESET}")
        return 0
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 07: NVIDIA Docker Toolkit ..................... FAILED${C_RESET}")
    return 1
}

run_step_08() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 08: SLURM Client Configuration${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/08_install_slurm_client.sh; then
        if dpkg -s munge &>/dev/null; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 08: SLURM Client Configuration ................ PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 08: SLURM Client Configuration ................ FAILED${C_RESET}")
    return 1
}

run_step_09() {
    echo -e "\n${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}🧪 Testing Step 09: Developer Tools (VSCode & Antigravity)${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------------------------${C_RESET}"
    if ./scripts/09_install_dev_tools.sh; then
        if dpkg -s code &>/dev/null && [ -f /usr/share/applications/antigravity.desktop ] && [ -x /usr/local/bin/agy ]; then
            TEST_RESULTS+=("${C_GREEN}[✓] Step 09: Developer Tools (VSCode & Antigravity) .... PASSED${C_RESET}")
            return 0
        fi
    fi
    TEST_RESULTS+=("${C_RED}[✗] Step 09: Developer Tools (VSCode & Antigravity) .... FAILED${C_RESET}")
    return 1
}

# Run selected test or complete pipeline
FAILED=0
case "$STEP" in
    01|network)
        run_step_01 || FAILED=1
        ;;
    02|base)
        run_step_02 || FAILED=1
        ;;
    03|docker)
        run_step_03 || FAILED=1
        ;;
    04|singularity)
        run_step_04 || FAILED=1
        ;;
    05|login)
        run_step_05 || FAILED=1
        ;;
    06|cuda)
        run_step_06 || FAILED=1
        ;;
    07|gpu-toolkit)
        run_step_07 || FAILED=1
        ;;
    08|slurm|slurm-client)
        run_step_08 || FAILED=1
        ;;
    09|dev-tools|vscode)
        run_step_09 || FAILED=1
        ;;
    all)
        run_step_01 || FAILED=1
        run_step_02 || FAILED=1
        run_step_03 || FAILED=1
        run_step_04 || FAILED=1
        run_step_05 || FAILED=1
        run_step_06 || FAILED=1
        run_step_07 || FAILED=1
        run_step_08 || FAILED=1
        run_step_09 || FAILED=1
        ;;
    *)
        echo -e "${C_RED}❌ Error: Unknown test step '$STEP'. Use 01, 02, 03, 04, 05, 06, 07, 08, 09, or all.${C_RESET}"
        exit 1
        ;;
esac

echo -e "\n${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}📊 WORKSTATION VALIDATION REPORT ($(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'))${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"
for line in "${TEST_RESULTS[@]}"; do
    echo -e "  $line"
done
echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${C_GREEN}${C_BOLD}🎉 ALL TESTED STEPS COMPLETED SUCCESSFULLY!${C_RESET}\n"
    exit 0
else
    echo -e "${C_RED}${C_BOLD}❌ ONE OR MORE STEPS FAILED VALIDATION.${C_RESET}\n"
    exit 1
fi
