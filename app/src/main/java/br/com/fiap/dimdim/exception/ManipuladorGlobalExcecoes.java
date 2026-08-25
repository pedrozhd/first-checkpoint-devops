package br.com.fiap.dimdim.exception;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class ManipuladorGlobalExcecoes {

    /**
     * Recurso inexistente -> 404.
     */
    @ExceptionHandler({RecursoNaoEncontradoException.class, EntityNotFoundException.class})
    public ResponseEntity<ErroResposta> tratarNaoEncontrado(RuntimeException ex) {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ErroResposta.de(404, "Nao encontrado", ex.getMessage()));
    }

    /**
     * Violacao de integridade referencial ou de unicidade -> 409.
     *
     * O caso central e a tentativa de apagar um cliente que possui transacoes:
     * a FK esta declarada como ON DELETE RESTRICT, o MySQL devolve ERROR 1451 e
     * o Spring o traduz em DataIntegrityViolationException. Sem este handler a
     * resposta seria um 500 com stack trace.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErroResposta> tratarViolacaoIntegridade(DataIntegrityViolationException ex) {
        String causa = ex.getMostSpecificCause().getMessage();
        String mensagem;

        if (causa != null && causa.contains("uk_cliente_cpf")) {
            mensagem = "Ja existe um cliente cadastrado com este CPF.";
        } else if (causa != null && causa.contains("fk_transacao_cliente")) {
            mensagem = "Nao e possivel excluir o cliente: existem transacoes vinculadas a ele. "
                     + "Exclua primeiro as transacoes do cliente.";
        } else if (causa != null && causa.contains("ck_transacao_tipo")) {
            mensagem = "Tipo de transacao invalido. Valores aceitos: CREDITO ou DEBITO.";
        } else {
            mensagem = "A operacao viola uma regra de integridade do banco de dados.";
        }

        return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .body(ErroResposta.de(409, "Conflito de integridade", mensagem));
    }

    /**
     * Falha de validacao dos DTOs anotados com @Valid -> 400, campo a campo.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErroResposta> tratarValidacao(MethodArgumentNotValidException ex) {
        Map<String, String> campos = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(erro -> campos.put(erro.getField(), erro.getDefaultMessage()));

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(ErroResposta.de(400, "Requisicao invalida",
                        "Um ou mais campos estao invalidos.", campos));
    }

    /**
     * JSON malformado ou tipo incompativel -> 400.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErroResposta> tratarJsonInvalido(HttpMessageNotReadableException ex) {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(ErroResposta.de(400, "Requisicao invalida",
                        "Corpo da requisicao ausente ou com JSON malformado."));
    }
}
