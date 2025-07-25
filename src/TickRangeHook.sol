// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { PoolKey } from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { BaseTickRangeHook } from "./abstract/BaseTickRangeHook.sol";

/**
 * @title  Tick Range Hook
 * @author M0 Labs
 * @notice Hook restricting liquidity provision to a specific tick range.
 */
contract TickRangeHook is BaseTickRangeHook {
    /* ============ Constructor ============ */

    /**
     * @notice Constructs the TickRangeHook contract.
     * @param  poolManager_    The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_ The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_ The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_           The address administrating the hook. Can grant and revoke roles.
     * @param  manager_         The address managing the hook.
     */
    constructor(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, admin_, manager_) {}

    /* ============ Hook functions ============ */

    /**
     * @dev    Hook that is called before liquidity is added.
     * @dev    Will revert if the sender is not allowed to add liquidity.
     * @param  params_ The parameters for modifying liquidity.
     * @return The selector of this function.
     */
    function _beforeAddLiquidity(
        address /* sender */,
        PoolKey calldata /* key */,
        IPoolManager.ModifyLiquidityParams calldata params_,
        bytes calldata /* hookData */
    ) internal view override returns (bytes4) {
        super._beforeAddLiquidity(params_);
        return this.beforeAddLiquidity.selector;
    }
}
