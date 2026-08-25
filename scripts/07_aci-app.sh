#!/usr/bin/env bash
#
# 07 - Cria o ACI da APLICACAO (container group #2 de 2).
#
# Sao dois ACIs SEPARADOS, nao um container group multi-container: e o
# que o enunciado pede literalmente ("Criar dois ACIs"). Como os dois
# grupos nao compartilham rede interna, a aplicacao alcanca o banco pelo
# FQDN PUBLICO do ACI do banco - descoberto aqui em runtime.
#
# Este script nao contem nenhum endereco de loopback.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az

titulo "07 - ACI DA APLICACAO"
echo "ACI    : ${ACI_APP}"
echo "Imagem : ${ACR_LOGIN_SERVER}/${IMAGE_APP}:${IMAGE_TAG}"

if az container show --resource-group "${RESOURCE_GROUP}" \
                     --name "${ACI_APP}" >/dev/null 2>&1; then
    echo ""
    echo "AVISO: o ACI '${ACI_APP}' ja existe."
    echo "Para recria-lo, remova-o antes:"
    echo "    az container delete -g ${RESOURCE_GROUP} -n ${ACI_APP} --yes"
    exit 0
fi

titulo "DESCOBERTA DO FQDN DO BANCO"

DB_FQDN=$(az container show \
              --resource-group "${RESOURCE_GROUP}" \
              --name "${ACI_DB}" \
              --query ipAddress.fqdn --output tsv)

if [[ -z "${DB_FQDN}" ]]; then
    echo "ERRO: nao foi possivel obter o FQDN do ACI '${ACI_DB}'." >&2
    echo "Execute 06_aci-db.sh antes deste script." >&2
    exit 1
fi
echo "  ${DB_FQDN}"

# allowPublicKeyRetrieval=true e OBRIGATORIO: o MySQL 8 usa
# caching_sha2_password e, sem TLS, o driver aborta com
# "Public Key Retrieval is not allowed".
JDBC_URL="jdbc:mysql://${DB_FQDN}:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
echo ""
echo "URL JDBC:"
echo "  ${JDBC_URL}"

titulo "LEITURA DE CREDENCIAIS (runtime, nada em disco)"

ACR_USERNAME=$(az acr credential show --name "${ACR_NAME}" \
                                      --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" \
                                      --query "passwords[0].value" --output tsv)
echo "  credencial do ACR ...... lida"

MYSQL_PASSWORD=$(ler_segredo "${SECRET_APP_PASSWORD}")
echo "  senha do Key Vault ..... lida"

titulo "CRIACAO DO CONTAINER GROUP"

az container create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACI_APP}" \
    --image "${ACR_LOGIN_SERVER}/${IMAGE_APP}:${IMAGE_TAG}" \
    --location "${LOCATION}" \
    --os-type Linux \
    --cpu 1 \
    --memory 1.5 \
    --registry-login-server "${ACR_LOGIN_SERVER}" \
    --registry-username "${ACR_USERNAME}" \
    --registry-password "${ACR_PASSWORD}" \
    --ports 8080 \
    --ip-address Public \
    --dns-name-label "${DNS_APP}" \
    --restart-policy Always \
    --environment-variables \
        SPRING_DATASOURCE_URL="${JDBC_URL}" \
        SPRING_DATASOURCE_USERNAME="${MYSQL_USER}" \
    --secure-environment-variables \
        SPRING_DATASOURCE_PASSWORD="${MYSQL_PASSWORD}" \
    --output table

unset ACR_PASSWORD MYSQL_PASSWORD

titulo "AGUARDANDO A APLICACAO SUBIR"
echo "E normal a aplicacao reiniciar 1 ou 2 vezes se o banco ainda estiver"
echo "aceitando as primeiras conexoes - a restart-policy e Always."
echo "Timeout: 5 minutos."

PRONTO=0
for tentativa in $(seq 1 30); do
    if az container logs --resource-group "${RESOURCE_GROUP}" \
                         --name "${ACI_APP}" 2>/dev/null \
       | grep -q "Started DimdimApplication"; then
        echo ""
        echo "Aplicacao pronta apos aproximadamente $((tentativa * 10)) segundos."
        PRONTO=1
        break
    fi
    printf "."
    sleep 10
done

if [[ "${PRONTO}" -eq 0 ]]; then
    echo ""
    echo "ERRO: a aplicacao nao subiu em 5 minutos." >&2
    echo "Ultimas linhas do log:" >&2
    az container logs --resource-group "${RESOURCE_GROUP}" --name "${ACI_APP}" 2>&1 | tail -30 >&2
    exit 1
fi

titulo "RESULTADO"
az container show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACI_APP}" \
    --query "{aci:name, estado:instanceView.state, fqdn:ipAddress.fqdn}" \
    --output table

APP_FQDN=$(az container show --resource-group "${RESOURCE_GROUP}" \
                             --name "${ACI_APP}" \
                             --query ipAddress.fqdn --output tsv)
echo ""
echo "API disponivel em:"
echo "  http://${APP_FQDN}:8080/api/clientes"
echo "  http://${APP_FQDN}:8080/api/transacoes"
