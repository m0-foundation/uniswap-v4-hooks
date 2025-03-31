// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { AllowlistHook } from "../../src/AllowlistHook.sol";

import { Deploy } from "../base/Deploy.sol";

contract DeployAllowlistHookAndPool is Deploy, Script {
    function run() public {
        address owner_ = vm.envAddress("OWNER");
        address migrationAdmin_ = vm.envAddress("MIGRATION_ADMIN");
        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        // Deploy the hook using CREATE2
        vm.startBroadcast();

        IHooks allowlistHook_ = _deployAllowlistHook(owner_, migrationAdmin_, config_);

        vm.recordLogs();
        _deployPool(config_, allowlistHook_);

        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        _logPoolDeployment(logs_);

        vm.stopBroadcast();
    }
}
