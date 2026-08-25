package br.com.fiap.dimdim;

import br.com.fiap.dimdim.repository.RepositorioBaseImpl;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication
// [ADICIONAL] @EnableJpaRepositories so e necessario para registrar o
// RepositorioBaseImpl como classe base dos repositorios. Sem o refresh()
// desta classe, o POST devolveria data_cadastro/data_transacao nulos.
@EnableJpaRepositories(
        basePackages = "br.com.fiap.dimdim.repository",
        repositoryBaseClass = RepositorioBaseImpl.class
)
public class DimdimApplication {

    public static void main(String[] args) {
        SpringApplication.run(DimdimApplication.class, args);
    }
}
