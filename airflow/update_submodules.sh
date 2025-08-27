#!/usr/bin/env bash

# Lista de submódulos asociados a cada ETL
echo "📦 Definiendo submódulos ETLs disponibles..."
SUBMODULES=(
)

# Ruta raíz donde se encontrarán los submódulos
SUBMODULES_DIR="submodules"
echo "📁 Carpeta raíz para submódulos definida como '$SUBMODULES_DIR'"

# Eliminar submódulos antiguos
echo "🔁 Iniciando limpieza de submódulos antiguos..."

for path in $(git config --file .gitmodules --get-regexp path | awk '{ print $2 }'); do
    echo "🗑️  Eliminando submódulo antiguo en ruta: $path"

    echo "   - Desactivando submódulo con git submodule deinit"
    git submodule deinit -f "$path"

    echo "   - Eliminando carpeta interna de Git: .git/modules/$path"
    rm -rf ".git/modules/$path"

    echo "   - Eliminando carpeta del submódulo: $path"
    rm -rf "$path"

    echo "   - Eliminando sección del submódulo en .gitmodules"
    git config --file .gitmodules --remove-section "submodule.$path" 2>/dev/null
done

# Si .gitmodules quedó vacío, se elimina
if [ ! -s .gitmodules ]; then
    echo "🧹 .gitmodules vacío, eliminando archivo"
    rm -f .gitmodules
else
    echo "📄 .gitmodules conserva contenido, no se elimina"
fi

echo "✅ Submódulos anteriores eliminados"
echo "============================================"

# Agregar nuevos submódulos
for submodule in "${SUBMODULES[@]}"; do
    echo "🔄 Procesando submódulo: $submodule"

    read -r REPO_URL FOLDER_NAME <<< "$submodule"
    LOCAL_PATH="$SUBMODULES_DIR/$FOLDER_NAME"

    echo "🔗 Repositorio: $REPO_URL"
    echo "📂 Ruta destino local: $LOCAL_PATH"

    echo "➕ Ejecutando git submodule add..."
    git submodule add --force "$REPO_URL" "$LOCAL_PATH"

    echo "⬇️  Inicializando y actualizando submódulo con --init --recursive --remote"
    git submodule update --init --recursive --remote "$LOCAL_PATH"

    CONFIGURE_SCRIPT="$LOCAL_PATH/configure.sh"
    if [ -f "$CONFIGURE_SCRIPT" ]; then
        echo "⚙️  Script de configuración detectado en $CONFIGURE_SCRIPT"
        echo "   - Ejecutando configure.sh desde dentro de $LOCAL_PATH"
        (cd "$LOCAL_PATH" && bash configure.sh)
    else
        echo "⚠️  No se encontró configure.sh en '$LOCAL_PATH'. Este paso será omitido."
    fi

    echo "✅ Submódulo $FOLDER_NAME listo"
    echo "============================================"
done

echo "🏁 Finalizado proceso de actualización de submódulos."
