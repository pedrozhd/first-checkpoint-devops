# =====================================================================
# Projeto DimDim - Imagem da Aplicacao (Spring Boot / Java 21)
# Grupo lupeol - RM561940 / RM563558 / RM564495
#
# Multi-stage: o Maven vive apenas no estagio de build; a imagem final
# carrega somente o JRE e o JAR.
#
# NENHUM segredo em ENV ou ARG.
# =====================================================================

# --- build ---
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# pom.xml copiado sozinho primeiro: enquanto ele nao mudar, a camada de
# dependencias fica em cache e o rebuild nao volta a baixar tudo.
COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

# --- runtime ---
# Base jammy (tem /bin/bash). Distroless ou scratch NAO servem: sem shell
# nao ha `az container exec` e sem isso nao se prova o nao-root no video.
FROM eclipse-temurin:21-jre-jammy

# Requisito avaliado (-10 se o container do App rodar como root)
RUN groupadd -r appuser && useradd -r -g appuser -u 10001 appuser

WORKDIR /app
COPY --from=build --chown=appuser:appuser /build/target/*.jar /app/app.jar

# USER apos tudo que precisa de root
USER appuser

# Porta 8080: usuario nao-root nao consegue bind em porta < 1024
EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]
