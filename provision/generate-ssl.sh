#!/bin/bash

# Definir constantes y variables
SSL_DIR="/vagrant/.vagrant/ssl"
CONFIG_FILE="/vagrant/config.yml"
DAYS_VALID=365
COUNTRY="ES"
STATE="Madrid"
LOCALITY="Madrid"
ORGANIZATION="Development Environment"
ORGANIZATIONAL_UNIT="IT"
KEY_SIZE=2048

# Función para registrar mensajes
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - $1"
}

# Función para verificar errores
check_error() {
    if [ $? -ne 0 ]; then
        log_message "ERROR: $1"
        exit 1
    fi
}

# Función para obtener dominios del config.yml
get_domains() {
    # Verificar si ruby está instalado
    if ! command -v ruby >/dev/null 2>&1; then
        log_message "ERROR: Ruby es requerido para procesar config.yml"
        exit 1
    }

    # Script Ruby para extraer dominios
    ruby -ryaml -e '
        begin
            config = YAML.load_file(ARGV[0])
            domains = []

            # Obtener el dominio principal
            domains << "#{config["name"]}.local" if config["name"]

            # Obtener dominios de desarrollo
            if config["development"]
                domains << config["development"]["domain"] if config["development"]["domain"]
                domains.concat(config["development"]["domains"]) if config["development"]["domains"]
            end

            # Agregar subdominios comunes
            subdomains = %w(www webgrind adminer mailcatcher browsersync info)
            subdomains.each do |subdomain|
                domains << "#{subdomain}.#{config["name"]}.local" if config["name"]
            end

            # Eliminar duplicados y valores nulos
            domains = domains.compact.uniq

            # Imprimir dominios
            puts domains.join(",")
        rescue => e
            STDERR.puts "Error procesando config.yml: #{e.message}"
            exit 1
        end
    ' "$CONFIG_FILE"
}

# Función para crear directorio SSL si no existe
create_ssl_directory() {
    if [ ! -d "$SSL_DIR" ]; then
        mkdir -p "$SSL_DIR"
        chmod 700 "$SSL_DIR"
        log_message "Directorio SSL creado: $SSL_DIR"
    fi
}

# Función para generar la configuración OpenSSL
generate_ssl_config() {
    local domains=$(get_domains)
    local primary_domain=$(echo $domains | cut -d',' -f1)
    local email="admin@${primary_domain}"

    # Crear archivo de configuración OpenSSL
    cat > "$SSL_DIR/openssl.cnf" << EOF
[req]
default_bits = ${KEY_SIZE}
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = ${COUNTRY}
ST = ${STATE}
L = ${LOCALITY}
O = ${ORGANIZATION}
OU = ${ORGANIZATIONAL_UNIT}
emailAddress = ${email}
CN = ${primary_domain}

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[alt_names]
DNS.1 = ${primary_domain}
EOF

    # Agregar todos los dominios como DNS alternativos
    local i=2
    IFS=',' read -ra ADDR <<< "$domains"
    for domain in "${ADDR[@]}"; do
        if [ "$domain" != "$primary_domain" ]; then
            echo "DNS.$i = $domain" >> "$SSL_DIR/openssl.cnf"
            i=$((i+1))
        fi
    done

    # Agregar localhost y IP local
    echo "DNS.$i = localhost" >> "$SSL_DIR/openssl.cnf"
    i=$((i+1))
    echo "IP.1 = 127.0.0.1" >> "$SSL_DIR/openssl.cnf"

    check_error "Error al generar la configuración OpenSSL"
}

# Función para generar el certificado
generate_certificate() {
    # Generar llave privada
    openssl genrsa -out "$SSL_DIR/development.key" ${KEY_SIZE}
    check_error "Error al generar la llave privada"
    chmod 600 "$SSL_DIR/development.key"

    # Generar el certificado
    openssl req -new -x509 \
        -config "$SSL_DIR/openssl.cnf" \
        -key "$SSL_DIR/development.key" \
        -out "$SSL_DIR/development.crt" \
        -days ${DAYS_VALID}
    check_error "Error al generar el certificado"

    log_message "Certificado generado para los dominios:"
    get_domains | tr ',' '\n' | sed 's/^/  - /'
}

# Función para configurar Apache
configure_apache() {
    if [ -d "/etc/apache2" ]; then
        # Copiar certificados
        cp "$SSL_DIR/development.crt" "/etc/ssl/certs/"
        cp "$SSL_DIR/development.key" "/etc/ssl/private/"

        # Asegurar permisos
        chmod 644 "/etc/ssl/certs/development.crt"
        chmod 600 "/etc/ssl/private/development.key"

        # Habilitar módulos
        a2enmod ssl
        a2enmod headers

        # Reiniciar Apache
        systemctl restart apache2
        check_error "Error al reiniciar Apache"

        log_message "Certificados instalados y Apache configurado"
    fi
}

# Función para agregar el certificado al sistema
trust_certificate() {
    if command -v update-ca-certificates &> /dev/null; then
        cp "$SSL_DIR/development.crt" "/usr/local/share/ca-certificates/"
        update-ca-certificates
        check_error "Error al actualizar certificados del sistema"
        log_message "Certificado agregado a los certificados de confianza del sistema"
    fi
}

# Función principal
main() {
    log_message "Iniciando generación de certificado SSL..."

    # Verificar si se está ejecutando como root
    if [ "$EUID" -ne 0 ]; then
        log_message "Este script debe ejecutarse como root"
        exit 1
    fi

    # Verificar que existe config.yml
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR: No se encuentra config.yml en $CONFIG_FILE"
        exit 1
    }

    create_ssl_directory
    generate_ssl_config
    generate_certificate
    configure_apache
    trust_certificate

    log_message "Generación de certificado SSL completada exitosamente"
}

# Ejecutar el script
main