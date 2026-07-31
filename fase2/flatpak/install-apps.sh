#!/usr/bin/env bash
#
# fase2/flatpak/install-apps.sh
#
# Pré-instala toda a curadoria de apps do Fabulinux via Flatpak/Flathub,
# a partir da lista em apps.list (mesma pasta).
#
# Pensado para rodar durante o BUILD da imagem (etapa de provisionamento,
# ex.: dentro do chroot/container que monta a imagem imutável), mas também
# funciona numa máquina/VM comum para testar a lista antes do build.
#
# Idempotente: pode ser executado várias vezes sem efeito colateral —
# apps já instalados são detectados e pulados.
#
# Uso:
#   sudo ./install-apps.sh                 # instala em --system (padrão, uso no build)
#   FLATPAK_INSTALLATION=user ./install-apps.sh   # instala em --user (teste sem root)
#   ./install-apps.sh --dry-run            # só mostra o que faria, não instala nada
#   ./install-apps.sh --list /caminho/outro-apps.list   # usa outra lista de IDs
#
# Variáveis de ambiente:
#   FLATPAK_INSTALLATION   "system" (padrão) ou "user"
#   FLATHUB_REPO_URL       URL do .flatpakrepo (padrão: repo oficial do Flathub)

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
APPS_LIST="${SCRIPT_DIR}/apps.list"
INSTALLATION="${FLATPAK_INSTALLATION:-system}"
FLATHUB_REPO_URL="${FLATHUB_REPO_URL:-https://dl.flathub.org/repo/flathub.flatpakrepo}"
DRY_RUN=0

log()  { printf '[install-apps] %s\n' "$*"; }
err()  { printf '[install-apps] ERRO: %s\n' "$*" >&2; }

usage() {
    grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//' | sed -n '1,25p'
}

# --- parse de argumentos -----------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --list)
            APPS_LIST="$2"
            shift 2
            ;;
        --user)
            INSTALLATION="user"
            shift
            ;;
        --system)
            INSTALLATION="system"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "argumento desconhecido: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$INSTALLATION" != "system" ] && [ "$INSTALLATION" != "user" ]; then
    err "FLATPAK_INSTALLATION/--system/--user inválido: '$INSTALLATION' (use 'system' ou 'user')"
    exit 1
fi

# --- pré-requisitos ------------------------------------------------------
if ! command -v flatpak >/dev/null 2>&1; then
    err "comando 'flatpak' não encontrado no PATH. Instale o pacote flatpak antes de rodar este script."
    exit 1
fi

if [ ! -f "$APPS_LIST" ]; then
    err "lista de apps não encontrada em: $APPS_LIST"
    exit 1
fi

if [ "$INSTALLATION" = "system" ] && [ "$DRY_RUN" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    err "instalação --system normalmente exige root. Rode com sudo, ou use --user / FLATPAK_INSTALLATION=user para testar sem root."
    exit 1
fi

log "instalação: --${INSTALLATION}   lista: ${APPS_LIST}   dry-run: ${DRY_RUN}"

# --- garante o remote Flathub (idempotente: --if-not-exists) ------------
if [ "$DRY_RUN" -eq 1 ]; then
    log "(dry-run) flatpak remote-add --${INSTALLATION} --if-not-exists flathub ${FLATHUB_REPO_URL}"
else
    flatpak remote-add --${INSTALLATION} --if-not-exists flathub "$FLATHUB_REPO_URL"
fi

# --- lê apps.list, ignorando comentários e linhas em branco --------------
# (loop portátil em vez de `mapfile`, que exige bash >= 4)
APP_IDS=()
while IFS= read -r line; do
    APP_IDS+=("$line")
done < <(grep -vE '^\s*(#|$)' "$APPS_LIST" | sed -E 's/[[:space:]]+$//')

if [ "${#APP_IDS[@]}" -eq 0 ]; then
    err "nenhum Application ID encontrado em $APPS_LIST"
    exit 1
fi

log "${#APP_IDS[@]} apps na curadoria."

INSTALLED=()
SKIPPED=()
FAILED=()

for app_id in "${APP_IDS[@]}"; do
    if flatpak info --${INSTALLATION} "$app_id" >/dev/null 2>&1; then
        log "já instalado, pulando: $app_id"
        SKIPPED+=("$app_id")
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "(dry-run) flatpak install --${INSTALLATION} -y --noninteractive flathub $app_id"
        continue
    fi

    log "instalando: $app_id"
    if flatpak install --${INSTALLATION} -y --noninteractive flathub "$app_id"; then
        INSTALLED+=("$app_id")
    else
        err "falha ao instalar: $app_id"
        FAILED+=("$app_id")
    fi
done

# --- resumo ---------------------------------------------------------------
log "----------------------------------------------------------------"
log "instalados agora : ${#INSTALLED[@]}"
log "já presentes     : ${#SKIPPED[@]}"
log "falharam         : ${#FAILED[@]}"

if [ "${#FAILED[@]}" -gt 0 ]; then
    printf '[install-apps]   - %s\n' "${FAILED[@]}" >&2
    exit 1
fi

log "concluído com sucesso."
