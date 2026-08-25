-- =====================================================================
-- Projeto DimDim - script de inicializacao do MySQL
-- Grupo lupeol - RM561940 / RM563558 / RM564495
--
-- Executado automaticamente pelo entrypoint do MySQL a partir de
-- /docker-entrypoint-initdb.d/ APENAS quando o datadir esta vazio.
-- Se o Azure Files ja contiver dados de um teste anterior, este script
-- e silenciosamente ignorado.
-- =====================================================================

USE db_dimdim;

-- ---------------------------------------------------------------------
-- DDL (identico a docs/DDL.sql)
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
    id_cliente    BIGINT       NOT NULL AUTO_INCREMENT,
    nome          VARCHAR(120) NOT NULL,
    cpf           VARCHAR(11)  NOT NULL,
    email         VARCHAR(150) NOT NULL,
    data_cadastro DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uk_cliente_cpf UNIQUE (cpf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE transacao (
    id_transacao   BIGINT        NOT NULL AUTO_INCREMENT,
    id_cliente     BIGINT        NOT NULL,
    descricao      VARCHAR(200)  NOT NULL,
    valor          DECIMAL(15,2) NOT NULL,
    tipo           VARCHAR(10)   NOT NULL,
    data_transacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_transacao PRIMARY KEY (id_transacao),
    CONSTRAINT ck_transacao_tipo CHECK (tipo IN ('CREDITO','DEBITO')),
    CONSTRAINT fk_transacao_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX ix_transacao_id_cliente ON transacao (id_cliente);

-- ---------------------------------------------------------------------
-- Seed minimo - para o SELECT inicial do video nao sair vazio
-- ---------------------------------------------------------------------
INSERT INTO cliente (nome, cpf, email) VALUES
    ('Ana Souza',   '11122233344', 'ana.souza@exemplo.com'),
    ('Bruno Lima',  '55566677788', 'bruno.lima@exemplo.com');

INSERT INTO transacao (id_cliente, descricao, valor, tipo) VALUES
    (1, 'Deposito inicial',        1500.00, 'CREDITO'),
    (2, 'Compra no supermercado',   250.75, 'DEBITO');
