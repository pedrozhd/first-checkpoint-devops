-- =====================================================================
-- Projeto DimDim - Evidencias do CRUD para a gravacao do video
-- Grupo lupeol - RM561940 / RM563558 / RM564495
--
-- Workbench conectado ao ACI do banco:
--   Hostname : rm561940-db-dimdim.brazilsouth.azurecontainer.io
--   Port     : 3306   Username : user_dimdim   Schema : db_dimdim
--
-- COMO USAR
--   Terminal ao lado do Workbench. Onde houver "NO TERMINAL", rode o curl
--   ANTES do SELECT que vem abaixo. Uma consulta por vez: Ctrl+Enter.
--
--   Antes de comecar, no terminal:
--     APP_FQDN=rm561940-app-dimdim.brazilsouth.azurecontainer.io
--
-- A ordem e sempre a mesma: a API altera o dado, o SELECT prova.
-- =====================================================================

USE db_dimdim;


-- =====================================================================
-- ESTADO INICIAL
-- =====================================================================

-- Confirma que a conexao e com o container na Azure: o servidor aparece
-- como "SandboxHost-...".
SELECT @@hostname AS servidor, DATABASE() AS banco_atual;

SHOW TABLES;

SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- CLIENTE
-- =====================================================================

-- --- CREATE ----------------------------------------------------------
-- NO TERMINAL (mostre o 201 e o cabecalho Location):
--   curl -i -X POST http://$APP_FQDN:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado","cpf":"32132132100","email":"joana.prado@dimdim.com"}'

SELECT * FROM cliente WHERE cpf = '32132132100';

-- >>> Anote o id_cliente. As consultas seguintes assumem id = 3.


-- --- UPDATE ----------------------------------------------------------
-- NO TERMINAL (200 OK):
--   curl -i -X PUT http://$APP_FQDN:8080/api/clientes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado Martins","cpf":"32132132100","email":"joana.martins@dimdim.com"}'

SELECT * FROM cliente WHERE id_cliente = 3;

-- O DELETE do cliente vem depois, por causa da chave estrangeira.


-- =====================================================================
-- TRANSACAO
-- =====================================================================

-- --- CREATE ----------------------------------------------------------
-- NO TERMINAL (201 Created):
--   curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida","valor":890.25,"tipo":"CREDITO"}'

SELECT * FROM transacao WHERE id_cliente = 3;

-- >>> Anote o id_transacao. As consultas seguintes assumem id = 3.


-- --- UPDATE ----------------------------------------------------------
-- NO TERMINAL (200 OK):
--   curl -i -X PUT http://$APP_FQDN:8080/api/transacoes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida - CORRIGIDA","valor":1120.75,"tipo":"CREDITO"}'

SELECT * FROM transacao WHERE id_transacao = 3;


-- --- DELETE ----------------------------------------------------------
-- NO TERMINAL (204 No Content):
--   curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/3

-- A consulta volta vazia: e essa a evidencia da exclusao.
SELECT * FROM transacao WHERE id_transacao = 3;


-- =====================================================================
-- INTEGRIDADE REFERENCIAL - o 409
-- =====================================================================

-- NO TERMINAL - recria o vinculo:
--   curl -i -X POST http://$APP_FQDN:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Compra parcelada","valor":300.00,"tipo":"DEBITO"}'

-- O cliente 3 tem transacao vinculada:
SELECT * FROM transacao WHERE id_cliente = 3;

-- NO TERMINAL - a tentativa que FALHA com 409 Conflict:
--   curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3

-- O cliente continua no banco - a FK e ON DELETE RESTRICT:
SELECT * FROM cliente WHERE id_cliente = 3;


-- =====================================================================
-- DELETE DO CLIENTE, NA ORDEM CORRETA
-- =====================================================================

-- NO TERMINAL, nesta ordem (204 nos dois):
--   curl -i -X DELETE http://$APP_FQDN:8080/api/transacoes/{id}
--   curl -i -X DELETE http://$APP_FQDN:8080/api/clientes/3

SELECT * FROM cliente   WHERE id_cliente = 3;
SELECT * FROM transacao WHERE id_cliente = 3;


-- =====================================================================
-- PERSISTENCIA
-- =====================================================================

-- NO TERMINAL:
--   curl -i -X POST http://$APP_FQDN:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Teste Persistencia","cpf":"45645645600","email":"persistencia@dimdim.com"}'

-- ANTES do restart:
SELECT * FROM cliente WHERE cpf = '45645645600';

-- NO TERMINAL - reinicia o container do banco (leva 1 a 2 minutos):
--   az container restart -g rg-dimdim-rm561940 -n rm561940-aci-db
--
--   O Workbench perde a conexao: Query > Reconnect to Server.

-- DEPOIS do restart - o registro continua la, porque /var/lib/mysql esta
-- no Azure File Share e nao no disco efemero do container:
SELECT * FROM cliente WHERE cpf = '45645645600';
