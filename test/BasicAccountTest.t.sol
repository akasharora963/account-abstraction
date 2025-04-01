// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BasicAccount} from "src/ethereum/BasicAccount.sol";
import {DeployAccount} from "script/DeployAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BasicAccountTest is Test {
    HelperConfig helperConfig;
    BasicAccount basicAccount;
    ERC20Mock usdc;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployAccount deploy = new DeployAccount();
        (helperConfig, basicAccount) = deploy.deployBasicAccount();
        usdc = new ERC20Mock();
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
}
