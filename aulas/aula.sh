#!/bin/bash
# Prepara o servidor para uma aula.
#   aula base  -> recria o banco rangoja do zero e remove usuários extras
#   aula 1..5  -> base + cenário (incidente) da aula
# Uso (no computador do professor):  docker compose exec servidor aula 1
set -e

BANCO=/opt/rangoja/banco
AULAS=/opt/rangoja/aulas

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root: docker compose exec servidor aula <n>" >&2
    exit 1
fi

reset_base() {
    echo "[aula] Removendo usuários criados em aulas anteriores..."
    mysql -uroot -N -e "
        SELECT CONCAT('DROP USER ', QUOTE(user), '@', QUOTE(host), ';')
          FROM mysql.user
         WHERE user NOT IN ('root','dba','debian-sys-maint',
                            'mysql.sys','mysql.session','mysql.infoschema')" \
        | mysql -uroot

    echo "[aula] Removendo objetos de aulas anteriores..."
    mysql -uroot -N -e "
        SELECT CONCAT('DROP EVENT IF EXISTS \`', event_schema, '\`.\`', event_name, '\`;')
          FROM information_schema.events" | mysql -uroot
    mysql -uroot -e "SET GLOBAL general_log = OFF; DROP DATABASE IF EXISTS rangoja_restore;"
    rm -f /dados/* /backup/* 2>/dev/null || true

    echo "[aula] Recriando o banco rangoja (cerca de 1 minuto)..."
    mysql -uroot < "$BANCO/01-schema.sql"
    mysql -uroot < "$BANCO/02-dados.sql" > /dev/null
}

case "$1" in
    base)
        reset_base
        ;;
    [1-5])
        reset_base
        DIR="$AULAS/aula0$1"
        echo "[aula] Aplicando o cenário da aula $1..."
        [ -f "$DIR/setup.sql" ] && mysql -uroot < "$DIR/setup.sql"
        [ -f "$DIR/setup.sh" ]  && bash "$DIR/setup.sh"
        ;;
    *)
        echo "Uso: aula base | aula <1-5>" >&2
        exit 1
        ;;
esac

echo "[aula] Pronto."
