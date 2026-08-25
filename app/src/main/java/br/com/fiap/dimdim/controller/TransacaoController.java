package br.com.fiap.dimdim.controller;

import br.com.fiap.dimdim.dto.TransacaoRequest;
import br.com.fiap.dimdim.dto.TransacaoResponse;
import br.com.fiap.dimdim.entity.Cliente;
import br.com.fiap.dimdim.entity.Transacao;
import br.com.fiap.dimdim.exception.RecursoNaoEncontradoException;
import br.com.fiap.dimdim.repository.ClienteRepository;
import br.com.fiap.dimdim.repository.TransacaoRepository;
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
@RequestMapping("/api/transacoes")
public class TransacaoController {

    private final TransacaoRepository transacaoRepository;
    private final ClienteRepository clienteRepository;

    public TransacaoController(TransacaoRepository transacaoRepository,
                               ClienteRepository clienteRepository) {
        this.transacaoRepository = transacaoRepository;
        this.clienteRepository = clienteRepository;
    }

    // readOnly: mantem a sessao aberta durante a montagem do DTO, necessario
    // porque o relacionamento com cliente e LAZY e open-in-view esta desligado.
    @GetMapping
    @Transactional(readOnly = true)
    public ResponseEntity<List<TransacaoResponse>> listar() {
        List<TransacaoResponse> transacoes = transacaoRepository.findAll()
                .stream()
                .map(TransacaoResponse::de)
                .toList();
        return ResponseEntity.ok(transacoes);
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public ResponseEntity<TransacaoResponse> buscarPorId(@PathVariable Long id) {
        Transacao transacao = buscarOuFalhar(id);
        return ResponseEntity.ok(TransacaoResponse.de(transacao));
    }

    @PostMapping
    @Transactional
    public ResponseEntity<TransacaoResponse> criar(@RequestBody @Valid TransacaoRequest request,
                                                   UriComponentsBuilder uriBuilder) {
        Cliente cliente = buscarClienteOuFalhar(request.idCliente());

        Transacao transacao = new Transacao();
        transacao.setCliente(cliente);
        transacao.setDescricao(request.descricao());
        transacao.setValor(request.valor());
        transacao.setTipo(request.tipo());

        Transacao salva = transacaoRepository.saveAndFlush(transacao);
        transacaoRepository.refresh(salva);

        URI location = uriBuilder.path("/api/transacoes/{id}")
                .buildAndExpand(salva.getIdTransacao())
                .toUri();

        return ResponseEntity.created(location).body(TransacaoResponse.de(salva));
    }

    @PutMapping("/{id}")
    @Transactional
    public ResponseEntity<TransacaoResponse> atualizar(@PathVariable Long id,
                                                       @RequestBody @Valid TransacaoRequest request) {
        Transacao transacao = buscarOuFalhar(id);
        Cliente cliente = buscarClienteOuFalhar(request.idCliente());

        transacao.setCliente(cliente);
        transacao.setDescricao(request.descricao());
        transacao.setValor(request.valor());
        transacao.setTipo(request.tipo());

        Transacao atualizada = transacaoRepository.saveAndFlush(transacao);
        return ResponseEntity.ok(TransacaoResponse.de(atualizada));
    }

    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<Void> excluir(@PathVariable Long id) {
        Transacao transacao = buscarOuFalhar(id);
        transacaoRepository.delete(transacao);
        transacaoRepository.flush();
        return ResponseEntity.noContent().build();
    }

    private Transacao buscarOuFalhar(Long id) {
        return transacaoRepository.findById(id)
                .orElseThrow(() -> new RecursoNaoEncontradoException(
                        "Transacao nao encontrada para o id " + id));
    }

    private Cliente buscarClienteOuFalhar(Long idCliente) {
        return clienteRepository.findById(idCliente)
                .orElseThrow(() -> new RecursoNaoEncontradoException(
                        "Cliente nao encontrado para o id " + idCliente));
    }
}
