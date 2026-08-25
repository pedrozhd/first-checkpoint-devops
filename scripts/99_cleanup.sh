#!/usr/bin/env bash
#
# 99 - Remove TODOS os recursos do projeto na Azure.
#
# ############################################################
# #  ATENCAO: ESTE SCRIPT E DESTRUTIVO E IRREVERSIVEL.       #
# #                                                          #
# #  Apaga o grupo de recursos inteiro: os dois ACIs, o ACR   #
# #  com as imagens, a Conta de Armazenamento com o File      #
# #  Share (todos os dados do MySQL) e o Key Vault.           #
# #                                                          #
# #  NAO EXECUTE antes de ter gravado o video: as evidencias  #
# #  da entrega desaparecem junto.                            #
# ############################################################
#
# Exige confirmacao digitada. Nao ha modo silencioso.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az

titulo "99 - REMOCAO DO AMBIENTE"

if ! az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "O grupo '${RESOURCE_GROUP}' nao existe. Nada a remover."
    exit 0
fi

echo "Os recursos abaixo serao APAGADOS:"
echo ""
az resource list --resource-group "${RESOURCE_GROUP}" \
    --query "[].{nome:name, tipo:type}" --output table

echo ""
echo "Isso inclui o File Share com todos os dados do banco."
echo ""
echo "Observacao sobre o Key Vault: ele entra em exclusao reversivel"
echo "(soft delete) por 90 dias. Para reutilizar o nome '${KEYVAULT_NAME}'"
echo "antes disso sera necessario purga-lo explicitamente."
echo ""

read -r -p "Digite exatamente APAGAR para confirmar: " confirmacao
if [[ "${confirmacao}" != "APAGAR" ]]; then
    echo "Cancelado. Nenhum recurso foi removido."
    exit 0
fi

titulo "REMOVENDO"
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait

echo "Remocao iniciada em segundo plano (--no-wait)."
echo ""
echo "Acompanhe com:"
echo "    az group show --name ${RESOURCE_GROUP}"
echo "Quando o grupo deixar de existir, o comando retorna erro - e o esperado."
