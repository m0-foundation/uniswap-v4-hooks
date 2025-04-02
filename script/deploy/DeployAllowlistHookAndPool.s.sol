// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Deploy } from "../base/Deploy.s.sol";

contract DeployAllowlistHookAndPool is Deploy {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address admin = vm.envAddress("OWNER");
        address manager = vm.envAddress("MANAGER");
        address upgrader = vm.envAddress("UPGRADER");
        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.startBroadcast();

        (, address allowlistHookProxy) = _deployAllowlistHook(deployer, admin, manager, upgrader, config);

        vm.recordLogs();
        _deployPool(config, IHooks(allowlistHookProxy));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        _logPoolDeployment(logs);

        vm.stopBroadcast();
    }
}
