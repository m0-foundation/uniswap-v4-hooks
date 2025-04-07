// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { TickRangeHook } from "../../src/TickRangeHook.sol";

contract TickRangeHookHarness is TickRangeHook {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_,
        address upgrader_
    ) public virtual override initializer {
        __BaseTickRangeHookUpgradeable_init(
            poolManager_,
            tickLowerBound_,
            tickUpperBound_,
            admin_,
            manager_,
            upgrader_
        );
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function checkTick(int24 tick_) external view {
        _checkTick(tick_);
    }
}
