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
 * @title  Base Tick Range Hook Storage Layout
 * @author M^0 Labs
 * @notice Abstract contract defining the storage layout of the BaseTickRangeHook contract.
 */

abstract contract BaseTickRangeHookStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.BaseTickRangeHookV0
    struct BaseTickRangeHookStorage {
        int24 tickLowerBound;
        int24 tickUpperBound;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.BaseTickRangeHookV0")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _BASE_TICK_RANGE_HOOK_V0_LOCATION =
        0x0e4acb1dbeddd067e2a463e36c9921647e116f6a35d1af0e63a77cf1b7a67800;

    function _getBaseTickRangeHookStorage() internal pure returns (BaseTickRangeHookStorage storage $) {
        assembly {
            $.slot := _BASE_TICK_RANGE_HOOK_V0_LOCATION
        }
    }
}

/**
 * @title  Base Tick Range Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range.
 */
abstract contract BaseTickRangeHook is
    IBaseTickRangeHook,
    BaseTickRangeHookStorageLayout,
    BaseHookUpgradeable,
    AccessControlUpgradeable
{
    using StateLibrary for IPoolManager;

    /* ============ Variables ============ */

    /// @inheritdoc IBaseTickRangeHook
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @inheritdoc IBaseTickRangeHook
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

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
        _grantRole(MANAGER_ROLE, manager_);
        _grantRole(UPGRADER_ROLE, upgrader_);

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
        (, int24 tickCurrent_, , ) = _getBaseHookUpgradeableStorage().poolManager.getSlot0(key_.toId());
        _checkTick(tickCurrent_);
    }

    /**
     * @dev    Hook that is called before liquidity is added.
     * @param  params_ The parameters for modifying liquidity.
     */
    function _beforeAddLiquidity(IPoolManager.ModifyLiquidityParams calldata params_) internal view {
        BaseTickRangeHookStorage storage $ = _getBaseTickRangeHookStorage();

        if (params_.tickLower < $.tickLowerBound || params_.tickUpper > $.tickUpperBound)
            revert InvalidTickRange(params_.tickLower, params_.tickUpper, $.tickLowerBound, $.tickUpperBound);
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IBaseTickRangeHook
    function setTickRange(int24 tickLowerBound_, int24 tickUpperBound_) external onlyRole(MANAGER_ROLE) {
        _setTickRange(tickLowerBound_, tickUpperBound_);
    }

    /* ============ External/Public view functions ============ */

    /// @inheritdoc IBaseTickRangeHook
    function tickLowerBound() external view returns (int24) {
        return _getBaseTickRangeHookStorage().tickLowerBound;
    }

    /// @inheritdoc IBaseTickRangeHook
    function tickUpperBound() external view returns (int24) {
        return _getBaseTickRangeHookStorage().tickUpperBound;
    }

    /* ============ Internal Interactive functions ============ */

    /**
     * @notice Sets the tick range to limit the liquidity provision and token swaps to.
     * @param  tickLowerBound_ The lower tick of the range.
     * @param  tickUpperBound_ The upper tick of the range.
     */
    function _setTickRange(int24 tickLowerBound_, int24 tickUpperBound_) internal {
        if (tickLowerBound_ >= tickUpperBound_) revert TicksOutOfOrder(tickLowerBound_, tickUpperBound_);

        BaseTickRangeHookStorage storage $ = _getBaseTickRangeHookStorage();

        $.tickLowerBound = tickLowerBound_;
        $.tickUpperBound = tickUpperBound_;

        emit TickRangeSet(tickLowerBound_, tickUpperBound_);
    }

    /* ============ Internal View functions ============ */

    /**
     * @notice Checks if the tick is within the defined tick range.
     * @param  tick_ The tick to check.
     */
    function _checkTick(int24 tick_) internal view {
        BaseTickRangeHookStorage storage $ = _getBaseTickRangeHookStorage();

        if (tick_ < $.tickLowerBound || tick_ >= $.tickUpperBound)
            revert InvalidTick(tick_, $.tickLowerBound, $.tickUpperBound);
    }

    /* ============ Internal Upgrade function ============ */

    /**
     * @dev Called by {upgradeToAndCall} to authorize the upgrade.
     *      Will revert if `msg.sender` has not the `UPGRADER_ROLE`.
     */
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
