// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Deploy } from "../base/Deploy.s.sol";

contract DeployAllowlistHookAndPool is Deploy {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            vm.envAddress("TOKEN_0"),
            vm.envAddress("TOKEN_1"),
            int24(vm.envInt("TICK_LOWER_BOUND")),
            int24(vm.envInt("TICK_UPPER_BOUND"))
        );

        vm.startBroadcast(deployer);

        address allowlistHook = _deployAllowlistHook(admin, manager, config);

        vm.recordLogs();
        _deployPool(config, IHooks(allowlistHook));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        _logPoolDeployment(logs);

        vm.stopBroadcast();
    }
}
