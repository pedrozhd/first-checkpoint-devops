package br.com.fiap.dimdim.dto;

import br.com.fiap.dimdim.entity.Cliente;

import java.time.LocalDateTime;

public record ClienteResponse(
        Long idCliente,
        String nome,
        String cpf,
        String email,
        LocalDateTime dataCadastro
) {

    public static ClienteResponse de(Cliente cliente) {
        return new ClienteResponse(
                cliente.getIdCliente(),
                cliente.getNome(),
                cliente.getCpf(),
                cliente.getEmail(),
                cliente.getDataCadastro()
        );
    }
}
