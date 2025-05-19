// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "../lib/v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";
import { BalanceDelta } from "../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { BaseTickRangeHook } from "./abstract/BaseTickRangeHook.sol";

import { IAllowlistHook } from "./interfaces/IAllowlistHook.sol";
import { IBaseActionsRouterLike } from "./interfaces/IBaseActionsRouterLike.sol";

/**
 * @title  Allowlist Hook
 * @author M0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range and allowlisted addresses.
 */
contract AllowlistHook is IAllowlistHook, BaseTickRangeHook {
    using CurrencyLibrary for Currency;

    /* ============ Variables ============ */

    /// @inheritdoc IAllowlistHook
    bool public isLiquidityProvidersAllowlistEnabled;

    /// @inheritdoc IAllowlistHook
    bool public isSwappersAllowlistEnabled;

    /**
     * @notice The PositionManagerStatus for a given positionManager contract. Only trusted position managers can
     *         invoke the beforeAddLiquidity and beforeRemoveLiquidity hooks. When a position manager is removed, it
     *         is designated as REDUCE_ONLY to allow users to remove their liquidity or migrate to a new position
     *         manager.
     */
    mapping(address positionManager => PositionManagerStatus positionManagerStatus) internal _positionManagers;

    /**
     * @notice Mapping of Swap Routers to their trusted status.
     * @dev    Only trusted Routers can invoke the beforeSwap hook.
     */
    mapping(address swapRouter => bool isSwapRouterTrusted) internal _swapRouters;

    /// @notice Mapping of Liquidity Providers to their allowed status.
    mapping(address liquidityProvider => bool isLiquidityProviderAllowed) internal _liquidityProvidersAllowlist;

    /// @notice Mapping of Swappers to their allowed status.
    mapping(address swapper => bool isSwapperAllowed) internal _swappersAllowlist;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the AllowlistHook contract.
     * @param  positionManager_ The initial Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param  swapRouter_      The initial Uniswap V4 Swap Router contract address allowed to swap.
     * @param  poolManager_     The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_  The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_  The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_           The address admnistrating the hook. Can grant and revoke roles.
     * @param  manager_         The address managing the hook.
     */
    constructor(
        address positionManager_,
        address swapRouter_,
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, admin_, manager_) {
        _setPositionManager(positionManager_, true);
        _setSwapRouter(swapRouter_, true);
        _setLiquidityProvidersAllowlist(true);
        _setSwappersAllowlist(true);
    }

    /* ============ Hook functions ============ */

    /**
     * @notice Returns a struct of permissions to signal which hook functions are to be implemented.
     * @dev    Used at deployment to validate the address correctly represents the expected permissions.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
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
     * @dev    Hook that is called before a swap is executed.
     * @dev    Will revert if the sender is not allowed to swap.
     * @param  sender_ The address of the sender initiating the swap (i.e. most commonly the Swap Router).
     * @return A tuple containing the selector of this function, the delta for the swap, and the LP fee.
     */
    function _beforeSwap(
        address sender_,
        PoolKey calldata /* poolKey */,
        IPoolManager.SwapParams calldata /* params */,
        bytes calldata /* hookData */
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        if (isSwappersAllowlistEnabled) {
            if (!_swapRouters[sender_]) {
                revert SwapRouterNotTrusted(sender_);
            }

            address caller_ = IBaseActionsRouterLike(sender_).msgSender();

            if (!isSwapperAllowed(caller_)) {
                revert SwapperNotAllowed(caller_);
            }
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @dev    Hook that is called after a swap is executed.
     * @param  key_ The key of the pool.
     * @return A tuple containing the selector of this function and the hook's delta in unspecified currency.
     */
    function _afterSwap(
        address /* sender */,
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
     * @param  sender_ The address of the sender adding liquidity (i.e. most commonly the Position Manager).
     * @param  params_ The parameters for modifying liquidity.
     * @return The selector of this function.
     */
    function _beforeAddLiquidity(
        address sender_,
        PoolKey calldata /* key */,
        IPoolManager.ModifyLiquidityParams calldata params_,
        bytes calldata /* hookData */
    ) internal override returns (bytes4) {
        if (isLiquidityProvidersAllowlistEnabled) {
            if (_positionManagers[sender_] != PositionManagerStatus.ALLOWED) {
                revert PositionManagerNotTrusted(sender_);
            }

            address caller_ = IBaseActionsRouterLike(sender_).msgSender();

            if (!isLiquidityProviderAllowed(caller_)) {
                revert LiquidityProviderNotAllowed(caller_);
            }
        }

        super._beforeAddLiquidity(params_);
        return this.beforeAddLiquidity.selector;
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IAllowlistHook
    function setLiquidityProvidersAllowlist(bool isEnabled_) external onlyRole(MANAGER_ROLE) {
        _setLiquidityProvidersAllowlist(isEnabled_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwappersAllowlist(bool isEnabled_) external onlyRole(MANAGER_ROLE) {
        _setSwappersAllowlist(isEnabled_);
    }

    /// @inheritdoc IAllowlistHook
    function setLiquidityProvider(address liquidityProvider_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setLiquidityProvider(liquidityProvider_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setLiquidityProviders(
        address[] calldata liquidityProviders_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (liquidityProviders_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < liquidityProviders_.length; ++i_) {
            _setLiquidityProvider(liquidityProviders_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setSwapper(address swapper_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setSwapper(swapper_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwappers(address[] calldata swappers_, bool[] calldata isAllowed_) external onlyRole(MANAGER_ROLE) {
        if (swappers_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < swappers_.length; ++i_) {
            _setSwapper(swappers_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setPositionManager(address positionManager_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setPositionManager(positionManager_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setPositionManagers(
        address[] calldata positionManagers_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (positionManagers_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < positionManagers_.length; ++i_) {
            _setPositionManager(positionManagers_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setSwapRouter(address swapRouter_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setSwapRouter(swapRouter_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwapRouters(
        address[] calldata swapRouters_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (swapRouters_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < swapRouters_.length; ++i_) {
            _setSwapRouter(swapRouters_[i_], isAllowed_[i_]);
        }
    }

    /* ============ External/Public view functions ============ */

    /// @inheritdoc IAllowlistHook
    function getPositionManagerStatus(address positionManager_) external view returns (PositionManagerStatus) {
        return _positionManagers[positionManager_];
    }

    /// @inheritdoc IAllowlistHook
    function isSwapRouterTrusted(address swapRouter_) external view returns (bool) {
        return _swapRouters[swapRouter_];
    }

    /// @inheritdoc IAllowlistHook
    function isLiquidityProviderAllowed(address liquidityProvider_) public view returns (bool) {
        return _liquidityProvidersAllowlist[liquidityProvider_];
    }

    /// @inheritdoc IAllowlistHook
    function isSwapperAllowed(address swapper_) public view returns (bool) {
        return _swappersAllowlist[swapper_];
    }

    /* ============ Internal Interactive functions ============ */

    /**
     * @notice Sets the liquidity providers allowlist status.
     * @param  isEnabled_ Boolean indicating whether the liquidity providers allowlist is enabled or not.
     */
    function _setLiquidityProvidersAllowlist(bool isEnabled_) internal {
        if (isLiquidityProvidersAllowlistEnabled == isEnabled_) return;

        isLiquidityProvidersAllowlistEnabled = isEnabled_;
        emit LiquidityProvidersAllowlistSet(isEnabled_);
    }

    /**
     * @notice Sets the swappers allowlist status.
     * @param  isEnabled_ Boolean indicating whether the swappers allowlist is enabled or not.
     */
    function _setSwappersAllowlist(bool isEnabled_) internal {
        if (isSwappersAllowlistEnabled == isEnabled_) return;

        isSwappersAllowlistEnabled = isEnabled_;
        emit SwappersAllowlistSet(isEnabled_);
    }

    /**
     * @dev   Sets the allowlist status of a liquidity provider.
     * @param liquidityProvider_ The address of the liquidity provider.
     * @param isAllowed_         Boolean indicating whether the liquidity provider is allowed or not.
     */
    function _setLiquidityProvider(address liquidityProvider_, bool isAllowed_) internal {
        if (liquidityProvider_ == address(0)) revert ZeroLiquidityProvider();
        if (_liquidityProvidersAllowlist[liquidityProvider_] == isAllowed_) return;

        _liquidityProvidersAllowlist[liquidityProvider_] = isAllowed_;
        emit LiquidityProviderSet(liquidityProvider_, isAllowed_);
    }

    /**
     * @dev   Sets the Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param positionManager_ The address of the Position Manager to set.
     * @param isAllowed_       Whether the Position Manager is allowed to modify liquidity or not.
     */
    function _setPositionManager(address positionManager_, bool isAllowed_) internal {
        if (positionManager_ == address(0)) revert ZeroPositionManager();

        // Return early if the position manager is already in the desired state.
        if ((_positionManagers[positionManager_] == PositionManagerStatus.ALLOWED) ? isAllowed_ : !isAllowed_) {
            return;
        }

        _positionManagers[positionManager_] = isAllowed_
            ? PositionManagerStatus.ALLOWED
            : PositionManagerStatus.REDUCE_ONLY;

        emit PositionManagerSet(positionManager_, isAllowed_);
    }

    /**
     * @dev   Sets the allowlist status of a swapper.
     * @param swapper_   The address of the swapper.
     * @param isAllowed_ Boolean indicating whether the swapper is allowed or not.
     */
    function _setSwapper(address swapper_, bool isAllowed_) internal {
        if (swapper_ == address(0)) revert ZeroSwapper();
        if (_swappersAllowlist[swapper_] == isAllowed_) return;

        _swappersAllowlist[swapper_] = isAllowed_;
        emit SwapperSet(swapper_, isAllowed_);
    }

    /**
     * @dev   Sets the status of the Swap Router contract address.
     * @param swapRouter_ The Swap Router address.
     * @param isAllowed_  Whether the Swap Router is allowed to swap or not.
     */
    function _setSwapRouter(address swapRouter_, bool isAllowed_) internal {
        if (swapRouter_ == address(0)) revert ZeroSwapRouter();
        if (_swapRouters[swapRouter_] == isAllowed_) return;

        _swapRouters[swapRouter_] = isAllowed_;
        emit SwapRouterSet(swapRouter_, isAllowed_);
    }
}
