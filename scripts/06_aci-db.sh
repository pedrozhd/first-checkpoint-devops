#!/usr/bin/env bash
#
# 06 - Cria o ACI do BANCO DE DADOS (container group #1 de 2).
#
# Pontos que o enunciado cobra e que estao implementados aqui:
#   - imagem vinda do ACR (nunca do Docker Hub)
#   - RM561940 como PREFIXO do nome do ACI
#   - persistencia em Conta de Armazenamento via Azure Files montado
#     em /var/lib/mysql
#   - senhas por --secure-environment-variables (com
#     --environment-variables elas apareceriam em texto claro no
#     `az container show` e no Portal)
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az

# O Git Bash do Windows converte argumentos que parecem caminho absoluto
# ("/var/lib/mysql") para a forma nativa ("C:/Program Files/Git/var/...")
# antes de repassa-los ao az.cmd, e o ACI rejeita o ':' resultante.
# A variavel desliga essa traducao. Em Linux e macOS ela e inofensiva.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

titulo "06 - ACI DO BANCO DE DADOS"
echo "ACI     : ${ACI_DB}"
echo "Imagem  : ${ACR_LOGIN_SERVER}/${IMAGE_DB}:${IMAGE_TAG}"
echo "Volume  : ${FILE_SHARE} -> /var/lib/mysql"
echo "FQDN    : ${DNS_DB}.${LOCATION}.azurecontainer.io"

if az container show --resource-group "${RESOURCE_GROUP}" \
                     --name "${ACI_DB}" >/dev/null 2>&1; then
    echo ""
    echo "AVISO: o ACI '${ACI_DB}' ja existe."
    echo "Para recria-lo, remova-o antes:"
    echo "    az container delete -g ${RESOURCE_GROUP} -n ${ACI_DB} --yes"
    exit 0
fi

titulo "LEITURA DE CREDENCIAIS (runtime, nada em disco)"

ACR_USERNAME=$(az acr credential show --name "${ACR_NAME}" \
                                      --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" \
                                      --query "passwords[0].value" --output tsv)
echo "  credencial do ACR ............ lida"

STORAGE_KEY=$(az storage account keys list \
                  --resource-group "${RESOURCE_GROUP}" \
                  --account-name "${STORAGE_ACCOUNT}" \
                  --query "[0].value" --output tsv)
echo "  chave da conta de storage .... lida"

MYSQL_ROOT_PASSWORD=$(ler_segredo "${SECRET_ROOT_PASSWORD}")
MYSQL_PASSWORD=$(ler_segredo "${SECRET_APP_PASSWORD}")
echo "  senhas do Key Vault .......... lidas"

titulo "CRIACAO DO CONTAINER GROUP"

az container create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACI_DB}" \
    --image "${ACR_LOGIN_SERVER}/${IMAGE_DB}:${IMAGE_TAG}" \
    --location "${LOCATION}" \
    --os-type Linux \
    --cpu 1 \
    --memory 2 \
    --registry-login-server "${ACR_LOGIN_SERVER}" \
    --registry-username "${ACR_USERNAME}" \
    --registry-password "${ACR_PASSWORD}" \
    --ports 3306 \
    --ip-address Public \
    --dns-name-label "${DNS_DB}" \
    --restart-policy Always \
    --azure-file-volume-account-name "${STORAGE_ACCOUNT}" \
    --azure-file-volume-account-key "${STORAGE_KEY}" \
    --azure-file-volume-share-name "${FILE_SHARE}" \
    --azure-file-volume-mount-path /var/lib/mysql \
    --environment-variables \
        MYSQL_DATABASE="${MYSQL_DATABASE}" \
        MYSQL_USER="${MYSQL_USER}" \
    --secure-environment-variables \
        MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
        MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
    --output table

# As variaveis com segredo saem da memoria do shell assim que o comando termina.
unset ACR_PASSWORD STORAGE_KEY MYSQL_ROOT_PASSWORD MYSQL_PASSWORD

titulo "AGUARDANDO O MYSQL FICAR PRONTO"
echo "Fazendo poll em 'az container logs' ate aparecer 'ready for connections'."
echo "Timeout: 5 minutos."

PRONTO=0
for tentativa in $(seq 1 30); do
    if az container logs --resource-group "${RESOURCE_GROUP}" \
                         --name "${ACI_DB}" 2>/dev/null \
       | grep -q "ready for connections"; then
        echo ""
        echo "MySQL pronto apos aproximadamente $((tentativa * 10)) segundos."
        PRONTO=1
        break
    fi
    printf "."
    sleep 10
done

if [[ "${PRONTO}" -eq 0 ]]; then
    echo ""
    echo "ERRO: o MySQL nao ficou pronto em 5 minutos." >&2
    echo "Ultimas linhas do log:" >&2
    az container logs --resource-group "${RESOURCE_GROUP}" --name "${ACI_DB}" 2>&1 | tail -30 >&2
    exit 1
fi

titulo "RESULTADO"
az container show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACI_DB}" \
    --query "{aci:name, estado:instanceView.state, fqdn:ipAddress.fqdn, ip:ipAddress.ip}" \
    --output table

echo ""
echo "FQDN do banco (usado pelo script 07):"
az container show --resource-group "${RESOURCE_GROUP}" \
                  --name "${ACI_DB}" \
                  --query ipAddress.fqdn --output tsv
