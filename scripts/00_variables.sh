#!/usr/bin/env bash
#
# Projeto DimDim - Grupo lupeol
# FIAP - DevOps Tools & Cloud Computing - Checkpoint 1
#
#   RM561940 - Pedro Franca   (representante)
#   RM563558 - Olavo Neves
#   RM564495 - Luiz Goncalves
#
# Centraliza os nomes de todos os recursos. NENHUMA SENHA AQUI.
# As senhas sao geradas em 04_key-vault.sh e lidas do Key Vault em runtime.
#
# Este arquivo nao e executado diretamente: e carregado com `source` pelos
# demais scripts.
#
set -euo pipefail

# --- identificacao -----------------------------------------------------
export RM="rm561940"

# --- regiao ------------------------------------------------------------
# Confirmada na Fase 0: brazilsouth esta na lista permitida pela policy
# "Allowed resource deployment regions" (canadacentral, northcentralus,
# brazilsouth, eastus, chilecentral), suporta containerGroups e tem
# 6 Standard Cores livres - precisamos de 2.
export LOCATION="brazilsouth"

# --- grupo de recursos -------------------------------------------------
export RESOURCE_GROUP="rg-dimdim-${RM}"

# --- registry / storage / cofre ----------------------------------------
# Nomes verificados como disponiveis globalmente na Fase 0.4.
export ACR_NAME="acrdimdim${RM}"
export STORAGE_ACCOUNT="stdimdim${RM}"
export FILE_SHARE="mysql-dimdim-volume"
export KEYVAULT_NAME="kv-dimdim-${RM}"

# --- imagens -----------------------------------------------------------
# O RM do representante e PREFIXO do nome da imagem (exigencia do enunciado).
export IMAGE_DB="${RM}-db-dimdim"
export IMAGE_APP="${RM}-app-dimdim"
export IMAGE_TAG="v1"

# --- instancias de container -------------------------------------------
# O RM tambem e PREFIXO do nome do ACI (exigencia do enunciado).
# Sao DOIS container groups distintos, nao um multi-container.
export ACI_DB="${RM}-aci-db"
export ACI_APP="${RM}-aci-app"

# Rotulos DNS: precisam ser unicos dentro da regiao.
export DNS_DB="${RM}-db-dimdim"
export DNS_APP="${RM}-app-dimdim"

# --- banco de dados ----------------------------------------------------
# Underscore, nunca hifen: com hifen todo `USE db-dimdim;` exigiria crases.
export MYSQL_DATABASE="db_dimdim"
export MYSQL_USER="user_dimdim"

# --- nomes dos segredos no Key Vault -----------------------------------
# Apenas os NOMES. Os valores nunca aparecem em arquivo.
export SECRET_ROOT_PASSWORD="mysql-root-password"
export SECRET_APP_PASSWORD="mysql-app-password"

# --- tags --------------------------------------------------------------
export TAG_DISCIPLINA="devops-tools-cloud-computing"
export TAG_CHECKPOINT="cp1-containers-nuvem"
export TAG_GRUPO="lupeol"

# --- derivados ---------------------------------------------------------
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# --- utilitarios usados pelos demais scripts ---------------------------

# Imprime um cabecalho de secao.
titulo() {
    echo ""
    echo "======================================================================"
    echo "  $*"
    echo "======================================================================"
}

# Aborta se um comando obrigatorio nao estiver disponivel.
exigir_comando() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERRO: comando '$1' nao encontrado no PATH." >&2
        exit 1
    fi
}

# Le um segredo do Key Vault. O valor vai para stdout e nunca para disco.
ler_segredo() {
    az keyvault secret show \
        --vault-name "${KEYVAULT_NAME}" \
        --name "$1" \
        --query value \
        --output tsv
}
