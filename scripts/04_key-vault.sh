#!/usr/bin/env bash
#
# 04 - Cria o Azure Key Vault e gera os segredos do MySQL.
#
# As senhas sao geradas AQUI, em tempo de execucao, com `openssl rand`.
# Nenhum valor literal existe em arquivo: os scripts 06 e 07 leem os
# segredos do cofre e os injetam nos ACIs por
# --secure-environment-variables.
#
# ATENCAO - soft delete: o Key Vault permanece "excluido reversivelmente"
# por 90 dias apos um `az group delete`. Recriar um cofre com o mesmo nome
# falha ate que ele seja purgado com:
#     az keyvault purge --name kv-dimdim-rm561940
# Avise o responsavel antes de purgar.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az
exigir_comando openssl

titulo "04 - AZURE KEY VAULT"
echo "Cofre : ${KEYVAULT_NAME}"

# Gera uma senha forte sem caracteres que quebrem URLs JDBC ou o shell.
gerar_senha() {
    openssl rand -base64 32 | tr -d '/+=\n' | head -c 28
}

if az keyvault show --name "${KEYVAULT_NAME}" \
                    --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo ""
    echo "AVISO: o cofre '${KEYVAULT_NAME}' ja existe. Nada a fazer."
else
    # Verifica se o nome esta preso em soft delete antes de tentar criar.
    if az keyvault list-deleted --query "[?name=='${KEYVAULT_NAME}'].name" \
                                --output tsv 2>/dev/null | grep -q .; then
        echo ""
        echo "ERRO: existe um cofre '${KEYVAULT_NAME}' excluido reversivelmente." >&2
        echo "Para reutilizar o nome e preciso purga-lo:" >&2
        echo "    az keyvault purge --name ${KEYVAULT_NAME}" >&2
        echo "Isso e IRREVERSIVEL. Confirme com o responsavel antes." >&2
        exit 1
    fi

    az keyvault create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${KEYVAULT_NAME}" \
        --location "${LOCATION}" \
        --enable-rbac-authorization false \
        --tags disciplina="${TAG_DISCIPLINA}" \
               checkpoint="${TAG_CHECKPOINT}" \
               grupo="${TAG_GRUPO}" \
        --output table
fi

titulo "SEGREDOS"

# Cada segredo so e criado se ainda nao existir: reexecutar o script nao
# troca a senha de um banco que ja esta no ar.
criar_segredo_se_ausente() {
    local nome="$1"
    if az keyvault secret show --vault-name "${KEYVAULT_NAME}" \
                               --name "${nome}" >/dev/null 2>&1; then
        echo "  ${nome} .......... ja existe (mantido)"
    else
        az keyvault secret set \
            --vault-name "${KEYVAULT_NAME}" \
            --name "${nome}" \
            --value "$(gerar_senha)" \
            --output none
        echo "  ${nome} .......... criado"
    fi
}

criar_segredo_se_ausente "${SECRET_ROOT_PASSWORD}"
criar_segredo_se_ausente "${SECRET_APP_PASSWORD}"

titulo "RESULTADO"
az keyvault secret list \
    --vault-name "${KEYVAULT_NAME}" \
    --query "[].{segredo:name, habilitado:attributes.enabled}" \
    --output table

echo ""
echo "Os VALORES dos segredos nunca sao impressos nem gravados em disco."
echo "Os scripts 06 e 07 os leem do cofre no momento do deploy."
