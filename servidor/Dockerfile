# Servidor de "produção" do RangoJá: Ubuntu + MySQL 8 + SSH
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Sao_Paulo \
    LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        mysql-server mysql-client openssh-server sudo tzdata \
        gzip less nano vim-tiny procps htop \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Usuário do sistema operacional usado pelo DBA (senha: dba)
RUN useradd -m -s /bin/bash -G adm dba \
    && echo 'dba:dba' | chpasswd \
    && mkdir -p /backup /dados \
    && chown dba:dba /backup \
    && chown mysql:dba /dados && chmod 2775 /dados

COPY rangoja.cnf  /etc/mysql/mysql.conf.d/zz-rangoja.cnf
COPY my.cnf       /home/dba/.my.cnf
COPY motd         /etc/motd
COPY aula         /usr/local/bin/aula
COPY entrypoint.sh /entrypoint.sh

# Remove finais de linha do Windows (CRLF), caso o Git tenha convertido os arquivos
RUN sed -i 's/\r$//' /usr/local/bin/aula /entrypoint.sh /etc/motd \
        /etc/mysql/mysql.conf.d/zz-rangoja.cnf /home/dba/.my.cnf

RUN chown dba:dba /home/dba/.my.cnf && chmod 600 /home/dba/.my.cnf \
    && chmod +x /usr/local/bin/aula /entrypoint.sh \
    && rm -f /etc/update-motd.d/* \
    && echo 'LANG=C.UTF-8' >> /etc/environment \
    && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && ssh-keygen -A \
    && echo 'export PS1="\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "' >> /home/dba/.bashrc

EXPOSE 22
VOLUME ["/var/lib/mysql"]
ENTRYPOINT ["/entrypoint.sh"]
