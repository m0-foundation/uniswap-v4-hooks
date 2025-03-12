// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { BalanceDelta } from "../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { PoolKey } from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { BaseTickRangeHook } from "./abstract/BaseTickRangeHook.sol";

/**
 * @title  Tick Range Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range.
 */
contract TickRangeHook is BaseTickRangeHook {
    /* ============ Constructor ============ */

    /**
     * @notice Constructs the TickRangeHook contract.
     * @param  poolManager_    The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_ The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_ The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  owner_          The owner of the contract.
     */
    constructor(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address owner_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, owner_) {}

    /* ============ Hook functions ============ */

    /**
     * @dev    Hook that is called after the pool is initialized.
     * @param  tick_ The initial tick of the pool.
     * @return The selector of this function.
     */
    function _afterInitialize(
        address /* sender */,
        PoolKey calldata /* poolKey */,
        uint160 /* sqrtPriceX96 */,
        int24 tick_
    ) internal view override returns (bytes4) {
        super._afterInitialize(tick_);
        return this.afterInitialize.selector;
    }

    /**
     * @dev    Hook that is called after a swap is executed.
     * @param  key_ The key of the pool.
     * @return A tuple containing the selector of this function and the hook's delta in unspecified currency.
     */
    function _afterSwap(
        address /* sender_ */,
        PoolKey calldata key_,
        IPoolManager.SwapParams calldata /* params */,
        BalanceDelta /* delta */,
        bytes calldata /* hookData */
    ) internal view override returns (bytes4, int128) {
        super._afterSwap(key_);
        return (this.afterSwap.selector, int128(0));
    }

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
