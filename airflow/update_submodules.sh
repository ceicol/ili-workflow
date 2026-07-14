#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Formato: nombre|URL|rama
SUBMODULOS=(
)

log() {
    local nivel="$1"
    shift

    if [[ "$nivel" == "WARN" || "$nivel" == "ERROR" ]]; then
        printf '[%s] %s\n' "$nivel" "$*" >&2
    else
        printf '[%s] %s\n' "$nivel" "$*"
    fi
}

fallar() {
    log "ERROR" "$1"
    exit 1
}

tiene_cambios_locales() {
    local ruta_submodulo="$1"

    ! git -C "$ruta_submodulo" diff --quiet || \
        ! git -C "$ruta_submodulo" diff --cached --quiet
}

trap 'log "ERROR" "Falló el comando en la línea $LINENO: $BASH_COMMAND"' ERR
trap 'codigo_salida=$?; if [[ "$codigo_salida" -ne 0 ]]; then log "ERROR" "Proceso finalizado con errores (código $codigo_salida)."; fi' EXIT

log "INFO" "Iniciando actualización de submódulos..."

command -v git >/dev/null 2>&1 || fallar "El comando 'git' no está disponible."
command -v bash >/dev/null 2>&1 || fallar "El comando 'bash' no está disponible."

DIRECTORIO_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if ! RAIZ_REPOSITORIO="$(git -C "$DIRECTORIO_SCRIPT" rev-parse --show-toplevel 2>/dev/null)"; then
    fallar "No fue posible determinar la raíz del repositorio Git."
fi

DIRECTORIO_AIRFLOW="$RAIZ_REPOSITORIO/airflow"
DIRECTORIO_SUBMODULOS_RELATIVO="airflow/submodules"
DIRECTORIO_SUBMODULOS="$RAIZ_REPOSITORIO/$DIRECTORIO_SUBMODULOS_RELATIVO"
ARCHIVO_GITMODULES="$RAIZ_REPOSITORIO/.gitmodules"

[[ -d "$DIRECTORIO_AIRFLOW" ]] || fallar "No existe el directorio '$DIRECTORIO_AIRFLOW'."
mkdir -p "$DIRECTORIO_SUBMODULOS"
cd "$RAIZ_REPOSITORIO"

log "INFO" "Validaciones completadas correctamente."
log "INFO" "Raíz del repositorio: $RAIZ_REPOSITORIO"
log "INFO" "Directorio de submódulos: $DIRECTORIO_SUBMODULOS"

for registro_submodulo in "${SUBMODULOS[@]}"; do
    IFS='|' read -r nombre_submodulo url_submodulo rama_submodulo <<< "$registro_submodulo"

    [[ -n "$nombre_submodulo" && -n "$url_submodulo" && -n "$rama_submodulo" ]] || \
        fallar "La definición de submódulo no es válida: '$registro_submodulo'."

    ruta_relativa="$DIRECTORIO_SUBMODULOS_RELATIVO/$nombre_submodulo"
    ruta_absoluta="$RAIZ_REPOSITORIO/$ruta_relativa"
    script_configuracion="$ruta_absoluta/configure.sh"
    url_actual=""
    rama_actual=""
    rama_registrada=""

    log "INFO" "Procesando submódulo: $nombre_submodulo"
    log "INFO" "Ruta: $ruta_relativa"
    log "INFO" "Repositorio: $url_submodulo"
    log "INFO" "Rama esperada: $rama_submodulo"

    if [[ -f "$ARCHIVO_GITMODULES" ]] && \
        url_actual="$(git config --file "$ARCHIVO_GITMODULES" --get "submodule.$ruta_relativa.url" 2>/dev/null)"; then
        log "INFO" "La entrada del submódulo ya está registrada en .gitmodules."

        if [[ "$url_actual" != "$url_submodulo" ]]; then
            log "INFO" "Actualizando la URL registrada del submódulo."
            git config --file "$ARCHIVO_GITMODULES" "submodule.$ruta_relativa.url" "$url_submodulo"
        fi

        rama_registrada="$(git config --file "$ARCHIVO_GITMODULES" \
            --get "submodule.$ruta_relativa.branch" 2>/dev/null || true)"
        if [[ "$rama_registrada" != "$rama_submodulo" ]]; then
            log "INFO" "Actualizando la rama registrada a '$rama_submodulo'."
            git config --file "$ARCHIVO_GITMODULES" "submodule.$ruta_relativa.branch" "$rama_submodulo"
        fi
    else
        log "INFO" "Registrando y descargando el submódulo."
        git submodule add --force -b "$rama_submodulo" "$url_submodulo" "$ruta_relativa"
    fi

    log "INFO" "Sincronizando la configuración local del submódulo."
    git submodule sync -- "$ruta_relativa"

    if git -C "$ruta_absoluta" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
        tiene_cambios_locales "$ruta_absoluta"; then
        log "WARN" "El submódulo tiene cambios locales. Se omite la actualización remota para conservarlos."
    else
        log "INFO" "Inicializando el submódulo y sus dependencias recursivas."
        git submodule update --init --recursive -- "$ruta_relativa"

        git -C "$ruta_absoluta" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
            fallar "La ruta '$ruta_relativa' no contiene un repositorio Git válido."

        log "INFO" "Descargando cambios de origin/$rama_submodulo."
        git -C "$ruta_absoluta" fetch origin \
            "+refs/heads/$rama_submodulo:refs/remotes/origin/$rama_submodulo"

        rama_actual="$(git -C "$ruta_absoluta" symbolic-ref --short -q HEAD || true)"
        if [[ -z "$rama_actual" ]]; then
            if git -C "$ruta_absoluta" show-ref --verify --quiet "refs/heads/$rama_submodulo"; then
                log "INFO" "Cambiando a la rama local '$rama_submodulo'."
                git -C "$ruta_absoluta" checkout "$rama_submodulo"
                rama_actual="$rama_submodulo"
            else
                log "INFO" "Creando la rama local '$rama_submodulo' desde origin/$rama_submodulo."
                git -C "$ruta_absoluta" checkout -b "$rama_submodulo" --track "origin/$rama_submodulo"
                rama_actual="$rama_submodulo"
            fi
        fi

        if [[ "$rama_actual" == "$rama_submodulo" ]]; then
            log "INFO" "Actualizando la rama '$rama_submodulo' mediante avance rápido."
            git -C "$ruta_absoluta" merge --ff-only "origin/$rama_submodulo"
        elif [[ -n "$rama_actual" ]]; then
            log "WARN" "El submódulo está en la rama '$rama_actual'. Se conserva y no se actualiza '$rama_submodulo'."
        fi
    fi

    [[ -f "$script_configuracion" ]] || \
        fallar "No se encontró el archivo configure.sh en '$ruta_relativa'."

    log "INFO" "Creando los enlaces de Airflow mediante configure.sh."
    AIRFLOW_ROOT="$DIRECTORIO_AIRFLOW" bash "$script_configuracion"
    log "OK" "Submódulo '$nombre_submodulo' actualizado y enlazado correctamente."
done

log "OK" "Proceso finalizado correctamente."
