// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Deploy } from "../base/Deploy.s.sol";

contract DeployTickRangeHook is Deploy {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");

        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");

        DeployConfig memory config = _getDeployConfig(block.chainid, tokenA, tokenB);

        vm.startBroadcast(deployer);

        _deployTickRangeHook(admin, manager, config);

        vm.stopBroadcast();
    }
}
