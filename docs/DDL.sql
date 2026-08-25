-- =====================================================================
-- Projeto DimDim - Checkpoint 1: Containers em Nuvem (ACR/ACI)
-- FIAP - DevOps Tools & Cloud Computing
--
-- Grupo lupeol
--   RM561940 - Pedro Franca   (representante)
--   RM563558 - Olavo Neves
--   RM564495 - Luiz Goncalves
--
-- SGBD: MySQL 8.0
-- Modelo: cliente 1:N transacao
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tabela: cliente
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

-- ---------------------------------------------------------------------
-- Tabela: transacao
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Indice da FK
--
-- O InnoDB cria um indice automatico para a FK, mas ele e declarado
-- explicitamente para deixar a intencao registrada no DDL entregue.
-- ---------------------------------------------------------------------
CREATE INDEX ix_transacao_id_cliente ON transacao (id_cliente);
