#!/usr/bin/env bash
#
# 05 - Constroi as imagens localmente e as publica no ACR.
#
# O RM do representante e PREFIXO do nome das duas imagens, conforme
# exigido pelo enunciado:
#     rm561940-db-dimdim:v1
#     rm561940-app-dimdim:v1
#
# --platform linux/amd64 e explicito: o ACI so executa amd64. Sem a flag,
# uma maquina arm64 produziria imagem que falha com "exec format error".
#
# Projeto DimDim - Grupo lupeol - RM561940
#
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

exigir_comando az
exigir_comando docker

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

# No Git Bash do Windows o `pwd` devolve um caminho no estilo Unix
# (/c/Users/...), que o docker.exe nao reconhece. `pwd -W` entrega a forma
# nativa (C:/Users/...). Em Linux e macOS a opcao nao existe e o caminho
# original e mantido.
if RAIZ_NATIVA="$(cd "${RAIZ}" && pwd -W 2>/dev/null)"; then
    RAIZ="${RAIZ_NATIVA}"
fi

titulo "05 - BUILD E PUSH DAS IMAGENS"
echo "Registry : ${ACR_LOGIN_SERVER}"
echo "Imagens  : ${IMAGE_DB}:${IMAGE_TAG}"
echo "           ${IMAGE_APP}:${IMAGE_TAG}"

titulo "AUTENTICACAO NO REGISTRY"
# az acr login usa o token da sessao az; nenhuma senha trafega no comando.
az acr login --name "${ACR_NAME}"

titulo "BUILD DA IMAGEM DO BANCO"
docker build --platform linux/amd64 \
    -t "${ACR_LOGIN_SERVER}/${IMAGE_DB}:${IMAGE_TAG}" \
    "${RAIZ}/db"

titulo "BUILD DA IMAGEM DA APLICACAO"
docker build --platform linux/amd64 \
    -t "${ACR_LOGIN_SERVER}/${IMAGE_APP}:${IMAGE_TAG}" \
    "${RAIZ}/app"

titulo "PUSH DA IMAGEM DO BANCO"
docker push "${ACR_LOGIN_SERVER}/${IMAGE_DB}:${IMAGE_TAG}"

titulo "PUSH DA IMAGEM DA APLICACAO"
docker push "${ACR_LOGIN_SERVER}/${IMAGE_APP}:${IMAGE_TAG}"

titulo "REPOSITORIOS NO ACR"
az acr repository list --name "${ACR_NAME}" --output table

titulo "VERIFICACAO DE ARQUITETURA"
# Precisa imprimir amd64 para as duas imagens.
for imagem in "${IMAGE_DB}" "${IMAGE_APP}"; do
    echo -n "${imagem}:${IMAGE_TAG} -> "
    docker manifest inspect "${ACR_LOGIN_SERVER}/${imagem}:${IMAGE_TAG}" \
        | grep -i '"architecture"' | head -1 | tr -d ' ",' | cut -d: -f2
done

titulo "TAGS PUBLICADAS"
for imagem in "${IMAGE_DB}" "${IMAGE_APP}"; do
    az acr repository show-tags --name "${ACR_NAME}" \
                                --repository "${imagem}" \
                                --output table
done
