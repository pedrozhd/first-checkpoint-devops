# Projeto DimDim — Containers em Nuvem (ACR/ACI)

**FIAP · Tecnologia em Desenvolvimento de Sistemas**
**DevOps Tools & Cloud Computing — 1º Checkpoint, 2º Semestre**

Aplicação Java (Spring Boot) e banco MySQL 8.0, ambos containerizados, com
imagens publicadas no **Azure Container Registry** e executadas em **dois
Azure Container Instances separados**, com persistência em **Azure Files** e
segredos no **Azure Key Vault**.

---

## Grupo lupeol

| RM | Nome | Papel |
|---|---|---|
| RM561940 | Pedro França | Representante |
| RM563558 | Olavo Neves | |
| RM564495 | Luiz Gonçalves | |

---

## Arquitetura

```
                    ┌──────────────────────────────────┐
                    │   Azure Container Registry       │
                    │   acrdimdimrm561940.azurecr.io   │
                    │                                  │
                    │   rm561940-db-dimdim:v1          │
                    │   rm561940-app-dimdim:v1         │
                    └───────────┬──────────────────────┘
                                │ pull
            ┌───────────────────┴───────────────────┐
            │                                       │
┌───────────▼────────────┐            ┌─────────────▼───────────┐
│  ACI #1                │            │  ACI #2                 │
│  rm561940-aci-db       │   JDBC     │  rm561940-aci-app       │
│                        │ ◄──────────┤                         │
│  MySQL 8.0             │   :3306    │  Spring Boot / Java 21  │
│  1 vCPU · 2 GB         │ via FQDN   │  1 vCPU · 1.5 GB        │
│  porta 3306 pública    │  público   │  porta 8080 pública     │
│                        │            │  usuário não-root       │
└───────────┬────────────┘            └─────────────┬───────────┘
            │ monta                                 │ lê segredo
┌───────────▼────────────┐            ┌─────────────▼───────────┐
│  Storage Account       │            │  Azure Key Vault        │
│  stdimdimrm561940      │            │  kv-dimdim-rm561940     │
│                        │            │                         │
│  File Share (5 GiB)    │            │  mysql-root-password    │
│  → /var/lib/mysql      │            │  mysql-app-password     │
└────────────────────────┘            └─────────────────────────┘
```

**Por que dois ACIs e não um container group multi-container?** É exigência
literal do enunciado ("Criar dois ACIs com base nas duas imagens registradas
no ACR"). Como os dois grupos não compartilham rede interna, a aplicação
alcança o banco pelo **FQDN público** do ACI do banco.

---

## Modelo de dados

Duas tabelas com relacionamento 1:N — `cliente (1) ──< (N) transacao`.

| `cliente` | Tipo | Constraint |
|---|---|---|
| `id_cliente` | BIGINT | PK, AUTO_INCREMENT |
| `nome` | VARCHAR(120) | NOT NULL |
| `cpf` | VARCHAR(11) | NOT NULL, UNIQUE |
| `email` | VARCHAR(150) | NOT NULL |
| `data_cadastro` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

| `transacao` | Tipo | Constraint |
|---|---|---|
| `id_transacao` | BIGINT | PK, AUTO_INCREMENT |
| `id_cliente` | BIGINT | NOT NULL, FK → `cliente` |
| `descricao` | VARCHAR(200) | NOT NULL |
| `valor` | DECIMAL(15,2) | NOT NULL |
| `tipo` | VARCHAR(10) | NOT NULL, CHECK IN ('CREDITO','DEBITO') |
| `data_transacao` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

A FK usa **`ON DELETE RESTRICT`**: apagar um cliente que possua transações
falha no banco, e a API devolve **409 Conflict** com mensagem legível. Para
excluir um cliente é preciso apagar antes as suas transações.

DDL completo: [`docs/DDL.sql`](docs/DDL.sql)

---

## Endpoints

| Recurso | Método | Retorno |
|---|---|---|
| `/api/clientes` | `GET` | 200 |
| `/api/clientes/{id}` | `GET` | 200 · 404 |
| `/api/clientes` | `POST` | 201 + `Location` · 400 · 409 |
| `/api/clientes/{id}` | `PUT` | 200 · 400 · 404 · 409 |
| `/api/clientes/{id}` | `DELETE` | 204 · 404 · **409** |
| `/api/transacoes` | `GET` | 200 |
| `/api/transacoes/{id}` | `GET` | 200 · 404 |
| `/api/transacoes` | `POST` | 201 + `Location` · 400 · 404 |
| `/api/transacoes/{id}` | `PUT` | 200 · 400 · 404 |
| `/api/transacoes/{id}` | `DELETE` | 204 · 404 |

Exemplos de payload: [`tests/json/`](tests/json/)

---

## Pré-requisitos

| Ferramenta | Versão usada |
|---|---|
| Azure CLI | 2.84.0 |
| Docker | 29.7.2 (engine Linux, WSL2) |
| Git | 2.55.0 |
| JDK | 21 (Temurin) — opcional, o build roda no Docker |

Maven **não** precisa estar instalado: o projeto traz o Maven Wrapper
(`app/mvnw`) e o build de produção acontece dentro do `app/Dockerfile`.

É necessária uma assinatura Azure com permissão para criar ACR, ACI, Storage
Account e Key Vault na região **brazilsouth**.

---

## How To — passo a passo

### 1. Clonar o repositório

```bash
git clone https://github.com/pedrozhd/first-checkpoint-devops.git
cd first-checkpoint-devops
chmod +x scripts/*.sh
```

### 2. Autenticar na Azure

```bash
az login
az account show
```

### 3. Validação local (recomendada antes de subir para a nuvem)

Gera as senhas do ambiente local — nenhum valor literal é versionado:

```bash
./scripts/00_local-env.sh
set -a; source .env; set +a
```

Prepara rede e volume, e constrói as duas imagens:

```bash
docker network create dimdim-net
docker volume create dimdim-data

docker build --platform linux/amd64 -t rm561940-db-dimdim:v1 ./db
docker build --platform linux/amd64 -t rm561940-app-dimdim:v1 ./app
```

Sobe o banco e aguarda ficar pronto:

```bash
docker run -d --name db-local --network dimdim-net \
  -v dimdim-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  -e MYSQL_DATABASE=db_dimdim \
  -e MYSQL_USER=user_dimdim \
  -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  -p 3306:3306 rm561940-db-dimdim:v1

docker logs -f db-local   # aguarde "ready for connections"
```

Sobe a aplicação:

```bash
docker run -d --name app-local --network dimdim-net \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://db-local:3306/db_dimdim?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
  -e SPRING_DATASOURCE_USERNAME=user_dimdim \
  -e SPRING_DATASOURCE_PASSWORD="$MYSQL_PASSWORD" \
  -p 8080:8080 rm561940-app-dimdim:v1
```

Prova de que o container da aplicação **não roda como root**:

```bash
docker exec app-local id
# uid=10001(appuser) gid=999(appuser) groups=999(appuser)
```

### 4. Provisionar a infraestrutura na Azure

Execute os scripts **na ordem**, um por vez:

```bash
./scripts/01_resource-group.sh      # grupo de recursos
./scripts/02_acr.sh                 # container registry (SKU Basic)
./scripts/03_storage-account.sh     # storage account + file share
./scripts/04_key-vault.sh           # cofre + senhas geradas em runtime
```

### 5. Build e push das imagens para o ACR

Este é o passo que registra as imagens no ACR com o **RM do representante
como prefixo**:

```bash
./scripts/05_build-push.sh
```

Os comandos executados por ele, na íntegra:

```bash
az acr login --name acrdimdimrm561940

docker build --platform linux/amd64 \
    -t acrdimdimrm561940.azurecr.io/rm561940-db-dimdim:v1 ./db

docker build --platform linux/amd64 \
    -t acrdimdimrm561940.azurecr.io/rm561940-app-dimdim:v1 ./app

docker push acrdimdimrm561940.azurecr.io/rm561940-db-dimdim:v1
docker push acrdimdimrm561940.azurecr.io/rm561940-app-dimdim:v1

az acr repository list --name acrdimdimrm561940 --output table
```

> **Alternativa — build do lado da Azure.** O ACR é capaz de compilar a
> imagem por conta própria, através de uma ACR Task, dispensando Docker na
> máquina local:
>
> ```bash
> az acr build --registry acrdimdimrm561940 \
>     --image rm561940-app-dimdim:v1 \
>     --platform linux/amd64 ./app
> ```
>
> Este projeto **não** usa esse caminho: o enunciado pede o build local, o
> teste local e a entrega dos comandos `docker build` e `docker push`. Fica
> registrado como referência.

### 6. Subir os dois ACIs

```bash
./scripts/06_aci-db.sh    # aguarda "ready for connections" (timeout 5 min)
./scripts/07_aci-app.sh   # descobre o FQDN do banco automaticamente
```

### 7. Testar em nuvem

```bash
./scripts/08_smoke-tests.sh
```

---

## Como testar manualmente

Descubra o FQDN da aplicação:

```bash
APP_FQDN=$(az container show \
    --resource-group rg-dimdim-rm561940 \
    --name rm561940-aci-app \
    --query ipAddress.fqdn --output tsv)
```

### Clientes

```bash
curl -X GET http://$APP_FQDN:8080/api/clientes

curl -X GET http://$APP_FQDN:8080/api/clientes/1

curl -X POST http://$APP_FQDN:8080/api/clientes \
  -H "Content-Type: application/json" \
  -d '{"nome":"Ana Souza","cpf":"11122233344","email":"ana.souza@exemplo.com"}'

curl -X PUT http://$APP_FQDN:8080/api/clientes/1 \
  -H "Content-Type: application/json" \
  -d '{"nome":"Ana Souza Silva","cpf":"11122233344","email":"ana.silva@exemplo.com"}'

curl -X DELETE http://$APP_FQDN:8080/api/clientes/1
```

### Transações

```bash
curl -X GET http://$APP_FQDN:8080/api/transacoes

curl -X GET http://$APP_FQDN:8080/api/transacoes/1

curl -X POST http://$APP_FQDN:8080/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{"idCliente":1,"descricao":"Deposito inicial","valor":1500.00,"tipo":"CREDITO"}'

curl -X PUT http://$APP_FQDN:8080/api/transacoes/1 \
  -H "Content-Type: application/json" \
  -d '{"idCliente":1,"descricao":"Deposito ALTERADO","valor":1750.50,"tipo":"CREDITO"}'

curl -X DELETE http://$APP_FQDN:8080/api/transacoes/1
```

### Evidência das operações no banco (SELECT)

As evidências de CRUD são colhidas **dentro do container do banco**, não pela
resposta da API:

```bash
az container exec \
    --resource-group rg-dimdim-rm561940 \
    --name rm561940-aci-db \
    --exec-command "/bin/bash"
```

Já dentro do container:

```sql
mysql -uuser_dimdim -p
USE db_dimdim;
SELECT * FROM cliente;
SELECT * FROM transacao;
```

### Prova de container não-root

```bash
az container exec \
    --resource-group rg-dimdim-rm561940 \
    --name rm561940-aci-app \
    --exec-command "id"
# uid=10001(appuser) gid=999(appuser) groups=999(appuser)
```

---

## Estrutura do repositório

```
.
├── README.md
├── .env.example              modelo de variáveis locais (sem valores)
├── .gitignore
├── app/                      aplicação Spring Boot
│   ├── Dockerfile            multi-stage, usuário não-root
│   ├── pom.xml
│   └── src/main/java/br/com/fiap/dimdim/
│       ├── entity/  repository/  dto/  controller/  exception/
├── db/                       banco MySQL
│   ├── Dockerfile
│   ├── init.sql              DDL + seed inicial
│   └── my.cnf                innodb_use_native_aio=0
├── docs/
│   ├── DDL.sql               script de banco entregue
│   └── ROTEIRO_VIDEO.md
├── scripts/                  provisionamento via Azure CLI
│   ├── 00_local-env.sh       00_variables.sh
│   ├── 01_resource-group.sh  02_acr.sh
│   ├── 03_storage-account.sh 04_key-vault.sh
│   ├── 05_build-push.sh      06_aci-db.sh
│   ├── 07_aci-app.sh         08_smoke-tests.sh
│   └── 99_cleanup.sh
└── tests/json/               payloads usados nos testes
    ├── cliente/    get.json  post.json  put.json  delete.json
    └── transacao/  get.json  post.json  put.json  delete.json
```

---

## Segurança

- Nenhuma senha, chave ou token é versionada. O `.env` local está no
  `.gitignore` e as senhas da nuvem nascem no `04_key-vault.sh` via
  `openssl rand`, guardadas no Key Vault.
- Os ACIs recebem as senhas por **`--secure-environment-variables`**. Com
  `--environment-variables` elas apareceriam em texto claro no
  `az container show` e no Portal.
- As credenciais do ACR e a chave da Storage Account são lidas em tempo de
  execução (`az acr credential show`, `az storage account keys list`) e
  descartadas com `unset` ao fim do script.
- O container da aplicação roda como `appuser` (uid 10001), sem privilégios
  administrativos.
- O `application.properties` não tem valores default: sem as variáveis de
  ambiente a aplicação sequer inicia.

### Limitações conhecidas (contexto acadêmico)

Este é um projeto de avaliação, com ambiente efêmero e dados fictícios. As
decisões abaixo seriam **inadequadas em produção** e estão registradas de
forma deliberada:

| Limitação | Motivo |
|---|---|
| A API não tem autenticação nem autorização | O escopo avaliado é a conteinerização e o deploy em ACR/ACI; o enunciado não pede controle de acesso na API. Exigir token acrescentaria uma camada não avaliada e dificultaria a demonstração das operações. |
| A porta 3306 do banco fica exposta publicamente | O enunciado exige **dois ACIs separados**. Container groups distintos não compartilham rede interna, então o FQDN público é o único caminho entre a aplicação e o banco. |
| A conexão JDBC usa `useSSL=false` | Sem TLS, o `caching_sha2_password` do MySQL 8 exige `allowPublicKeyRetrieval=true`. Habilitar TLS demandaria certificado e configuração fora do escopo do checkpoint. |
| CPF e e-mail trafegam sem controle de acesso | São dados de teste inventados; nenhuma informação pessoal real é utilizada. |

Em um cenário real, o caminho seria: rede virtual privada entre os
containers (ou um único container group), TLS obrigatório no MySQL,
autenticação na API e o banco sem endereço público.

---

## Como derrubar o ambiente

Para economizar entre sessões **sem perder nada** — ACI parado não cobra
compute e os dados continuam no File Share:

```bash
az container stop -g rg-dimdim-rm561940 -n rm561940-aci-db
az container stop -g rg-dimdim-rm561940 -n rm561940-aci-app

# para religar
az container start -g rg-dimdim-rm561940 -n rm561940-aci-db
az container start -g rg-dimdim-rm561940 -n rm561940-aci-app
```

Para remover **tudo** (destrutivo e irreversível):

```bash
./scripts/99_cleanup.sh
```

O script pede confirmação digitada. Ele apaga o grupo de recursos inteiro,
incluindo as imagens no ACR e os dados do banco no File Share.

> O Key Vault entra em exclusão reversível por 90 dias. Para reutilizar o
> mesmo nome antes disso é preciso
> `az keyvault purge --name kv-dimdim-rm561940`.

---

## Observações técnicas

**`allowPublicKeyRetrieval=true` na URL JDBC** — o MySQL 8 usa
`caching_sha2_password` por padrão. Sem TLS e sem esse parâmetro, o driver
falha com `Public Key Retrieval is not allowed`.

**`innodb_use_native_aio=0` no `my.cnf`** — Azure Files é um share CIFS e não
suporta o AIO nativo do InnoDB. Sem essa linha o MySQL costuma falhar ao
iniciar sobre o volume.

**`--platform linux/amd64` nos builds** — o ACI executa apenas amd64. A flag é
explícita para garantir reprodutibilidade em qualquer máquina.

**`spring.jpa.hibernate.ddl-auto=validate`** — o schema é criado pelo
`init.sql`; o Hibernate apenas valida, para que o `DDL.sql` entregue seja a
fonte de verdade.

**O `init.sql` só roda com o datadir vazio.** Se o File Share já contiver
dados de uma execução anterior, o script é ignorado silenciosamente pelo
entrypoint do MySQL.
