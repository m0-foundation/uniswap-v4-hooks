// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { TickRangeHook } from "../src/TickRangeHook.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract TickRangeHookScript is Script {
    TickRangeHook internal tickRangeHook;

    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address poolManager_ = vm.envAddress("POOL_MANAGER");
        address owner_ = vm.envAddress("OWNER");

        vm.startBroadcast(deployer_);

        tickRangeHook = new TickRangeHook(poolManager_, 0, 1, owner_);

        vm.stopBroadcast();
    }
}
