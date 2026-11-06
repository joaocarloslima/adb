#!/bin/bash
# =====================================================================
# Backup do RangoJá
#   - dump completo e compactado, com data e hora no nome
#   - guarda só os 7 backups mais recentes
#   - anota cada execução em /backup/backup.log
# Para agendar:  crontab -e   (ou o comando do gabarito da Aula 5)
# =====================================================================
set -e

DESTINO=/backup
ARQUIVO="$DESTINO/rangoja-$(date +%F-%H%M).sql.gz"

mysqldump --single-transaction --routines --events --triggers rangoja | gzip > "$ARQUIVO"

# Apaga os mais antigos, mantendo os 7 últimos
ls -1t "$DESTINO"/rangoja-*.sql.gz | tail -n +8 | xargs -r rm --

echo "$(date '+%F %T') backup ok: $ARQUIVO ($(du -h "$ARQUIVO" | cut -f1))" >> "$DESTINO/backup.log"
