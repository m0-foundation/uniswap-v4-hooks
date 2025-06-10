// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import { AccessControl } from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import { BaseHook } from "../../lib/v4-periphery/src/utils/BaseHook.sol";

import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";

import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IBaseTickRangeHook } from "../interfaces/IBaseTickRangeHook.sol";

/**
 * @title  Base Tick Range Hook
 * @author M0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range.
 */
abstract contract BaseTickRangeHook is IBaseTickRangeHook, BaseHook, AccessControl {
    using StateLibrary for IPoolManager;

    /* ============ Variables ============ */

    /// @inheritdoc IBaseTickRangeHook
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @inheritdoc IBaseTickRangeHook
    int24 public tickLowerBound;

    /// @inheritdoc IBaseTickRangeHook
    int24 public tickUpperBound;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the TickRangeHook contract.
     * @param  poolManager_    The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_ The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_ The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_          The address administrating the hook. Can grant and revoke roles.
     * @param  manager_        The address managing the hook.
     */
    constructor(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    ) BaseHook(IPoolManager(poolManager_)) AccessControl() {
        if (admin_ == address(0)) revert ZeroAdmin();
        if (manager_ == address(0)) revert ZeroManager();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MANAGER_ROLE, manager_);

        _setTickRange(tickLowerBound_, tickUpperBound_);
    }

    /* ============ Hook functions ============ */

    /**
     * @notice Returns a struct of permissions to signal which hook functions are to be implemented.
     * @dev    Used at deployment to validate the address correctly represents the expected permissions.
     */
    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
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

    /**
     * @dev    Hook that is called after a swap is executed.
     * @param  key_ The key of the pool.
     */
    function _afterSwap(PoolKey calldata key_) internal view {
        (, int24 tickCurrent_, , ) = poolManager.getSlot0(key_.toId());
        _checkTick(tickCurrent_);
    }

    /**
     * @dev    Hook that is called before liquidity is added.
     * @param  params_ The parameters for modifying liquidity.
     */
    function _beforeAddLiquidity(IPoolManager.ModifyLiquidityParams calldata params_) internal view {
        if (params_.tickLower < tickLowerBound || params_.tickUpper > tickUpperBound)
            revert InvalidTickRange(params_.tickLower, params_.tickUpper, tickLowerBound, tickUpperBound);
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IBaseTickRangeHook
    function setTickRange(int24 tickLowerBound_, int24 tickUpperBound_) external onlyRole(MANAGER_ROLE) {
        _setTickRange(tickLowerBound_, tickUpperBound_);
    }

    /* ============ Internal Interactive functions ============ */

    /**
     * @notice Sets the tick range to limit the liquidity provision and token swaps to.
     * @param  tickLowerBound_ The lower tick of the range.
     * @param  tickUpperBound_ The upper tick of the range.
     */
    function _setTickRange(int24 tickLowerBound_, int24 tickUpperBound_) internal {
        if (tickLowerBound_ >= tickUpperBound_) revert TicksOutOfOrder(tickLowerBound_, tickUpperBound_);

        tickLowerBound = tickLowerBound_;
        tickUpperBound = tickUpperBound_;

        emit TickRangeSet(tickLowerBound_, tickUpperBound_);
    }

    /* ============ Internal View functions ============ */

    /**
     * @notice Checks if the tick is within the defined tick range.
     * @param  tick_ The tick to check.
     */
    function _checkTick(int24 tick_) internal view {
        if (tick_ < tickLowerBound || tick_ >= tickUpperBound)
            revert InvalidTick(tick_, tickLowerBound, tickUpperBound);
    }
}
