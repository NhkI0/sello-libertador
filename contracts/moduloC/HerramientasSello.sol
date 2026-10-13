// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IHerramientasSello.sol";
import "../comun/ConstantesUBO.sol";

/// @title HerramientasSello — PLANTILLA del Módulo C (Curso C)
/// @notice Cálculos auxiliares en Solidity. Todas las funciones son `pure`: se pueden
///         llamar gratis desde «Deploy & Run» de Remix, sin enviar transacciones.
/// @dev    Completar los TODO. Las tres últimas funciones ya están hechas.
contract HerramientasSello is IHerramientasSello {
    error ByteNoAceptado(uint8 b);
    error ListaVacia();

    /// @dev Los 36 símbolos permitidos, en orden. ALFABETO[i] devuelve el símbolo número i.
    bytes internal constant ALFABETO = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    // ---------------------------------------------------------------
    // Localizador sin sesgo de módulo
    // ---------------------------------------------------------------
    /// @dev 256 = 7 × 36 + 4. El mayor múltiplo de 36 que cabe en 256 es 252 (7 × 36),
    ///      así que se aceptan los bytes 0..251: cada símbolo recibe exactamente 7 bytes.
    function byteAceptado(uint8 b) public pure override returns (bool) {
        return b < 252;
    }

    function simboloDe(uint8 b) public pure override returns (bytes1) {
        if (!byteAceptado(b)) revert ByteNoAceptado(b);
        return ALFABETO[b % 36];
    }

    function derivarLocalizador(bytes32 semilla) external pure override returns (bytes10) {
        bytes memory resultado = new bytes(10);
        uint256 n = 0;
        bytes32 h = keccak256(abi.encode(semilla));
        while (n < 10) {
            for (uint256 i = 0; i < 32 && n < 10; i++) {
                uint8 b = uint8(h[i]);
                if (byteAceptado(b)) {
                    resultado[n++] = simboloDe(b);
                }
            }
            if (n < 10) h = keccak256(abi.encode(h));
        }
        return bytes10(resultado);
    }

    // ---------------------------------------------------------------
    // Raíz de Merkle
    // ---------------------------------------------------------------
    function raizDeMerkle(bytes32[] calldata hojas) external pure override returns (bytes32) {
        // TODO: revertir con ListaVacia si no hay hojas
        // TODO: copiar las hojas a memoria y reducir nivel a nivel:
        //       - emparejar (0,1), (2,3), ... con _hashPar
        //       - si sobra un nodo, sube tal cual al nivel siguiente
        //       - repetir hasta que quede un solo nodo: la raíz
        hojas;
        revert("TODO: raizDeMerkle");
    }

    /// @dev Hash de un par ordenado, igual que MerkleProof de OpenZeppelin. YA HECHA.
    function _hashPar(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // ---------------------------------------------------------------
    // Funciones YA HECHAS (no modificar)
    // ---------------------------------------------------------------
    function hashDocumento(string calldata documentoCanonico) external pure override returns (bytes32) {
        return keccak256(bytes(documentoCanonico));
    }

    function compromiso(bytes32 sal, bytes32 hashDoc) external pure override returns (bytes32) {
        return ConstantesUBO.compromiso(sal, hashDoc);
    }

    function hojaLote(bytes10 localizador, bytes32 compromiso_) external pure override returns (bytes32) {
        return ConstantesUBO.hojaLote(localizador, compromiso_);
    }
}
