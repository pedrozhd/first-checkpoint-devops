#!/usr/bin/env bash
#
# Projeto DimDim - Grupo lupeol
#
# Gera o arquivo .env com senhas aleatorias para a VALIDACAO LOCAL (Fase 4).
#
# As senhas NAO sao literais no codigo: sao geradas aqui, em tempo de
# execucao, e gravadas apenas no .env, que esta no .gitignore.
#
# Este script NAO tem relacao com a nuvem. As senhas dos ACIs sao outras,
# geradas e guardadas no Key Vault por scripts/04_key-vault.sh.
#
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ARQUIVO_ENV="${RAIZ}/.env"

if [[ -f "${ARQUIVO_ENV}" ]]; then
    echo "AVISO: ${ARQUIVO_ENV} ja existe."
    echo "Se voce sobrescrever, o banco local existente ficara inacessivel"
    echo "com as novas senhas (o volume dimdim-data guarda as antigas)."
    read -r -p "Sobrescrever mesmo assim? [s/N] " resposta
    if [[ ! "${resposta}" =~ ^[sS]$ ]]; then
        echo "Cancelado. Nada foi alterado."
        exit 0
    fi
fi

gerar_senha() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

umask 077   # o .env nasce legivel apenas pelo dono

cat > "${ARQUIVO_ENV}" <<EOF
# Gerado por scripts/00_local-env.sh - NAO COMMITAR
# Uso exclusivo da validacao local em Docker (Fase 4).
MYSQL_ROOT_PASSWORD=$(gerar_senha)
MYSQL_PASSWORD=$(gerar_senha)
EOF

echo "Arquivo .env criado em ${ARQUIVO_ENV}"
echo
echo "Para carregar as variaveis no terminal antes de subir os containers:"
echo "    set -a; source .env; set +a"
