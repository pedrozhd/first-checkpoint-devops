#!/usr/bin/env bash
#
# 08 - Exercita os 10 endpoints da API contra o FQDN PUBLICO do ACI.
#
# Todas as chamadas partem da maquina local e usam o endereco publico -
# nao ha nenhuma chamada de loopback aqui. E este script que comprova
# que a solucao esta acessivel pela internet, e nao apenas dentro do
# container.
#
# Cada operacao imprime o status HTTP esperado ao lado do obtido.
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az
exigir_comando curl

titulo "08 - SMOKE TESTS EM NUVEM"

APP_FQDN=$(az container show \
               --resource-group "${RESOURCE_GROUP}" \
               --name "${ACI_APP}" \
               --query ipAddress.fqdn --output tsv)

if [[ -z "${APP_FQDN}" ]]; then
    echo "ERRO: nao foi possivel obter o FQDN do ACI '${ACI_APP}'." >&2
    exit 1
fi

API="http://${APP_FQDN}:8080/api"
echo "Endpoint base: ${API}"

CORPO="$(mktemp)"
trap 'rm -f "${CORPO}"' EXIT

FALHAS=0

# chamar <esperado> <rotulo> <args do curl...>
chamar() {
    local esperado="$1"; shift
    local rotulo="$1"; shift
    local obtido
    obtido=$(curl -s -o "${CORPO}" -w "%{http_code}" "$@")

    if [[ "${obtido}" == "${esperado}" ]]; then
        printf "  [ OK ] %-46s %s\n" "${rotulo}" "${obtido}"
    else
        printf "  [FALHA] %-45s esperado %s, obtido %s\n" "${rotulo}" "${esperado}" "${obtido}"
        FALHAS=$((FALHAS + 1))
    fi
}

titulo "TABELA CLIENTE"

chamar 201 "POST   /clientes" \
    -X POST "${API}/clientes" \
    -H "Content-Type: application/json" \
    -d '{"nome":"Cliente Smoke Test","cpf":"10120230340","email":"smoke@dimdim.com"}'

ID_CLIENTE=$(grep -o '"idCliente":[0-9]*' "${CORPO}" | head -1 | cut -d: -f2)
echo "         id_cliente criado: ${ID_CLIENTE}"

chamar 200 "GET    /clientes (lista)"     "${API}/clientes"
chamar 200 "GET    /clientes/${ID_CLIENTE}"          "${API}/clientes/${ID_CLIENTE}"

chamar 200 "PUT    /clientes/${ID_CLIENTE}" \
    -X PUT "${API}/clientes/${ID_CLIENTE}" \
    -H "Content-Type: application/json" \
    -d '{"nome":"Cliente Smoke Test ALTERADO","cpf":"10120230340","email":"smoke.alterado@dimdim.com"}'

titulo "TABELA TRANSACAO"

chamar 201 "POST   /transacoes" \
    -X POST "${API}/transacoes" \
    -H "Content-Type: application/json" \
    -d "{\"idCliente\":${ID_CLIENTE},\"descricao\":\"Transacao Smoke Test\",\"valor\":199.90,\"tipo\":\"CREDITO\"}"

ID_TRANSACAO=$(grep -o '"idTransacao":[0-9]*' "${CORPO}" | head -1 | cut -d: -f2)
echo "         id_transacao criada: ${ID_TRANSACAO}"

chamar 200 "GET    /transacoes (lista)"   "${API}/transacoes"
chamar 200 "GET    /transacoes/${ID_TRANSACAO}"      "${API}/transacoes/${ID_TRANSACAO}"

chamar 200 "PUT    /transacoes/${ID_TRANSACAO}" \
    -X PUT "${API}/transacoes/${ID_TRANSACAO}" \
    -H "Content-Type: application/json" \
    -d "{\"idCliente\":${ID_CLIENTE},\"descricao\":\"Transacao Smoke Test ALTERADA\",\"valor\":250.00,\"tipo\":\"DEBITO\"}"

titulo "INTEGRIDADE REFERENCIAL"

# A FK e ON DELETE RESTRICT: apagar o cliente antes da transacao precisa
# devolver 409, e nao 500.
chamar 409 "DELETE /clientes/${ID_CLIENTE} (com transacao)" \
    -X DELETE "${API}/clientes/${ID_CLIENTE}"

titulo "EXCLUSAO NA ORDEM CORRETA"

chamar 204 "DELETE /transacoes/${ID_TRANSACAO}" -X DELETE "${API}/transacoes/${ID_TRANSACAO}"
chamar 404 "GET    /transacoes/${ID_TRANSACAO} (apos delete)" "${API}/transacoes/${ID_TRANSACAO}"
chamar 204 "DELETE /clientes/${ID_CLIENTE}"     -X DELETE "${API}/clientes/${ID_CLIENTE}"
chamar 404 "GET    /clientes/${ID_CLIENTE} (apos delete)"     "${API}/clientes/${ID_CLIENTE}"

titulo "RESUMO"
if [[ "${FALHAS}" -eq 0 ]]; then
    echo "Todos os testes passaram."
else
    echo "${FALHAS} teste(s) falharam." >&2
    exit 1
fi
