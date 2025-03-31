// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { BalanceDelta } from "../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { PoolKey } from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { BaseTickRangeHook } from "./abstract/BaseTickRangeHook.sol";

import { IAdminMigratable } from "./interfaces/IAdminMigratable.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";

/**
 * @title  Tick Range Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range.
 */
contract TickRangeHook is BaseTickRangeHook {
    /* ============ Variables ============ */

    /// @inheritdoc IAdminMigratable
    bytes32 public constant override MIGRATOR_KEY_PREFIX = "allowlist_hook_migrator_v1";

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the TickRangeHook contract.
     * @param  poolManager_    The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_ The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_ The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  registrar_      The address of the registrar contract.
     * @param  owner_          The owner of the contract.
     * @param  migrationAdmin_ The address allowed to migrate the contract.
     */
    constructor(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address registrar_,
        address owner_,
        address migrationAdmin_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, registrar_, owner_, migrationAdmin_) {}

    /* ============ Hook functions ============ */

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

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the address of the contract to use as a migrator, if any.
    function _getMigrator() internal view override returns (address) {
        return
            address(
                uint160(
                    // NOTE: A subsequent implementation should use a unique migrator prefix.
                    uint256(IRegistrarLike(registrar).get(keccak256(abi.encode(MIGRATOR_KEY_PREFIX, address(this)))))
                )
            );
    }
}
