package br.com.fiap.dimdim.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record TransacaoRequest(

        @NotNull(message = "idCliente e obrigatorio")
        Long idCliente,

        @NotBlank(message = "descricao e obrigatoria")
        @Size(max = 200, message = "descricao deve ter no maximo 200 caracteres")
        String descricao,

        // inclusive=false garante valor estritamente maior que zero
        @NotNull(message = "valor e obrigatorio")
        @DecimalMin(value = "0.00", inclusive = false, message = "valor deve ser maior que zero")
        @Digits(integer = 13, fraction = 2, message = "valor deve ter no maximo 13 inteiros e 2 decimais")
        BigDecimal valor,

        @NotBlank(message = "tipo e obrigatorio")
        @Pattern(regexp = "CREDITO|DEBITO", message = "tipo deve ser CREDITO ou DEBITO")
        String tipo
) {
}
