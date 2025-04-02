// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BasicAccount} from "src/ethereum/BasicAccount.sol";
import {DeployAccount} from "script/DeployAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";

contract BasicAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    BasicAccount basicAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployAccount deploy = new DeployAccount();
        (helperConfig, basicAccount) = deploy.deployBasicAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    //Usdc mint
    //msg.sender->basicAccount
    function testOwnerCanExecute() public {
        //Arrange
        assertEq(usdc.balanceOf(address(basicAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(basicAccount), AMOUNT);
        //Act
        vm.startPrank(basicAccount.owner());
        basicAccount.execute(destination, value, data);
        vm.stopPrank();

        //Assert
        assertEq(usdc.balanceOf(address(basicAccount)), AMOUNT);
    }

    function test_RevertIfNotOwnerCanExecute() public {
        //Arrange
        assertEq(usdc.balanceOf(address(basicAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(basicAccount), AMOUNT);
        //Act
        vm.startPrank(randomUser);
        vm.expectRevert(BasicAccount.BasicAccount__NotFromEntryPointOrOwner.selector);
        basicAccount.execute(destination, value, data);
        vm.stopPrank();
    }

    function testRecoverSignedUserOp() public {
        //Arrange
        assertEq(usdc.balanceOf(address(basicAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(basicAccount), AMOUNT);

        bytes memory executeData = abi.encodeWithSelector(BasicAccount.execute.selector, destination, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedPackedOp(executeData, helperConfig.getConfig());
        //Act
        address entryPoint = helperConfig.getConfig().entryPoint;

        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);
        address sender = ECDSA.recover(userOpHash.toEthSignedMessageHash(), userOp.signature);

        // Assert
        assertEq(sender, basicAccount.owner());
    }

    function testValidateUserOp() public {
        //Arrange
        assertEq(usdc.balanceOf(address(basicAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(basicAccount), AMOUNT);

        bytes memory executeData = abi.encodeWithSelector(BasicAccount.execute.selector, destination, value, data);
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedPackedOp(executeData, helperConfig.getConfig());
        address entryPoint = helperConfig.getConfig().entryPoint;
        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);
        uint256 missingAccountFunds = 1 ether;

        //Act
        vm.startPrank(msg.sender);
        (bool success,) = payable(address(basicAccount)).call{value: missingAccountFunds, gas: type(uint256).max}("");
        vm.stopPrank();

        vm.startPrank(entryPoint);
        uint256 validationData = basicAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);
        uint256 balance2 = address(entryPoint).balance;

        vm.stopPrank();

        // Assert
        assert(validationData == SIG_VALIDATION_SUCCESS);
    }
}
