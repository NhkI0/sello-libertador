// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/moduloC/VerificadorUBO.sol";
import "../contracts/moduloC/AnclajeLotes.sol";
import "../contracts/moduloC/HerramientasSello.sol";
import "../contracts/simulacros/SimRegistroEmisores.sol";
import "../contracts/simulacros/SimRegistroTitulos.sol";
import "../contracts/comun/ConstantesUBO.sol";
import "../contracts/comun/ActorPruebas.sol";

/// @title Pruebas del Módulo C — PLANTILLA (Curso C)
/// @notice Usa SimRegistroEmisores y SimRegistroTitulos en lugar de los módulos reales.
///         Mínimo 8 pruebas. Dos están resueltas como ejemplo; completar el resto.
contract ModuloCTest {
    SimRegistroEmisores registro;
    SimRegistroTitulos titulos;
    VerificadorUBO verificador;
    AnclajeLotes anclaje;
    HerramientasSello herramientas;
    address emisorIng = address(0xB1);
    bytes10 constant L1 = bytes10("U0ZSA8QPFN");
    bytes32 constant SAL_ = bytes32(uint256(111));
    bytes32 constant HASH_DOC = keccak256('{"programa":"ING-INFORMATICA"}');

    function beforeEach() public {
        registro = new SimRegistroEmisores();
        titulos = new SimRegistroTitulos();
        verificador = new VerificadorUBO(address(titulos), address(registro));
        anclaje = new AnclajeLotes(address(registro));
        herramientas = new HerramientasSello();
    }

    /// @dev Fabrica un título con el simulacro: emitido por emisorIng hace 100 s,
    ///      con un periodo de autorización que lo cubre.
    function _tituloValido(bytes10 loc) internal returns (bytes32 compromiso) {
        compromiso = ConstantesUBO.compromiso(SAL_, HASH_DOC);
        uint64 fecha = uint64(block.timestamp - 100);
        registro.fijarPeriodo(emisorIng, ConstantesUBO.ING, fecha - 1000, 0);
        titulos.fijarTitulo(loc, IRegistroTitulos.Titulo({
            compromiso: compromiso,
            emisor: emisorIng,
            facultad: ConstantesUBO.ING,
            codigoPrograma: keccak256("ING-INFORMATICA"),
            fechaEmision: fecha,
            estado: IRegistroTitulos.Estado.Emitido,
            motivo: 0,
            rectificadoComo: bytes10(0)
        }));
    }

    /// @dev Par ordenado (el menor primero), como MerkleProof de OpenZeppelin.
    function _par(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /// @dev Posición de un símbolo en "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"; 36 si no está.
    function _indice(bytes1 s) internal pure returns (uint256) {
        if (s >= "0" && s <= "9") return uint8(s) - 0x30;
        if (s >= "A" && s <= "Z") return uint8(s) - 0x41 + 10;
        return 36;
    }

    // ---------- EJEMPLO 1 (resuelto) ----------
    function veredictoValido() public {
        bytes32 c = _tituloValido(L1);
        Assert.equal(uint256(verificador.verificar(L1, c)),
            uint256(IVerificadorUBO.Veredicto.Valido), "Debe ser valido");
    }

    // ---------- EJEMPLO 2 (resuelto) ----------
    function documentoAlteradoUnCaracter() public {
        _tituloValido(L1);
        bytes32 alterado = ConstantesUBO.compromiso(SAL_, keccak256('{"programa":"ING-INFORMATICB"}'));
        Assert.equal(uint256(verificador.verificar(L1, alterado)),
            uint256(IVerificadorUBO.Veredicto.DocumentoAlterado), "Debe detectar la alteracion");
    }

    // ---------- PRUEBAS OBLIGATORIAS (completar) ----------
    function veredictosInexistenteYEmisorNoAutorizado() public {
        // TODO: un localizador nunca emitido -> Inexistente;
        //       fijarPeriodo() que empiece DESPUÉS de fechaEmision -> EmisorNoAutorizado
        Assert.ok(false, "TODO");
    }

    function veredictosRevocadoSuspendidoYOrden() public {
        // TODO: suspender -> Suspendido; revocar -> Revocado;
        //       un título revocado Y con documento alterado debe dar Revocado
        Assert.ok(false, "TODO");
    }

    function explicacionDeRectificacion() public {
        // TODO: rectificar L1 a otro localizador con el simulacro y comprobar que
        //       verificarConExplicacion(L1, ...) menciona el nuevo localizador
        Assert.ok(false, "TODO");
    }

    function loteYPruebasDeInclusion() public {
        bytes10 l2 = bytes10("AB12CD34EF");
        bytes32 c1 = ConstantesUBO.compromiso(SAL_, HASH_DOC);
        bytes32 c2 = ConstantesUBO.compromiso(SAL_, keccak256('{"programa":"ING-CIVIL"}'));
        bytes32 h1 = ConstantesUBO.hojaLote(L1, c1);
        bytes32 h2 = ConstantesUBO.hojaLote(l2, c2);

        registro.autorizarEmisor(address(this), ConstantesUBO.ING);
        uint256 loteId = anclaje.anclarLote(_par(h1, h2), ConstantesUBO.ING, keccak256("CEREMONIA-2026-12"));

        bytes32[] memory prueba = new bytes32[](1);
        prueba[0] = h2;
        Assert.ok(anclaje.verificarInclusion(loteId, L1, c1, prueba), "La prueba correcta debe dar true");
        prueba[0] = keccak256("hermano falso");
        Assert.ok(!anclaje.verificarInclusion(loteId, L1, c1, prueba), "Una prueba falsa debe dar false");

        ActorPruebas intruso = new ActorPruebas();
        try intruso.llamar(address(anclaje),
            abi.encodeCall(IAnclajeLotes.anclarLote, (keccak256("otra raiz"), ConstantesUBO.ING, bytes32(0)))) {
            Assert.ok(false, "Un emisor no autorizado no debe poder anclar");
        } catch (bytes memory err) {
            Assert.equal(keccak256(err), keccak256(abi.encodeWithSelector(
                AnclajeLotes.NoAutorizado.selector, address(intruso), ConstantesUBO.ING)),
                "Debe revertir con NoAutorizado");
        }
    }

    function localizadorSinSesgo() public {
        // (a) Enumeración exacta: 252 bytes aceptados / 36 símbolos = 7 por símbolo
        uint256[36] memory cuenta;
        for (uint256 b = 0; b < 256; b++) {
            if (herramientas.byteAceptado(uint8(b))) cuenta[_indice(herramientas.simboloDe(uint8(b)))]++;
        }
        for (uint256 i = 0; i < 36; i++) {
            Assert.equal(cuenta[i], 7, "Cada simbolo debe recibir 7 bytes aceptados");
        }

        // (b) 10 símbolos del alfabeto, determinista, cambia con la semilla
        bytes10 a = herramientas.derivarLocalizador(keccak256("semilla 1"));
        for (uint256 i = 0; i < 10; i++) {
            Assert.ok(_indice(a[i]) < 36, "Cada simbolo debe estar en el alfabeto");
        }
        Assert.equal(bytes32(herramientas.derivarLocalizador(keccak256("semilla 1"))), bytes32(a),
            "La misma semilla debe dar el mismo localizador");
        Assert.notEqual(bytes32(herramientas.derivarLocalizador(keccak256("semilla 2"))), bytes32(a),
            "Otra semilla debe dar otro localizador");
    }

    function raizDeMerkleEnSolidity() public {
        bytes32 h1 = ConstantesUBO.hojaLote(bytes10("AAAAAAAAA1"), keccak256("c1"));
        bytes32 h2 = ConstantesUBO.hojaLote(bytes10("AAAAAAAAA2"), keccak256("c2"));
        bytes32 h3 = ConstantesUBO.hojaLote(bytes10("AAAAAAAAA3"), keccak256("c3"));

        bytes32[] memory tres = new bytes32[](3);
        tres[0] = h1; tres[1] = h2; tres[2] = h3;
        Assert.equal(herramientas.raizDeMerkle(tres), _par(_par(h1, h2), h3),
            "Con 3 hojas, la tercera sube sin emparejar");

        bytes32[] memory una = new bytes32[](1);
        una[0] = h1;
        Assert.equal(herramientas.raizDeMerkle(una), h1, "Con 1 hoja, la raiz es la hoja");

        try herramientas.raizDeMerkle(new bytes32[](0)) returns (bytes32) {
            Assert.ok(false, "Con 0 hojas debe revertir");
        } catch (bytes memory err) {
            Assert.equal(keccak256(err), keccak256(abi.encodeWithSelector(HerramientasSello.ListaVacia.selector)),
                "Debe revertir con ListaVacia");
        }
    }
}
