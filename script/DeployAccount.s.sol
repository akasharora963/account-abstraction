// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {BasicAccount} from "src/ethereum/BasicAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployAccount is Script {
    function run() public {
        deployBasicAccount();
    }

    function deployBasicAccount() public returns (HelperConfig, BasicAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        BasicAccount basicAccount = new BasicAccount(config.entryPoint);
        basicAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, basicAccount);
    }
}
