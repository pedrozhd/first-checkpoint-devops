#!/usr/bin/env bash
#
# 03 - Cria a Conta de Armazenamento e o File Share que persiste o MySQL.
#
# O enunciado exige "persistir os dados do banco em uma Conta de
# Armazenamento". O share e montado em /var/lib/mysql no ACI do banco,
# entao os dados sobrevivem ao restart e a recriacao do container.
#
# Usa `az storage share-rm` (plano de controle ARM) em vez de
# `az storage share`: o segundo exigiria passar a chave da conta no
# comando, expondo credencial no historico do shell.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az

titulo "03 - CONTA DE ARMAZENAMENTO"
echo "Conta      : ${STORAGE_ACCOUNT}"
echo "File Share : ${FILE_SHARE}"
echo "Cota       : 5 GiB"

if az storage account show --name "${STORAGE_ACCOUNT}" \
                           --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo ""
    echo "AVISO: a conta '${STORAGE_ACCOUNT}' ja existe. Nada a fazer."
else
    az storage account create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${STORAGE_ACCOUNT}" \
        --location "${LOCATION}" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --tags disciplina="${TAG_DISCIPLINA}" \
               checkpoint="${TAG_CHECKPOINT}" \
               grupo="${TAG_GRUPO}" \
        --output table
fi

titulo "FILE SHARE"
if az storage share-rm show --storage-account "${STORAGE_ACCOUNT}" \
                            --resource-group "${RESOURCE_GROUP}" \
                            --name "${FILE_SHARE}" >/dev/null 2>&1; then
    echo "AVISO: o share '${FILE_SHARE}' ja existe. Nada a fazer."
else
    az storage share-rm create \
        --resource-group "${RESOURCE_GROUP}" \
        --storage-account "${STORAGE_ACCOUNT}" \
        --name "${FILE_SHARE}" \
        --quota 5 \
        --output table
fi

titulo "RESULTADO"
az storage share-rm show \
    --resource-group "${RESOURCE_GROUP}" \
    --storage-account "${STORAGE_ACCOUNT}" \
    --name "${FILE_SHARE}" \
    --query "{share:name, cotaGiB:shareQuota, conta:'${STORAGE_ACCOUNT}'}" \
    --output table

echo ""
echo "A chave da conta NAO e exibida aqui. Ela e lida em runtime pelo"
echo "script 06_aci-db.sh, no momento de montar o volume."
