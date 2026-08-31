# Roteiro de gravação — Projeto DimDim

**Grupo lupeol** · RM561940 Pedro França · RM563558 Olavo Neves · RM564495 Luiz Gonçalves
FIAP — DevOps Tools & Cloud Computing — 1º Checkpoint

---

## Antes de apertar o REC

- [ ] Os dois ACIs em `Running` (`az container list -o table`)
- [ ] Portal Azure aberto no grupo `rg-dimdim-rm561940`
- [ ] Terminal pronto para `az`/`curl`
- [ ] MySQL Workbench **já conectado** (conecte antes de gravar, para a senha não aparecer)
- [ ] `docs/EVIDENCIAS_VIDEO.sql` aberto numa aba do Workbench
- [ ] Fonte do terminal **aumentada** — texto pequeno não se lê em vídeo
- [ ] Gravação em **1080p** (mínimo exigido: 720p), com áudio claro
- [ ] Variáveis carregadas no terminal:

```bash
source scripts/00_variables.sh
APP_FQDN=$(az container show -g $RESOURCE_GROUP -n $ACI_APP --query ipAddress.fqdn -o tsv)
echo $APP_FQDN
```

### Vocabulário — cuidado ao narrar

| Diga | Não diga |
|---|---|
| **MySQL 8.0** | Oracle *(o SGBD é MySQL; a Oracle apenas o mantém)* |
| dois **ACIs separados** | "o container" no singular |
| **FQDN público** | localhost |

Se rodar `cat /etc/os-release` no container do banco vai aparecer **Oracle
Linux** — esse é o sistema operacional da imagem oficial do MySQL, não o
banco. Se mostrar isso, explique a diferença.

---

## 1. Abertura — recursos criados na Azure

> O enunciado exige começar por aqui: *"Comece o vídeo mostrando os Recursos
> criados na Azure"*.

**No Portal**, mostre o grupo `rg-dimdim-rm561940` com os cinco recursos:

| Recurso | Nome |
|---|---|
| Container Registry | `acrdimdimrm561940` |
| Container Instances (×2) | `rm561940-aci-db` · `rm561940-aci-app` |
| Storage Account | `stdimdimrm561940` |
| Key Vault | `kv-dimdim-rm561940` |

**Narração:** apresente o grupo, os integrantes e diga que toda a
infraestrutura foi criada por script de Azure CLI, versionado no GitHub —
nada pelo Portal.

---

## 2. ACR — as duas imagens com o prefixo do RM

**No Portal:** ACR → Repositories. Mostre os dois repositórios.

**No terminal:**

```bash
az acr repository list --name acrdimdimrm561940 --output table
az acr repository show-tags --name acrdimdimrm561940 --repository rm561940-db-dimdim
az acr repository show-tags --name acrdimdimrm561940 --repository rm561940-app-dimdim
```

**Narração:** destaque que `rm561940` é **prefixo** no nome das duas imagens,
conforme exigido.

---

## 3. Os dois ACIs em execução

```bash
az container list --output table
```

**No Portal:** abra cada ACI e mostre estado `Running` e o FQDN.

**Narração:** são **dois container groups distintos**, não um multi-container.
Por isso a aplicação alcança o banco pelo FQDN público, e não por localhost.

---

## 4. Storage Account — persistência do banco

**No Portal:** Storage Account → File shares → `mysql-dimdim-volume` → Browse.

Mostre os arquivos que o MySQL gravou: `ibdata1`, a pasta `mysql/` e a pasta
`db_dimdim/` com os `.ibd` das tabelas.

**Narração:** o share está montado em `/var/lib/mysql` dentro do ACI do banco;
é isso que faz os dados sobreviverem a um restart do container.

---

## 5. Prova de que o container da aplicação não roda como root

```bash
az container exec --resource-group rg-dimdim-rm561940 \
                  --name rm561940-aci-app \
                  --exec-command "id"
```

Saída esperada:

```
uid=10001(appuser) gid=999(appuser) groups=999(appuser)
```

**Narração:** `uid=10001`, não `uid=0` — o container roda sem privilégio
administrativo, como o enunciado exige.

---

## 6. Abrindo o banco — o SELECT inicial

> **Este é o ponto mais importante do vídeo.** A evidência que o enunciado
> cobra é o SELECT **dentro do banco**, não a resposta da API. A penalidade
> por evidência fraca é de −30 pontos.

As consultas de todas as etapas estão prontas em
[`docs/EVIDENCIAS_VIDEO.sql`](EVIDENCIAS_VIDEO.sql) — abra esse arquivo no
Workbench e execute uma por vez com `Ctrl+Enter`.

### 6.1 Prova de que o banco está dentro do ACI

Antes de ir para o Workbench, mostre uma vez que o banco roda no container
na Azure:

```bash
az container exec --resource-group rg-dimdim-rm561940 \
                  --name rm561940-aci-db \
                  --exec-command "/bin/bash"
```

Dentro do container:

```bash
mysql -uuser_dimdim -p
```

> Digite a senha quando solicitado — **não** a passe na linha de comando,
> ou ela fica visível na tela. Recupere-a antes de gravar com:
> `az keyvault secret show --vault-name kv-dimdim-rm561940 --name mysql-app-password --query value -o tsv`

```sql
USE db_dimdim;
SHOW TABLES;
```

Saia com `exit` duas vezes.

### 6.2 Workbench — de onde saem as evidências

Conexão já configurada:

| Campo | Valor |
|---|---|
| Hostname | `rm561940-db-dimdim.brazilsouth.azurecontainer.io` |
| Port | `3306` |
| Username | `user_dimdim` |
| Schema | `db_dimdim` |

Rode a consulta de identificação do servidor:

```sql
SELECT @@hostname AS servidor, @@version AS versao_mysql,
       DATABASE() AS banco_atual, CURRENT_USER() AS usuario;
```

O `servidor` aparece como `SandboxHost-...` — é o nome que a Azure dá ao
container. Serve como prova de que o Workbench está conectado ao ACI, e não
a um MySQL local.

Em seguida, o estado inicial:

```sql
SHOW TABLES;
SELECT * FROM cliente;
SELECT * FROM transacao;
```

**Narração:** apresente o modelo — `cliente` 1:N `transacao` — e o estado
inicial dos dados. Deixe claro que este é o MySQL rodando no ACI, acessado
pelo FQDN público.

---

## 7. CRUD da tabela CLIENTE

> Regra de ouro: **cada operação é seguida do seu SELECT**. É a alternância
> operação → evidência que o professor precisa ver.
> O DELETE de cliente fica para o fim, por causa da chave estrangeira.

### 7.1 CREATE

```bash
curl -i -X POST http://$APP_FQDN:8080/api/clientes \
  -H "Content-Type: application/json" \
  -d '{"nome":"Joana Prado","cpf":"32132132100","email":"joana.prado@dimdim.com"}'
```

Mostre o **201 Created** e o cabeçalho `Location`.

**No banco:**

```sql
SELECT * FROM cliente WHERE cpf = '32132132100';
```

> Anote o `id_cliente` retornado — ele é usado nos próximos passos.
> O roteiro assume **id 3**; ajuste conforme o seu.

### 7.2 READ

```bash
curl -X GET http://$APP_FQDN:8080/api/clientes/3
curl -X GET http://$APP_FQDN:8080/api/clientes
```

**No banco:**

```sql
SELECT * FROM cliente;
```

### 7.3 UPDATE

```bash
curl -i -X PUT http://$APP_FQDN:8080/api/clientes/3 \
  -H "Content-Type: application/json" \
  -d '{"nome":"Joana Prado Martins","cpf":"32132132100","email":"joana.martins@dimdim.com"}'
```

**No banco — a evidência da alteração:**

```sql
SELECT id_cliente, nome, email FROM cliente WHERE id_cliente = 3;
```

**Narração:** o nome e o e-mail mudaram no banco, não apenas na resposta da API.

---

## 8. CRUD da tabela TRANSACAO

### 8.1 CREATE

```bash
curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{"idCliente":3,"descricao":"Transferencia recebida","valor":890.25,"tipo":"CREDITO"}'
```

**No banco:**

```sql
SELECT * FROM transacao WHERE id_cliente = 3;
```

> Anote o `id_transacao`. O roteiro assume **id 3**.

### 8.2 READ

```bash
curl -X GET http://$APP_FQDN:8080/api/transacoes/3
curl -X GET http://$APP_FQDN:8080/api/transacoes
```

**No banco:**

```sql
SELECT * FROM transacao;
```

### 8.3 UPDATE

```bash
curl -i -X PUT http://$APP_FQDN:8080/api/transacoes/3 \
  -H "Content-Type: application/json" \
  -d '{"idCliente":3,"descricao":"Transferencia recebida - CORRIGIDA","valor":1120.75,"tipo":"CREDITO"}'
```

**No banco:**

```sql
SELECT id_transacao, descricao, valor FROM transacao WHERE id_transacao = 3;
```

### 8.4 DELETE

```bash
curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/3
```

Mostre o **204 No Content**.

**No banco — a evidência da exclusão:**

```sql
SELECT * FROM transacao WHERE id_transacao = 3;
-- Empty set
```

---

## 9. Integridade referencial — o 409

> Momento que vale a pena explicar bem: não é falha, é a FK funcionando.

Crie uma transação nova para o cliente 3 e **tente apagar o cliente**:

```bash
curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{"idCliente":3,"descricao":"Compra parcelada","valor":300.00,"tipo":"DEBITO"}'

curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3
```

Resposta esperada — **409 Conflict**:

```json
{
  "status": 409,
  "erro": "Conflito de integridade",
  "mensagem": "Nao e possivel excluir o cliente: existem transacoes vinculadas a ele. Exclua primeiro as transacoes do cliente."
}
```

**No banco — o cliente continua lá:**

```sql
SELECT * FROM cliente WHERE id_cliente = 3;
```

**Narração:** a FK é `ON DELETE RESTRICT`. O banco recusa a exclusão, a
aplicação traduz isso em **409 com mensagem legível** — não em erro 500 com
stack trace. É integridade referencial funcionando.

---

## 10. DELETE do cliente, na ordem correta

Apague primeiro a transação, depois o cliente:

```bash
# descubra o id da transação criada no passo 9
curl -X GET http://$APP_FQDN:8080/api/transacoes

curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/4
curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3
```

Ambos devem retornar **204**.

**No banco — a evidência final:**

```sql
SELECT * FROM cliente WHERE id_cliente = 3;
-- Empty set
SELECT * FROM cliente;
SELECT * FROM transacao;
```

---

## 11. Teste de persistência — restart do ACI do banco

Insira um registro que servirá de prova:

```bash
curl -i -X POST http://$APP_FQDN:8080/api/clientes \
  -H "Content-Type: application/json" \
  -d '{"nome":"Teste Persistencia","cpf":"45645645600","email":"persistencia@dimdim.com"}'
```

**No banco, antes do restart:**

```sql
SELECT * FROM cliente WHERE cpf = '45645645600';
```

Saia do container (`exit`, `exit`) e reinicie o ACI:

```bash
az container restart --resource-group rg-dimdim-rm561940 --name rm561940-aci-db
az container show -g rg-dimdim-rm561940 -n rm561940-aci-db --query instanceView.state -o tsv
```

> Leva 1 a 2 minutos. Aguarde voltar a `Running` — pode cortar a espera na
> edição.

Entre de novo e consulte:

```bash
az container exec --resource-group rg-dimdim-rm561940 \
                  --name rm561940-aci-db \
                  --exec-command "/bin/bash"
mysql -uuser_dimdim -p
```

```sql
USE db_dimdim;
SELECT * FROM cliente WHERE cpf = '45645645600';
```

**Narração:** o container foi reiniciado e o registro continua lá — porque o
`/var/lib/mysql` está no Azure File Share, não no disco efêmero do container.
É a persistência em Conta de Armazenamento que o enunciado pede.

---

## 12. Fechamento

Volte ao Portal com os recursos à vista e encerre mencionando:

- Banco e aplicação **containerizados**, com Dockerfile próprio para cada um
- Imagens no **ACR** com o RM do representante como prefixo
- **Dois ACIs** separados, também com o prefixo
- Persistência em **Conta de Armazenamento** via Azure Files
- Segredos no **Key Vault**, nunca no código
- Container da aplicação **sem privilégio de root**
- Toda a infraestrutura criada por **Azure CLI**, versionada no GitHub
- Link do repositório

---

## Checklist final

- [ ] Vídeo começa pelos recursos na Azure
- [ ] ACR com as duas imagens prefixadas visíveis
- [ ] Os dois ACIs em `Running`
- [ ] File Share com os arquivos do MySQL
- [ ] `id` provando container não-root
- [ ] Workbench conectado ao FQDN do ACI (`@@hostname` = SandboxHost-...)
- [ ] **CREATE, READ, UPDATE e DELETE de `cliente`, cada um com seu SELECT**
- [ ] **CREATE, READ, UPDATE e DELETE de `transacao`, cada um com seu SELECT**
- [ ] 409 da integridade referencial demonstrado
- [ ] Persistência comprovada com restart
- [ ] Nenhuma chamada a localhost — tudo pelo FQDN público
- [ ] Nenhuma senha visível na tela
- [ ] Áudio claro, narração explicando cada passo
- [ ] 1080p

---

## Se algo der errado durante a gravação

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `az container exec` não abre | shell inexistente | use `/bin/bash`; no ACI do banco também funciona `/bin/sh` |
| API responde 500 | banco reiniciando | aguarde ~1 min; a política de restart é `Always` |
| Conexão recusada no curl | ACI ainda subindo | `az container logs -g $RESOURCE_GROUP -n $ACI_APP` |
| `Public Key Retrieval is not allowed` | falta parâmetro na URL JDBC | já tratado no `07_aci-app.sh` |
| Tabelas não existem | share com dados antigos; `init.sql` ignorado | pare a gravação e investigue antes de continuar |
