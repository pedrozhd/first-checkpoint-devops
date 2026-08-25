package br.com.fiap.dimdim.repository;

import jakarta.persistence.EntityManager;
import org.springframework.data.jpa.repository.support.JpaEntityInformation;
import org.springframework.data.jpa.repository.support.SimpleJpaRepository;
import org.springframework.transaction.annotation.Transactional;

/**
 * [ADICIONAL - classe fora da lista de camadas da Fase 2.1 do roteiro]
 *
 * Implementacao de RepositorioBase. Registrada em DimdimApplication via
 * repositoryBaseClass. Ver a justificativa em {@link RepositorioBase}.
 */
public class RepositorioBaseImpl<T, ID> extends SimpleJpaRepository<T, ID>
        implements RepositorioBase<T, ID> {

    private final EntityManager entityManager;

    public RepositorioBaseImpl(JpaEntityInformation<T, ?> entityInformation,
                               EntityManager entityManager) {
        super(entityInformation, entityManager);
        this.entityManager = entityManager;
    }

    @Override
    @Transactional
    public void refresh(T entidade) {
        entityManager.refresh(entidade);
    }
}
