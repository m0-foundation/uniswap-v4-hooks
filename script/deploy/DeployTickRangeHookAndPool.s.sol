// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHookAndPool is Deploy {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            vm.envAddress("TOKEN_A"),
            vm.envAddress("TOKEN_B"),
            int24(vm.envInt("TICK_LOWER_BOUND")),
            int24(vm.envInt("TICK_UPPER_BOUND"))
        );

        vm.startBroadcast(deployer);

        address tickRangeHook = _deployTickRangeHook(admin, manager, config);

        vm.recordLogs();
        _deployPool(config, IHooks(tickRangeHook));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        _logPoolDeployment(logs);

        vm.stopBroadcast();
    }
}
