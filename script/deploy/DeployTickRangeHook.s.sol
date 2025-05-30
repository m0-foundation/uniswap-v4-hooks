// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHook is Deploy {
    function run() public {
        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");
        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.startBroadcast();

        _deployTickRangeHook(admin, manager, config);

        vm.stopBroadcast();
    }
}
