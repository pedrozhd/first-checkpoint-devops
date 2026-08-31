# Roteiro de gravação — Projeto DimDim

**Grupo lupeol** · RM561940 Pedro França · RM563558 Olavo Neves · RM564495 Luiz Gonçalves
FIAP — DevOps Tools & Cloud Computing — 1º Checkpoint

> Este arquivo cuida da **narrativa**: o que mostrar, em que ordem, o que
> dizer. Todas as consultas SQL e os comandos `curl` da demonstração estão
> em [`EVIDENCIAS_VIDEO.sql`](EVIDENCIAS_VIDEO.sql), que é a fonte única —
> deixe-o aberto no Workbench durante a gravação.

---

## Antes de apertar o REC

- [ ] Os dois ACIs em `Running` (`az container list -o table`)
- [ ] Portal Azure aberto no grupo `rg-dimdim-rm561940`
- [ ] Terminal pronto para `az`/`curl`
- [ ] MySQL Workbench **já conectado** (conecte antes de gravar, para a senha não aparecer)
- [ ] [`EVIDENCIAS_VIDEO.sql`](EVIDENCIAS_VIDEO.sql) aberto numa aba do Workbench
- [ ] Fonte do terminal **aumentada** — texto pequeno não se lê em vídeo
- [ ] Gravação em **1080p** (mínimo exigido: 720p), com áudio claro
- [ ] Variáveis carregadas no terminal, **a partir da raiz do projeto**:

```bash
cd "/c/Users/StartSe/Workspace 2/fiap/cp1_devops"
source scripts/00_variables.sh
APP_FQDN=$(az container show -g $RESOURCE_GROUP -n $ACI_APP --query ipAddress.fqdn -o tsv)
echo $APP_FQDN
```

> O `source` usa caminho relativo. Fora da raiz do projeto ele falha com
> `No such file or directory`, as variáveis ficam vazias e o `az` responde
> `argument --resource-group/-g: expected one argument`. Confira com `pwd`.
>
> Deve imprimir: `rm561940-app-dimdim.brazilsouth.azurecontainer.io`

**Atalho mais seguro para a gravação.** Os comandos do vídeo usam os nomes
dos recursos por extenso, então `APP_FQDN` é a única variável realmente
necessária. Definir o valor direto dispensa `cd`, `source` e a consulta ao
Azure — funciona de qualquer diretório:

```bash
APP_FQDN=rm561940-app-dimdim.brazilsouth.azurecontainer.io
echo $APP_FQDN
```

> **Confirme que o `echo` imprimiu o endereço antes de seguir.** Com a
> variável vazia, a URL vira `http://:8080/...` e o curl responde
> `URL rejected: No host part in the URL`.

- [ ] **No Git Bash do Windows**, exportar antes de qualquer `az container exec`:

```bash
export MSYS_NO_PATHCONV=1
```

> Sem isso, o Git Bash converte `"/bin/bash"` em `C:/Program Files/Git/bin/bash`
> antes de enviar o comando à Azure, e o `exec` falha com
> `stat C:/Program: no such file or directory`. Como alternativa, dobre a
> primeira barra: `--exec-command "//bin/bash"`.

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

# PARTE 1 — Os recursos na Azure

## 1. Abertura

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

## 6. O banco está dentro do ACI

```bash
az container exec --resource-group rg-dimdim-rm561940 \
                  --name rm561940-aci-db \
                  --exec-command "/bin/bash"
```

Dentro do container:

```bash
mysql -uuser_dimdim -p
```

> Digite a senha quando solicitado — **não** a passe na linha de comando, ou
> ela fica visível na tela. Recupere-a antes de gravar com:
> `az keyvault secret show --vault-name kv-dimdim-rm561940 --name mysql-app-password --query value -o tsv`

```sql
USE db_dimdim;
SHOW TABLES;
```

Saia com `exit` duas vezes.

> **Se rodar `id` neste container**, ele responde `uid=0(root)` — e isso está
> correto. O MySQL precisa de root para gerenciar o próprio datadir. A
> exigência de container sem privilégio administrativo vale para o container
> da **aplicação** (etapa 5), que roda como `appuser`.

---

# PARTE 2 — As evidências do CRUD

> **A partir daqui, tudo sai do [`EVIDENCIAS_VIDEO.sql`](EVIDENCIAS_VIDEO.sql).**
>
> O arquivo está dividido nas mesmas etapas deste roteiro. Cada bloco traz o
> `curl` a executar no terminal em comentário, seguido do SELECT que comprova
> a alteração. Execute uma consulta por vez, com `Ctrl+Enter`.
>
> **Não há GET na demonstração.** A leitura que vale como evidência é o
> SELECT no banco, não a resposta da API.
>
> Esta é a parte mais importante do vídeo: a penalidade por evidência fraca
> de CRUD é de **−30 pontos**.

## 7. Estado inicial — a foto antes de tudo

No Workbench, execute o bloco **ETAPA 6.2** do arquivo `.sql`:

- identificação do servidor (`@@hostname` → `SandboxHost-...`)
- `SHOW TABLES`
- `DESCRIBE` das duas tabelas
- `SELECT *` em `cliente` e `transacao`

**Narração:** o `servidor` aparece como `SandboxHost-...`, o nome que a Azure
dá ao container — é a prova de que o Workbench está conectado ao ACI, e não a
um MySQL local. Apresente o modelo `cliente` 1:N `transacao` e o estado
inicial dos dados.

---

## 8. CRUD da tabela CLIENTE

Bloco **ETAPA 7** do arquivo `.sql`.

| Passo | Terminal | Workbench |
|---|---|---|
| CREATE | `curl POST /api/clientes` → **201** | `SELECT ... WHERE cpf = '32132132100'` |
| UPDATE | `curl PUT /api/clientes/3` → **200** | `SELECT id_cliente, nome, email ...` |

> Anote o `id_cliente` devolvido no POST. O arquivo assume **id 3** — ajuste
> se o seu for diferente.

**Narração:** no CREATE, mostre o `201 Created` e o cabeçalho `Location`. No
UPDATE, deixe claro que nome e e-mail mudaram **no banco**, não apenas na
resposta da API.

O DELETE do cliente fica para a etapa 10, por causa da chave estrangeira —
vale explicar isso já aqui.

---

## 9. CRUD da tabela TRANSACAO

Bloco **ETAPA 8** do arquivo `.sql`.

| Passo | Terminal | Workbench |
|---|---|---|
| CREATE | `curl POST /api/transacoes` → **201** | `SELECT ... WHERE id_cliente = 3` + JOIN 1:N |
| UPDATE | `curl PUT /api/transacoes/3` → **200** | `SELECT id_transacao, descricao, valor ...` |
| DELETE | `curl DELETE /api/transacoes/3` → **204** | `SELECT ... WHERE id_transacao = 3` (vazio) |

**Narração:** o JOIN mostra o relacionamento 1:N funcionando. No DELETE, a
consulta voltar vazia é a evidência — reforce com a contagem.

---

## 10. Integridade referencial — o 409

Bloco **ETAPA 9** do arquivo `.sql`.

1. `curl POST /api/transacoes` — recria o vínculo com o cliente 3
2. No Workbench: contagem de transações do cliente e a consulta ao
   `information_schema`, que mostra `delete_rule = RESTRICT`
3. `curl DELETE /api/clientes/3` → **409 Conflict**
4. No Workbench: `SELECT * FROM cliente WHERE id_cliente = 3` — continua lá

**Narração:** a FK é `ON DELETE RESTRICT`. O banco recusa a exclusão, e a
aplicação traduz isso em **409 com mensagem legível** — não em 500 com stack
trace. Não é falha: é integridade referencial funcionando, e a consulta ao
catálogo prova a regra.

---

## 11. DELETE do cliente, na ordem correta

Bloco **ETAPA 10** do arquivo `.sql`.

1. `curl DELETE /api/transacoes/{id}` → **204**
2. `curl DELETE /api/clientes/3` → **204**
3. No Workbench: as duas consultas voltam vazias

**Narração:** apagando primeiro o lado N, o cliente sai sem violar a
restrição. Fecha o CRUD completo das duas tabelas.

---

## 12. Teste de persistência

Bloco **ETAPA 11** do arquivo `.sql`.

1. `curl POST /api/clientes` — cria o registro de prova
2. No Workbench: `SELECT` mostra o registro
3. No terminal: `az container restart -g rg-dimdim-rm561940 -n rm561940-aci-db`
4. Aguarde voltar a `Running` (1 a 2 min — pode cortar na edição)
5. No Workbench: **Query > Reconnect to Server**
6. `SELECT` de novo — o registro continua lá

**Narração:** o container foi reiniciado e o dado permanece, porque
`/var/lib/mysql` está no Azure File Share e não no disco efêmero do
container. É a persistência em Conta de Armazenamento que o enunciado pede.

---

## 13. Fechamento

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
- [ ] `id` provando container da aplicação não-root
- [ ] Workbench conectado ao FQDN do ACI (`@@hostname` = `SandboxHost-...`)
- [ ] **CREATE, UPDATE e DELETE de `cliente`, cada um com seu SELECT**
- [ ] **CREATE, UPDATE e DELETE de `transacao`, cada um com seu SELECT**
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
| `URL rejected: No host part in the URL` | `$APP_FQDN` vazio | redefina a variável e confira com `echo $APP_FQDN` |
| `scripts/00_variables.sh: No such file or directory` | terminal fora da raiz do projeto | `cd` para a raiz e repita o `source`; confira com `pwd` |
| `argument --resource-group/-g: expected one argument` | variáveis vazias — o `source` não rodou | mesma causa acima |
| `stat C:/Program: no such file or directory` | Git Bash converteu o caminho | `export MSYS_NO_PATHCONV=1` ou `--exec-command "//bin/bash"` |
| `az container exec` não abre | shell inexistente | use `/bin/bash`; no ACI do banco também funciona `/bin/sh` |
| API responde 500 | banco reiniciando | aguarde ~1 min; a política de restart é `Always` |
| Conexão recusada no curl | ACI ainda subindo | `az container logs -g $RESOURCE_GROUP -n $ACI_APP` |
| Workbench perde a conexão | restart do ACI | Query > Reconnect to Server |
| `Public Key Retrieval is not allowed` | falta parâmetro na URL JDBC | já tratado no `07_aci-app.sh` |
| Tabelas não existem | share com dados antigos; `init.sql` ignorado | pare a gravação e investigue antes de continuar |
