package br.com.fiap.dimdim.controller;

import br.com.fiap.dimdim.dto.ClienteRequest;
import br.com.fiap.dimdim.dto.ClienteResponse;
import br.com.fiap.dimdim.entity.Cliente;
import br.com.fiap.dimdim.exception.RecursoNaoEncontradoException;
import br.com.fiap.dimdim.repository.ClienteRepository;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/clientes")
public class ClienteController {

    private final ClienteRepository repository;

    public ClienteController(ClienteRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public ResponseEntity<List<ClienteResponse>> listar() {
        List<ClienteResponse> clientes = repository.findAll()
                .stream()
                .map(ClienteResponse::de)
                .toList();
        return ResponseEntity.ok(clientes);
    }

    @GetMapping("/{id}")
    public ResponseEntity<ClienteResponse> buscarPorId(@PathVariable Long id) {
        Cliente cliente = buscarOuFalhar(id);
        return ResponseEntity.ok(ClienteResponse.de(cliente));
    }

    @PostMapping
    @Transactional
    public ResponseEntity<ClienteResponse> criar(@RequestBody @Valid ClienteRequest request,
                                                 UriComponentsBuilder uriBuilder) {
        Cliente cliente = new Cliente();
        cliente.setNome(request.nome());
        cliente.setCpf(request.cpf());
        cliente.setEmail(request.email());

        // saveAndFlush: forca o INSERT agora, para que uma violacao de CPF
        // duplicado vire 409 dentro deste handler e nao no commit da transacao.
        Cliente salvo = repository.saveAndFlush(cliente);

        // O DDL preenche data_cadastro via DEFAULT CURRENT_TIMESTAMP, entao a
        // entidade em memoria precisa ser recarregada para devolver o valor.
        repository.refresh(salvo);

        URI location = uriBuilder.path("/api/clientes/{id}")
                .buildAndExpand(salvo.getIdCliente())
                .toUri();

        return ResponseEntity.created(location).body(ClienteResponse.de(salvo));
    }

    @PutMapping("/{id}")
    @Transactional
    public ResponseEntity<ClienteResponse> atualizar(@PathVariable Long id,
                                                     @RequestBody @Valid ClienteRequest request) {
        Cliente cliente = buscarOuFalhar(id);
        cliente.setNome(request.nome());
        cliente.setCpf(request.cpf());
        cliente.setEmail(request.email());

        Cliente atualizado = repository.saveAndFlush(cliente);
        return ResponseEntity.ok(ClienteResponse.de(atualizado));
    }

    /**
     * A FK transacao -> cliente e ON DELETE RESTRICT. Apagar um cliente que
     * possua transacoes falha no banco e o handler global converte em 409.
     */
    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<Void> excluir(@PathVariable Long id) {
        Cliente cliente = buscarOuFalhar(id);
        repository.delete(cliente);
        repository.flush();
        return ResponseEntity.noContent().build();
    }

    private Cliente buscarOuFalhar(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new RecursoNaoEncontradoException(
                        "Cliente nao encontrado para o id " + id));
    }
}
