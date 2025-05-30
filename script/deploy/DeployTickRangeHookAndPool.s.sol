// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHookAndPool is Deploy {
    function run() public {
        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");
        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.startBroadcast();

        address tickRangeHook = _deployTickRangeHook(admin, manager, config);

        vm.recordLogs();
        _deployPool(config, IHooks(tickRangeHook));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        _logPoolDeployment(logs);

        vm.stopBroadcast();
    }
}
