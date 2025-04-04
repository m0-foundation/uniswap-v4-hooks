// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { BaseHookUpgradeable } from "../../src/abstract/BaseHookUpgradeable.sol";

contract BaseHookUpgradeableHarness is BaseHookUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address poolManager_) public virtual initializer {
        __BaseHookUpgradeable_init(poolManager_);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: true,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterAddLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: true,
                afterDonate: true,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: true,
                afterRemoveLiquidityReturnDelta: true
            });
    }

    function _authorizeUpgrade(address) internal override {}
}
