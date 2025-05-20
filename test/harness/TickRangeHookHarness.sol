// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { TickRangeHook } from "../../src/TickRangeHook.sol";

contract TickRangeHookHarness is TickRangeHook {
    constructor(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    ) TickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, admin_, manager_) {}

    function checkTick(int24 tick_) external view {
        _checkTick(tick_);
    }
}
