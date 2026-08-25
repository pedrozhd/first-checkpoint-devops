# =====================================================================
# Projeto DimDim - Imagem do Banco de Dados (MySQL 8.0)
# Grupo lupeol - RM561940 / RM563558 / RM564495
#
# O enunciado exige "criar as imagens do projeto com um Dockerfile
# (Banco e App)". Apontar o ACI diretamente para mysql:8.0 nao cumpre
# esse requisito - por isso esta imagem propria.
#
# NENHUMA senha em ENV: as credenciais chegam por variavel de ambiente
# do ACI (--secure-environment-variables), lidas do Key Vault.
# =====================================================================
FROM mysql:8.0

# innodb_use_native_aio=0 - obrigatorio para o MySQL iniciar sobre
# Azure Files (CIFS), que nao suporta AIO nativo do InnoDB.
COPY my.cnf /etc/mysql/conf.d/my.cnf

# Executado pelo entrypoint APENAS quando o datadir esta vazio.
# Se o File Share ja contiver dados, este script e ignorado silenciosamente.
COPY init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 3306
