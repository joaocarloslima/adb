#!/bin/bash
# Sobe o MySQL e o SSH do servidor rangoja-prod-db01
set -e

mkdir -p /var/run/mysqld /var/log/mysql /run/sshd
chown mysql:mysql /var/run/mysqld /var/lib/mysql
chmod 755 /var/run/mysqld
chown mysql:adm /var/log/mysql && chmod 2750 /var/log/mysql

# Primeira execução com volume vazio: inicializa o diretório de dados
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[rangoja] Inicializando diretório de dados do MySQL..."
    mysqld --initialize-insecure --user=mysql
fi

echo "[rangoja] Iniciando MySQL..."
mysqld --user=mysql &
MYSQL_PID=$!

for i in $(seq 1 60); do
    mysqladmin -uroot ping >/dev/null 2>&1 && break
    sleep 1
done

# Primeira execução: cria o usuário do DBA e carrega o banco da empresa
if [ ! -f /var/lib/mysql/.rangoja-instalado ]; then
    echo "[rangoja] Criando usuário dba e carregando o banco (leva cerca de 1 minuto)..."
    mysql -uroot <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;
CREATE USER IF NOT EXISTS 'dba'@'localhost' IDENTIFIED BY 'Dba@Rango2026';
GRANT ALL PRIVILEGES ON *.* TO 'dba'@'localhost' WITH GRANT OPTION;
SQL
    /usr/local/bin/aula base
    touch /var/lib/mysql/.rangoja-instalado
    echo "[rangoja] Banco carregado."
fi

# Desliga o MySQL com segurança quando o container for parado
trap 'echo "[rangoja] Desligando..."; mysqladmin -uroot shutdown; kill $SSHD_PID 2>/dev/null; exit 0' TERM INT

/usr/sbin/sshd -D -e &
SSHD_PID=$!

echo "[rangoja] Servidor pronto. Acesse com: ssh dba@localhost -p 2222 (senha: dba)"
wait -n $MYSQL_PID $SSHD_PID
