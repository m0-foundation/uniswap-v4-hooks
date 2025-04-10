// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {
    AccessControlUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";

import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IBaseTickRangeHook } from "../interfaces/IBaseTickRangeHook.sol";

import { BaseHookUpgradeable } from "./BaseHookUpgradeable.sol";

/**
 * @title  Base Tick Range Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range.
 */
abstract contract BaseTickRangeHook is IBaseTickRangeHook, BaseHookUpgradeable, AccessControlUpgradeable {
    using StateLibrary for IPoolManager;

    /* ============ Variables ============ */

    /// @dev The role that can manage the hook.
    bytes32 internal constant _MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev The role that can upgrade the implementation.
    bytes32 internal constant _UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @inheritdoc IBaseTickRangeHook
    int24 public tickLowerBound;

    /// @inheritdoc IBaseTickRangeHook
    int24 public tickUpperBound;

    /* ============ Initializer ============ */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the TickRangeHook contract.
     * @dev Needs to be called in the initialize function of the derived contract.
     * @param  poolManager_    The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_ The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_ The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_          The address admnistrating the hook. Can grant and revoke roles.
     * @param  manager_        The address managing the hook.
     * @param  upgrader_       The address allowed to upgrade the implementation.
     */
    function __BaseTickRangeHookUpgradeable_init(
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_,
        address upgrader_
    ) internal onlyInitializing {
        __BaseHookUpgradeable_init(poolManager_);

        if (admin_ == address(0)) revert ZeroAdmin();
        if (manager_ == address(0)) revert ZeroManager();
        if (upgrader_ == address(0)) revert ZeroUpgrader();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(_MANAGER_ROLE, manager_);
        _grantRole(_UPGRADER_ROLE, upgrader_);

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
    function setTickRange(int24 tickLowerBound_, int24 tickUpperBound_) external onlyRole(_MANAGER_ROLE) {
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

    /* ============ Internal Upgrade function ============ */

    /**
     * @dev Called by {upgradeToAndCall} to authorize the upgrade.
     *      Will revert if `msg.sender` has not the `_UPGRADER_ROLE`.
     */
    function _authorizeUpgrade(address) internal override onlyRole(_UPGRADER_ROLE) {}
}
