#!/bin/bash

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directorios
VAGRANT_DIR="/vagrant"
GIT_DIR="$VAGRANT_DIR/.git"
HOOKS_SOURCE_DIR="$VAGRANT_DIR/provision/git-hooks"
HOOKS_DIR="$GIT_DIR/hooks"

# Lista de hooks a activar
HOOKS=(
    "pre-commit"
    "pre-push"
    "post-merge"
    "post-checkout"
)

# Función para mostrar mensajes
log_message() {
    local level=$1
    local message=$2
    case $level in
        "info")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Función para verificar requisitos
check_requirements() {
    log_message "info" "Verificando requisitos..."

    # Verificar que git está instalado
    if ! command -v git >/dev/null 2>&1; then
        log_message "error" "Git no está instalado"
        exit 1
    }

    # Verificar que estamos en un repositorio git
    if [ ! -d "$GIT_DIR" ]; then
        log_message "error" "No se encuentra el directorio .git"
        exit 1
    }

    # Verificar que existe el directorio de hooks fuente
    if [ ! -d "$HOOKS_SOURCE_DIR" ]; then
        mkdir -p "$HOOKS_SOURCE_DIR"
        log_message "info" "Creado directorio de hooks fuente: $HOOKS_SOURCE_DIR"
    fi
}

# Función para crear hooks por defecto
create_default_hooks() {
    log_message "info" "Creando hooks por defecto..."

    # Pre-commit hook
    cat > "$HOOKS_SOURCE_DIR/pre-commit" << 'EOF'
#!/bin/bash

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Verificar archivos PHP
check_php_files() {
    local files=$(git diff --cached --name-only --diff-filter=ACMR | grep "\.php$")
    if [ -n "$files" ]; then
        echo "Verificando sintaxis PHP..."
        echo "$files" | while read -r file; do
            if [ -f "$file" ]; then
                php -l "$file" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Error de sintaxis en $file${NC}"
                    exit 1
                fi
            fi
        done
    fi
}

# Verificar WordPress Coding Standards
check_wpcs() {
    if command -v phpcs >/dev/null 2>&1; then
        local files=$(git diff --cached --name-only --diff-filter=ACMR | grep "\.php$")
        if [ -n "$files" ]; then
            echo "Verificando WordPress Coding Standards..."
            echo "$files" | while read -r file; do
                if [ -f "$file" ]; then
                    phpcs --standard=WordPress "$file"
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}El archivo $file no cumple con WordPress Coding Standards${NC}"
                        exit 1
                    fi
                fi
            done
        fi
    fi
}

# Verificar archivos JavaScript
check_js_files() {
    if command -v eslint >/dev/null 2>&1; then
        local files=$(git diff --cached --name-only --diff-filter=ACMR | grep "\.js$")
        if [ -n "$files" ]; then
            echo "Verificando archivos JavaScript..."
            eslint $files
            if [ $? -ne 0 ]; then
                echo -e "${RED}Se encontraron errores en los archivos JavaScript${NC}"
                exit 1
            fi
        fi
    fi
}

# Verificar archivos CSS
check_css_files() {
    if command -v stylelint >/dev/null 2>&1; then
        local files=$(git diff --cached --name-only --diff-filter=ACMR | grep "\.css$")
        if [ -n "$files" ]; then
            echo "Verificando archivos CSS..."
            stylelint $files
            if [ $? -ne 0 ]; then
                echo -e "${RED}Se encontraron errores en los archivos CSS${NC}"
                exit 1
            fi
        fi
    fi
}

# Ejecutar todas las verificaciones
echo "Ejecutando verificaciones pre-commit..."
check_php_files
check_wpcs
check_js_files
check_css_files

echo -e "${GREEN}Todas las verificaciones pasaron exitosamente${NC}"
exit 0
EOF

    # Pre-push hook
    cat > "$HOOKS_SOURCE_DIR/pre-push" << 'EOF'
#!/bin/bash

# Ejecutar pruebas unitarias si existen
if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
    echo "Ejecutando pruebas unitarias..."
    ./vendor/bin/phpunit
    if [ $? -ne 0 ]; then
        echo "Las pruebas unitarias fallaron"
        exit 1
    fi
fi

exit 0
EOF

    # Post-merge hook
    cat > "$HOOKS_SOURCE_DIR/post-merge" << 'EOF'
#!/bin/bash

# Verificar si hay cambios en composer.json
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep "^composer.json"; then
    echo "composer.json ha cambiado, actualizando dependencias..."
    composer install
fi

# Verificar si hay cambios en package.json
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep "^package.json"; then
    echo "package.json ha cambiado, actualizando dependencias..."
    npm install
fi

# Actualizar base de datos si es necesario
if command -v wp >/dev/null 2>&1; then
    echo "Actualizando base de datos WordPress..."
    wp core update-db
fi
EOF

    # Post-checkout hook
    cat > "$HOOKS_SOURCE_DIR/post-checkout" << 'EOF'
#!/bin/bash

# Verificar si hay cambios en archivos de configuración
if git diff-tree -r --name-only --no-commit-id $1 $2 | grep -E "composer.json|package.json"; then
    echo "Se detectaron cambios en archivos de configuración"
    echo "Por favor, ejecuta:"
    echo "  composer install"
    echo "  npm install"
fi
EOF

    # Hacer ejecutables todos los hooks
    chmod +x "$HOOKS_SOURCE_DIR"/*
    log_message "info" "Hooks por defecto creados y configurados"
}

# Función para activar los hooks
activate_hooks() {
    log_message "info" "Activando hooks..."

    # Crear directorio de hooks si no existe
    mkdir -p "$HOOKS_DIR"

    # Activar cada hook
    for hook in "${HOOKS[@]}"; do
        if [ -f "$HOOKS_SOURCE_DIR/$hook" ]; then
            ln -sf "$HOOKS_SOURCE_DIR/$hook" "$HOOKS_DIR/$hook"
            log_message "info" "Hook $hook activado"
        else
            log_message "warn" "Hook $hook no encontrado en directorio fuente"
        fi
    done
}

# Función principal
main() {
    log_message "info" "Iniciando activación de git hooks..."

    check_requirements
    create_default_hooks
    activate_hooks

    log_message "info" "Configuración de git hooks completada"
}

# Ejecutar el script
main