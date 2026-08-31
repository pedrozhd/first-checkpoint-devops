-- =====================================================================
-- Projeto DimDim - Consultas de evidencia para a gravacao do video
-- Grupo lupeol - RM561940 / RM563558 / RM564495
--
-- Executar no MySQL Workbench conectado ao ACI do banco:
--
--   Hostname : rm561940-db-dimdim.brazilsouth.azurecontainer.io
--   Port     : 3306
--   Username : user_dimdim
--   Schema   : db_dimdim
--
-- Cada bloco corresponde a uma etapa do docs/ROTEIRO_VIDEO.md. A ordem
-- importa: as operacoes sao feitas pela API (curl) e cada uma e seguida
-- pelo SELECT que comprova a alteracao no banco.
--
-- No Workbench, execute UMA consulta por vez com Ctrl+Enter, com o cursor
-- sobre ela. Nao use "Execute All" - a demonstracao precisa ser passo a passo.
-- =====================================================================

USE db_dimdim;


-- =====================================================================
-- ETAPA 6 - Estado inicial
-- =====================================================================

-- Confirma que as duas tabelas existem no banco em nuvem
SHOW TABLES;

-- Estrutura das tabelas (opcional, mas reforca a evidencia do DDL)
DESCRIBE cliente;
DESCRIBE transacao;

-- Dados iniciais, vindos do seed do init.sql
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- ETAPA 7 - CRUD da tabela CLIENTE
-- =====================================================================

-- 7.1 CREATE
-- Executar ANTES no terminal:
--   curl -i -X POST http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado","cpf":"32132132100","email":"joana.prado@dimdim.com"}'
--
-- Evidencia do INSERT:
SELECT * FROM cliente WHERE cpf = '32132132100';

-- Anote o id_cliente retornado. As consultas seguintes assumem id = 3.


-- 7.2 READ
-- Executar ANTES no terminal:
--   curl -X GET http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/clientes/3
--
-- Evidencia de que a API le o mesmo dado que esta no banco:
SELECT * FROM cliente WHERE id_cliente = 3;
SELECT * FROM cliente;


-- 7.3 UPDATE
-- Executar ANTES no terminal:
--   curl -i -X PUT http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/clientes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Joana Prado Martins","cpf":"32132132100","email":"joana.martins@dimdim.com"}'
--
-- Evidencia do UPDATE - nome e email alterados:
SELECT id_cliente, nome, email, data_cadastro
  FROM cliente
 WHERE id_cliente = 3;


-- =====================================================================
-- ETAPA 8 - CRUD da tabela TRANSACAO
-- =====================================================================

-- 8.1 CREATE
-- Executar ANTES no terminal:
--   curl -i -X POST http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida","valor":890.25,"tipo":"CREDITO"}'
--
-- Evidencia do INSERT:
SELECT * FROM transacao WHERE id_cliente = 3;

-- Anote o id_transacao. As consultas seguintes assumem id = 3.


-- 8.2 READ
-- Executar ANTES no terminal:
--   curl -X GET http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/transacoes/3
--
-- Evidencia:
SELECT * FROM transacao WHERE id_transacao = 3;
SELECT * FROM transacao;

-- Consulta com JOIN - mostra o relacionamento 1:N funcionando
SELECT c.id_cliente,
       c.nome,
       t.id_transacao,
       t.descricao,
       t.valor,
       t.tipo
  FROM cliente c
  INNER JOIN transacao t ON t.id_cliente = c.id_cliente
 ORDER BY c.id_cliente, t.id_transacao;


-- 8.3 UPDATE
-- Executar ANTES no terminal:
--   curl -i -X PUT http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/transacoes/3 \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Transferencia recebida - CORRIGIDA","valor":1120.75,"tipo":"CREDITO"}'
--
-- Evidencia do UPDATE - descricao e valor alterados:
SELECT id_transacao, id_cliente, descricao, valor, tipo
  FROM transacao
 WHERE id_transacao = 3;


-- 8.4 DELETE
-- Executar ANTES no terminal:
--   curl -i -X DELETE http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/transacoes/3
--
-- Evidencia do DELETE - a consulta volta vazia:
SELECT * FROM transacao WHERE id_transacao = 3;

-- Confirmacao pela contagem:
SELECT COUNT(*) AS transacoes_restantes FROM transacao;


-- =====================================================================
-- ETAPA 9 - Integridade referencial (o 409)
-- =====================================================================

-- Executar ANTES no terminal, para recriar o vinculo:
--   curl -i -X POST http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/transacoes \
--     -H "Content-Type: application/json" \
--     -d '{"idCliente":3,"descricao":"Compra parcelada","valor":300.00,"tipo":"DEBITO"}'
--
-- Confirma que o cliente 3 tem transacao vinculada:
SELECT c.id_cliente,
       c.nome,
       COUNT(t.id_transacao) AS qtd_transacoes
  FROM cliente c
  LEFT JOIN transacao t ON t.id_cliente = c.id_cliente
 WHERE c.id_cliente = 3
 GROUP BY c.id_cliente, c.nome;

-- Agora, no terminal, tentar apagar o cliente:
--   curl -i -X DELETE http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/clientes/3
--   -> a API responde 409 Conflict
--
-- Evidencia de que o cliente NAO foi apagado:
SELECT * FROM cliente WHERE id_cliente = 3;

-- Opcional - a mesma restricao demonstrada direto no banco.
-- Este DELETE FALHA com ERROR 1451, e a falha e a evidencia:
-- DELETE FROM cliente WHERE id_cliente = 3;

-- A definicao da chave estrangeira, mostrando o ON DELETE RESTRICT:
SELECT constraint_name,
       table_name,
       referenced_table_name,
       delete_rule
  FROM information_schema.referential_constraints
 WHERE constraint_schema = 'db_dimdim';


-- =====================================================================
-- ETAPA 10 - DELETE do cliente, na ordem correta
-- =====================================================================

-- Executar ANTES no terminal, nesta ordem:
--   curl -i -X DELETE http://.../api/transacoes/{id_da_transacao}
--   curl -i -X DELETE http://.../api/clientes/3
--
-- Evidencia de que ambos sairam do banco:
SELECT * FROM cliente   WHERE id_cliente   = 3;
SELECT * FROM transacao WHERE id_cliente   = 3;

-- Estado geral apos as exclusoes:
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- ETAPA 11 - Teste de persistencia
-- =====================================================================

-- Executar ANTES no terminal:
--   curl -i -X POST http://rm561940-app-dimdim.brazilsouth.azurecontainer.io:8080/api/clientes \
--     -H "Content-Type: application/json" \
--     -d '{"nome":"Teste Persistencia","cpf":"45645645600","email":"persistencia@dimdim.com"}'
--
-- ANTES do restart:
SELECT id_cliente, nome, cpf, data_cadastro
  FROM cliente
 WHERE cpf = '45645645600';

-- Agora reiniciar o container do banco, no terminal:
--   az container restart --resource-group rg-dimdim-rm561940 --name rm561940-aci-db
--
-- O Workbench perde a conexao. Aguarde o ACI voltar a Running e
-- reconecte (Query > Reconnect to Server).
--
-- DEPOIS do restart - o registro continua la, porque /var/lib/mysql
-- esta no Azure File Share e nao no disco efemero do container:
SELECT id_cliente, nome, cpf, data_cadastro
  FROM cliente
 WHERE cpf = '45645645600';

-- Visao final das duas tabelas:
SELECT * FROM cliente;
SELECT * FROM transacao;


-- =====================================================================
-- Consultas de apoio (se precisar durante a gravacao)
-- =====================================================================

-- Confirma em qual servidor o Workbench esta conectado.
-- Util para deixar claro que e o banco em nuvem, e nao um local:
SELECT @@hostname       AS servidor,
       @@version        AS versao_mysql,
       DATABASE()       AS banco_atual,
       CURRENT_USER()   AS usuario;

-- Contagem geral:
SELECT (SELECT COUNT(*) FROM cliente)   AS total_clientes,
       (SELECT COUNT(*) FROM transacao) AS total_transacoes;
