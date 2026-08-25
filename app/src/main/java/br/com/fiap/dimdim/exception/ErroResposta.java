package br.com.fiap.dimdim.exception;

import java.time.LocalDateTime;
import java.util.Map;

public record ErroResposta(
        LocalDateTime timestamp,
        int status,
        String erro,
        String mensagem,
        Map<String, String> campos
) {

    public static ErroResposta de(int status, String erro, String mensagem) {
        return new ErroResposta(LocalDateTime.now(), status, erro, mensagem, null);
    }

    public static ErroResposta de(int status, String erro, String mensagem, Map<String, String> campos) {
        return new ErroResposta(LocalDateTime.now(), status, erro, mensagem, campos);
    }
}
