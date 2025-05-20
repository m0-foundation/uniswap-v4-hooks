// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { AllowlistHook } from "../../src/AllowlistHook.sol";

contract AllowlistHookHarness is AllowlistHook {
    constructor(
        address positionManager_,
        address swapRouter_,
        address poolManager_,
        address serviceManager_,
        string memory policyID_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    )
        AllowlistHook(
            positionManager_,
            swapRouter_,
            poolManager_,
            serviceManager_,
            policyID_,
            tickLowerBound_,
            tickUpperBound_,
            admin_,
            manager_
        )
    {}
}
