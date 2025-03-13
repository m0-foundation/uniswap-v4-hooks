// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { TickRangeHook } from "../../src/TickRangeHook.sol";

import { Deploy } from "../base/Deploy.sol";

contract DeployTickRangeHook is Deploy, Script {
    function run() public {
        address owner_ = vm.envAddress("OWNER");
        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        // Deploy the hook using CREATE2
        vm.startBroadcast();

        _deployTickRangeHook(owner_, config_);

        vm.stopBroadcast();
    }
}
