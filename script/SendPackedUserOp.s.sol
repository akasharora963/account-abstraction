// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedPackedOp(bytes memory callData, HelperConfig.NetworkConfig memory config)
        public
        view
        returns (PackedUserOperation memory)
    {
        //Generate Unsigned Data
        address sender = config.account;
        uint256 nonce = vm.getNonce(sender);
        PackedUserOperation memory userOp = _generateUnsignedPackedOp(callData, sender, nonce);

        // get userop hash
        address entryPoint = config.entryPoint;
        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // sign
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(sender, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v); //odder is important
        return userOp;
    }

    function _generateUnsignedPackedOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: uint256(verificationGasLimit),
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
