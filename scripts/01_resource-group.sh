#!/usr/bin/env bash
#
# 01 - Cria o Grupo de Recursos que abriga todo o projeto.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az

titulo "01 - GRUPO DE RECURSOS"
echo "Nome    : ${RESOURCE_GROUP}"
echo "Regiao  : ${LOCATION}"

if az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo ""
    echo "AVISO: o grupo '${RESOURCE_GROUP}' ja existe. Nada a fazer."
else
    az group create \
        --name "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --tags disciplina="${TAG_DISCIPLINA}" \
               checkpoint="${TAG_CHECKPOINT}" \
               grupo="${TAG_GRUPO}" \
        --output table
fi

titulo "RESULTADO"
az group show --name "${RESOURCE_GROUP}" \
    --query "{nome:name, regiao:location, estado:properties.provisioningState}" \
    --output table
