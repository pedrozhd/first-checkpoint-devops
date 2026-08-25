package br.com.fiap.dimdim.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.NoRepositoryBean;

/**
 * [ADICIONAL - classe fora da lista de camadas da Fase 2.1 do roteiro]
 *
 * Acrescenta refresh() ao contrato padrao do Spring Data.
 *
 * As colunas data_cadastro e data_transacao sao preenchidas pelo banco via
 * DEFAULT CURRENT_TIMESTAMP. Apos o INSERT a entidade em memoria ainda tem
 * esses campos nulos, entao e preciso reler a linha para devolve-los na
 * resposta HTTP.
 */
@NoRepositoryBean
public interface RepositorioBase<T, ID> extends JpaRepository<T, ID> {

    void refresh(T entidade);
}
