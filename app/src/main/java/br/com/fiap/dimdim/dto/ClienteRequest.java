package br.com.fiap.dimdim.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ClienteRequest(

        @NotBlank(message = "nome e obrigatorio")
        @Size(max = 120, message = "nome deve ter no maximo 120 caracteres")
        String nome,

        @NotBlank(message = "cpf e obrigatorio")
        @Pattern(regexp = "\\d{11}", message = "cpf deve conter exatamente 11 digitos numericos")
        String cpf,

        @NotBlank(message = "email e obrigatorio")
        @Email(message = "email invalido")
        @Size(max = 150, message = "email deve ter no maximo 150 caracteres")
        String email
) {
}
