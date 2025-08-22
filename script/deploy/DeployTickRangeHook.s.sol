// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHook is Deploy {
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

        _deployTickRangeHook(admin, manager, config);

        vm.stopBroadcast();
    }
}
