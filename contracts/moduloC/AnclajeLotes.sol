// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.1.0/utils/cryptography/MerkleProof.sol";
import "../interfaces/IAnclajeLotes.sol";
import "../interfaces/IRegistroEmisores.sol";
import "../comun/ConstantesUBO.sol";

/// @title AnclajeLotes — PLANTILLA del Módulo C (Curso C)
/// @notice MODO ECONÓMICO, alternativo a RegistroTitulos: ancla la raíz de Merkle de una
///         ceremonia completa en UNA transacción, sin guardar cada título en la cadena.
///         No se usa sobre los mismos títulos que ya están en RegistroTitulos: es otra
///         forma de emitir, más barata y con menos funciones (no hay estado por título).
/// @dev    Completar los TODO. Requisitos mínimos:
///         - Solo emisores autorizados AHORA en la facultad.
///         - Rechazar raíz vacía y raíces repetidas.
///         - Hoja = ConstantesUBO.hojaLote(localizador, compromiso).
///         - Verificación con MerkleProof.verify (pares ordenados).
contract AnclajeLotes is IAnclajeLotes {
    error NoAutorizado(address cuenta, bytes32 facultad);
    error RaizInvalida();
    error RaizDuplicada(bytes32 raiz);
    error LoteInexistente(uint256 loteId);

    struct Lote {
        bytes32 raiz;
        bytes32 facultad;
        bytes32 idCeremonia;
        address emisor;
        uint64 fecha;
    }

    IRegistroEmisores public immutable registro;
    mapping(uint256 => Lote) private _lotes;
    mapping(bytes32 => bool) private _raizUsada;
    uint256 private _siguienteId = 1;

    constructor(address registro_) {
        registro = IRegistroEmisores(registro_);
    }

    /// @dev Orden: autorización (estaAutorizado, el presente), raíz vacía, raíz repetida.
    ///      Se escribe el estado solo después de validar todo.
    function anclarLote(bytes32 raiz, bytes32 facultad, bytes32 idCeremonia)
        external
        override
        returns (uint256 loteId)
    {
        if (!registro.estaAutorizado(msg.sender, facultad)) revert NoAutorizado(msg.sender, facultad);
        if (raiz == bytes32(0)) revert RaizInvalida();
        if (_raizUsada[raiz]) revert RaizDuplicada(raiz);

        loteId = _siguienteId++;
        _raizUsada[raiz] = true;
        _lotes[loteId] = Lote(raiz, facultad, idCeremonia, msg.sender, uint64(block.timestamp));
        emit LoteAnclado(loteId, facultad, raiz, idCeremonia, msg.sender);
    }

    /// @dev Un lote existe si tiene raíz: anclarLote nunca guarda una raíz vacía.
    function verificarInclusion(
        uint256 loteId,
        bytes10 localizador,
        bytes32 compromiso,
        bytes32[] calldata prueba
    ) external view override returns (bool) {
        bytes32 raiz = _lotes[loteId].raiz;
        if (raiz == bytes32(0)) revert LoteInexistente(loteId);
        return MerkleProof.verifyCalldata(prueba, raiz, ConstantesUBO.hojaLote(localizador, compromiso));
    }

    function obtenerLote(uint256 loteId) external view returns (Lote memory) {
        return _lotes[loteId];
    }
}
