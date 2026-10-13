// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IVerificadorUBO.sol";
import "../interfaces/IRegistroTitulos.sol";
import "../interfaces/IRegistroEmisores.sol";

/// @title VerificadorUBO — Módulo C (Curso C)
/// @notice Aplica la regla RN-06 y devuelve un veredicto.
/// @dev    Orden OBLIGATORIO (el primero que falla decide):
///         1) Inexistente  2) EmisorNoAutorizado (en la FECHA DE EMISIÓN)
///         3) Revocado     4) Suspendido   5) DocumentoAlterado   6) Valido
contract VerificadorUBO is IVerificadorUBO {
    IRegistroTitulos public immutable titulos;
    IRegistroEmisores public immutable registro;

    constructor(address titulos_, address registro_) {
        titulos = IRegistroTitulos(titulos_);
        registro = IRegistroEmisores(registro_);
    }

    function verificar(bytes10 localizador, bytes32 compromisoRecalculado)
        external
        view
        override
        returns (Veredicto)
    {
        return _veredicto(titulos.obtenerTitulo(localizador), compromisoRecalculado);
    }

    /// @notice Versión explicativa para el verificador humano.
    /// @dev    Devuelve el veredicto y un texto claro en español para un empleador.
    ///         Si el título fue rectificado, indica el nuevo localizador (rectificadoComo).
    function verificarConExplicacion(bytes10 localizador, bytes32 compromisoRecalculado)
        external
        view
        returns (Veredicto veredicto, string memory explicacion)
    {
        IRegistroTitulos.Titulo memory t = titulos.obtenerTitulo(localizador);
        veredicto = _veredicto(t, compromisoRecalculado);

        if (veredicto == Veredicto.Valido) {
            explicacion = "Titulo valido emitido por la UBO";
        } else if (veredicto == Veredicto.Inexistente) {
            explicacion = "No existe un titulo registrado con ese localizador";
        } else if (veredicto == Veredicto.EmisorNoAutorizado) {
            explicacion = "El emisor no estaba autorizado en la facultad en la fecha de emision";
        } else if (veredicto == Veredicto.Revocado) {
            if (t.rectificadoComo != bytes10(0)) {
                explicacion = string.concat(
                    "Titulo revocado por rectificacion. Pida el documento con el nuevo localizador: ",
                    _texto(t.rectificadoComo)
                );
            } else {
                explicacion = "Titulo revocado: no es valido";
            }
        } else if (veredicto == Veredicto.Suspendido) {
            explicacion = "Titulo suspendido temporalmente: no es valido por ahora";
        } else {
            explicacion = "El documento presentado no coincide con el registrado: fue alterado";
        }
    }

    /// @dev Aplica las seis comprobaciones en el orden obligatorio.
    ///      Se consulta estabaAutorizado (histórica, en la fecha de emisión), no estaAutorizado.
    function _veredicto(IRegistroTitulos.Titulo memory t, bytes32 compromisoRecalculado)
        internal
        view
        returns (Veredicto)
    {
        if (t.estado == IRegistroTitulos.Estado.Inexistente) return Veredicto.Inexistente;
        if (!registro.estabaAutorizado(t.emisor, t.facultad, t.fechaEmision)) {
            return Veredicto.EmisorNoAutorizado;
        }
        if (t.estado == IRegistroTitulos.Estado.Revocado) return Veredicto.Revocado;
        if (t.estado == IRegistroTitulos.Estado.Suspendido) return Veredicto.Suspendido;
        if (t.compromiso != compromisoRecalculado) return Veredicto.DocumentoAlterado;
        return Veredicto.Valido;
    }

    /// @dev Convierte un bytes10 (ASCII) en texto, ignorando bytes nulos.
    function _texto(bytes10 loc) internal pure returns (string memory) {
        bytes memory out = new bytes(10);
        uint256 n;
        for (uint256 i = 0; i < 10; i++) {
            if (loc[i] != 0) out[n++] = loc[i];
        }
        assembly { mstore(out, n) }
        return string(out);
    }
}
