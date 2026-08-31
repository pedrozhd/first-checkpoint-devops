-- =====================================================================
-- Projeto DimDim - Evidencias do CRUD para a gravacao do video
-- Grupo lupeol - RM561940 / RM563558 / RM564495
--
-- ESTE ARQUIVO E A FONTE UNICA DAS CONSULTAS.
-- O docs/ROTEIRO_VIDEO.md cuida da narrativa e do que mostrar no Portal;
-- todo o SQL e todo o curl da demonstracao estao aqui.
--
-- Executar no MySQL Workbench conectado ao ACI do banco:
--
--   Hostname : rm561940-db-dimdim.brazilsouth.azurecontainer.io
--   Port     : 3306
--   Username : user_dimdim
--   Schema   : db_dimdim
--
-- COMO USAR NA GRAVACAO
--   1. Deixe este arquivo aberto numa aba do Workbench e o terminal ao lado.
--   2. Execute UMA consulta por vez: cursor sobre ela e Ctrl+Enter.
--      Nao use "Execute All" - a demonstracao precisa ser passo a passo.
--   3. Onde houver um bloco "NO TERMINAL", rode o curl indicado ANTES de
--      executar o SELECT que vem logo abaixo.
--
-- A ordem e sempre a mesma: a operacao altera o dado pela API, o SELECT
-- prova a alteracao no banco. Nao ha GET na demonstracao - a leitura que
-- vale como evidencia e o SELECT, nao a resposta da API.
-- =====================================================================

USE db_dimdim;


-- =====================================================================
-- ETAPA 6.2 - ESTADO INICIAL
-- Comeca aqui a demonstracao das evidencias.
-- =====================================================================

-- Confirma que a conexao e com o container na Azure, e nao com um MySQL
-- local: o servidor aparece como "SandboxHost-...".
SELECT @@hostname     AS servidor,
       @@version      AS versao_mysql,
       DATABASE()     AS banco_atual,
       CURRENT_USER() AS usuario;

-- As duas tabelas do modelo
SHOW TABLES;

-- Estrutura das tabelas - reforca que o DDL entregue e o que esta no banco
DESCRIBE cliente;
DESCRIBE transacao;

-- A foto do banco ANTES de qualquer alteracao
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- ETAPA 7 - TABELA CLIENTE
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7.1 CREATE
--
-- NO TERMINAL:
--   curl -i -X POST http://$APP_FQDN:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado","cpf":"32132132100","email":"joana.prado@dimdim.com"}'
--
--   Mostre o 201 Created e o cabecalho Location.
-- ---------------------------------------------------------------------

-- Evidencia do INSERT
SELECT * FROM cliente WHERE cpf = '32132132100';

-- >>> Anote o id_cliente retornado. As consultas seguintes assumem id = 3.


-- ---------------------------------------------------------------------
-- 7.2 UPDATE
--
-- NO TERMINAL:
--   curl -i -X PUT http://$APP_FQDN:8080/api/clientes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado Martins","cpf":"32132132100","email":"joana.martins@dimdim.com"}'
--
--   Mostre o 200 OK.
-- ---------------------------------------------------------------------

-- Evidencia do UPDATE - nome e email alterados no banco
SELECT id_cliente, nome, email, data_cadastro
  FROM cliente
 WHERE id_cliente = 3;

-- O DELETE do cliente fica para a etapa 10, por causa da chave estrangeira.


-- =====================================================================
-- ETAPA 8 - TABELA TRANSACAO
-- =====================================================================

-- ---------------------------------------------------------------------
-- 8.1 CREATE
--
-- NO TERMINAL:
--   curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida","valor":890.25,"tipo":"CREDITO"}'
--
--   Mostre o 201 Created.
-- ---------------------------------------------------------------------

-- Evidencia do INSERT
SELECT * FROM transacao WHERE id_cliente = 3;

-- >>> Anote o id_transacao. As consultas seguintes assumem id = 3.

-- O relacionamento 1:N funcionando
SELECT c.id_cliente,
       c.nome,
       t.id_transacao,
       t.descricao,
       t.valor,
       t.tipo
  FROM cliente c
  INNER JOIN transacao t ON t.id_cliente = c.id_cliente
 ORDER BY c.id_cliente, t.id_transacao;


-- ---------------------------------------------------------------------
-- 8.2 UPDATE
--
-- NO TERMINAL:
--   curl -i -X PUT http://$APP_FQDN:8080/api/transacoes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida - CORRIGIDA","valor":1120.75,"tipo":"CREDITO"}'
-- ---------------------------------------------------------------------

-- Evidencia do UPDATE - descricao e valor alterados
SELECT id_transacao, id_cliente, descricao, valor, tipo
  FROM transacao
 WHERE id_transacao = 3;


-- ---------------------------------------------------------------------
-- 8.3 DELETE
--
-- NO TERMINAL:
--   curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/3
--
--   Mostre o 204 No Content.
-- ---------------------------------------------------------------------

-- Evidencia do DELETE - a consulta volta vazia
SELECT * FROM transacao WHERE id_transacao = 3;

-- Confirmacao pela contagem
SELECT COUNT(*) AS transacoes_restantes FROM transacao;


-- =====================================================================
-- ETAPA 9 - INTEGRIDADE REFERENCIAL (o 409)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Recria o vinculo, para tentar apagar um cliente que tem transacao.
--
-- NO TERMINAL:
--   curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Compra parcelada","valor":300.00,"tipo":"DEBITO"}'
-- ---------------------------------------------------------------------

-- Confirma que o cliente 3 tem transacao vinculada
SELECT c.id_cliente,
       c.nome,
       COUNT(t.id_transacao) AS qtd_transacoes
  FROM cliente c
  LEFT JOIN transacao t ON t.id_cliente = c.id_cliente
 WHERE c.id_cliente = 3
 GROUP BY c.id_cliente, c.nome;

-- A definicao da chave estrangeira, direto do catalogo do MySQL:
-- delete_rule = RESTRICT e a razao tecnica do 409 que vem a seguir.
SELECT constraint_name,
       table_name,
       referenced_table_name,
       delete_rule
  FROM information_schema.referential_constraints
 WHERE constraint_schema = 'db_dimdim';

-- ---------------------------------------------------------------------
-- NO TERMINAL - a tentativa que deve FALHAR:
--   curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3
--
--   A API responde 409 Conflict com mensagem legivel, nao 500.
-- ---------------------------------------------------------------------

-- Evidencia de que o cliente NAO foi apagado
SELECT * FROM cliente WHERE id_cliente = 3;

-- Opcional - a mesma restricao demonstrada direto no banco.
-- Este DELETE falha com ERROR 1451, e a falha e a evidencia:
-- DELETE FROM cliente WHERE id_cliente = 3;


-- =====================================================================
-- ETAPA 10 - DELETE DO CLIENTE, NA ORDEM CORRETA
-- =====================================================================

-- ---------------------------------------------------------------------
-- NO TERMINAL, nesta ordem - primeiro a transacao, depois o cliente:
--   curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/{id_da_transacao}
--   curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3
--
--   Ambos devem retornar 204 No Content.
-- ---------------------------------------------------------------------

-- Evidencia de que ambos sairam do banco
SELECT * FROM cliente   WHERE id_cliente = 3;
SELECT * FROM transacao WHERE id_cliente = 3;

-- Estado geral apos as exclusoes
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- ETAPA 11 - TESTE DE PERSISTENCIA
-- =====================================================================

-- ---------------------------------------------------------------------
-- NO TERMINAL:
--   curl -i -X POST http://$APP_FQDN:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Teste Persistencia","cpf":"45645645600","email":"persistencia@dimdim.com"}'
-- ---------------------------------------------------------------------

-- ANTES do restart
SELECT id_cliente, nome, cpf, data_cadastro
  FROM cliente
 WHERE cpf = '45645645600';

-- ---------------------------------------------------------------------
-- NO TERMINAL - reinicia o container do banco:
--   az container restart --resource-group rg-dimdim-rm561940 \
--                        --name rm561940-aci-db
--
--   Leva 1 a 2 minutos. Aguarde voltar a Running.
--   O Workbench perde a conexao: reconecte em Query > Reconnect to Server.
-- ---------------------------------------------------------------------

-- DEPOIS do restart - o registro continua la, porque /var/lib/mysql esta
-- no Azure File Share e nao no disco efemero do container.
SELECT id_cliente, nome, cpf, data_cadastro
  FROM cliente
 WHERE cpf = '45645645600';

-- Visao final das duas tabelas
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- CONSULTAS DE APOIO (se precisar durante a gravacao)
-- =====================================================================

-- Contagem geral
SELECT (SELECT COUNT(*) FROM cliente)   AS total_clientes,
       (SELECT COUNT(*) FROM transacao) AS total_transacoes;

-- Ultimos registros inseridos, se perder a referencia de algum id
SELECT * FROM cliente   ORDER BY id_cliente   DESC LIMIT 5;
SELECT * FROM transacao ORDER BY id_transacao DESC LIMIT 5;
