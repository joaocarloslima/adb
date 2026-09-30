# RangoJá — Administração de Banco de Dados na prática

Você acaba de ser contratado como **DBA do RangoJá**, um app de delivery com 50 mil clientes,
400 restaurantes e 200 mil pedidos. Este repositório sobe, no seu computador, uma cópia do
servidor de produção da empresa para você repetir tudo o que foi feito nas aulas.

| Aula | Incidente | Conteúdo |
|------|-----------|----------|
| 1 | Primeiro dia como DBA | Dicionário de dados, usuários, `GRANT` / `REVOKE`, senhas |
| 2 | O banco sumiu! | Backup, restore, importação e exportação |
| 3 | A consulta lenta | `EXPLAIN`, índices, teste de carga, compressão |
| 4 | Incidente em produção | Logs, transações, locks e deadlocks |
| 5 | Deixe o banco trabalhar sozinho | Views, triggers, eventos e backup automático |

## Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows, macOS ou Linux)
- Um terminal com cliente SSH (no Windows, o PowerShell já tem)

## Subindo o servidor

```bash
git clone <url-deste-repositorio> rangoja-dba
cd rangoja-dba
docker compose up -d --build
docker compose logs -f        # aguarde "Servidor pronto" e saia com Ctrl+C
```

Na primeira vez, a imagem é construída e o banco é carregado. Isso leva alguns minutos.

## Acessando como DBA

```bash
ssh dba@localhost -p 2222     # senha: dba
mysql                         # já entra como o usuário dba do MySQL
```

O MySQL só aceita conexões de dentro do servidor (`bind-address = 127.0.0.1`).
Assim como em uma empresa de verdade, o acesso é feito pelo SSH.

| O quê | Onde |
|-------|------|
| Logs do MySQL | `/var/log/mysql` |
| Pasta de importação/exportação | `/dados` |
| Pasta de backups | `/backup` |

## Preparando o cenário de uma aula

Cada aula começa com o banco em um estado específico (com os problemas "plantados").
No seu computador, dentro da pasta do repositório:

```bash
docker compose exec servidor aula 1     # troque pelo número da aula
```

O comando recria o banco do zero, então tudo o que foi feito antes é perdido.
Os comandos usados em cada aula estão em `aulas/aulaNN/gabarito.sql`.

## Problemas comuns

**`REMOTE HOST IDENTIFICATION HAS CHANGED` ao conectar:** a imagem foi reconstruída e a chave
do servidor mudou. Rode `ssh-keygen -R "[localhost]:2222"` e conecte de novo.

**Porta 2222 em uso:** troque a porta em `docker-compose.yml` (por exemplo `"2200:22"`)
e conecte com `-p 2200`.

**Começar tudo do zero:** `docker compose down -v` apaga o volume com os dados.
