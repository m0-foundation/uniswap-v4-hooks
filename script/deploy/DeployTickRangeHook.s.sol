// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHook is Deploy {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address admin = vm.envAddress("OWNER");
        address manager = vm.envAddress("MANAGER");
        address upgrader = vm.envAddress("UPGRADER");
        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.startBroadcast();

        _deployTickRangeHook(deployer, admin, manager, upgrader, config);

        vm.stopBroadcast();
    }
}
