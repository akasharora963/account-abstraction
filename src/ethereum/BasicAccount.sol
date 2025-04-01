// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "@account-abstraction/contracts/core/Helpers.sol";

contract BasicAccount is IAccount, Ownable {
    error MISSING_ACCOUNT_FUNDS();

    constructor() Ownable(msg.sender) {}

    /**
     * @param userOp - The user operation to validate.
     * @param userOpHash - The hash of the user operation to validate.
     * @param missingAccountFunds - The amount of funds the user will need to deposit to cover the cost of the user operation.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {
        //the signature is valid if  sender is the owner
        validationData = _validateSignature(userOp, userOpHash);
        //_validateNonce(userOp.nonce);
        bool success = _payPreFund(missingAccountFunds);
        if (!success) {
            revert MISSING_ACCOUNT_FUNDS();
        }
    }

    //the signature is valid if  sender is the owner
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPreFund(uint256 missingAccountFunds) internal returns (bool success) {
        if (missingAccountFunds != 0) {
            (success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
        }
    }
}
