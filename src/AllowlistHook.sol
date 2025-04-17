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
 * @title  Allowlist Hook Storage Layout
 * @author M^0 Labs
 * @notice Abstract contract defining the storage layout of the AllowlistHook contract.
 */

abstract contract AllowlistHookStorageLayout is IAllowlistHook {
    /// @custom:storage-location erc7201:M0.storage.AllowlistHookV0
    struct AllowlistHookStorage {
        bool isLiquidityProvidersAllowlistEnabled;
        bool isSwappersAllowlistEnabled;
        mapping(address positionManager => PositionManagerStatus positionManagerStatus) positionManagers;
        mapping(address swapRouter => bool isSwapRouterTrusted) swapRouters;
        mapping(address liquidityProvider => bool isLiquidityProviderAllowed) liquidityProvidersAllowlist;
        mapping(address swapper => bool isSwapperAllowed) swappersAllowlist;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.AllowlistHookV0")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _ALLOWLIST_HOOK_V0_LOCATION =
        0x012690e2bc2d6709c0c24ad5057b6f4444803285aec60d9a2256a7c0fad1c800;

    function _getAllowlistHookStorage() internal pure returns (AllowlistHookStorage storage $) {
        assembly {
            $.slot := _ALLOWLIST_HOOK_V0_LOCATION
        }
    }
}

/**
 * @title  Allowlist Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range and allowlisted addresses.
 */
contract AllowlistHook is BaseTickRangeHook, AllowlistHookStorageLayout {
    using CurrencyLibrary for Currency;

    /* ============ Initializer ============ */

    /**
     * @notice Initialize the AllowlistHook contract.
     * @param  positionManager_ The initial Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param  swapRouter_      The initial Uniswap V4 Swap Router contract address allowed to swap.
     * @param  poolManager_     The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_  The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_  The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_           The address admnistrating the hook. Can grant and revoke roles.
     * @param  manager_         The address managing the hook.
     * @param  upgrader_        The address allowed to upgrade the implementation.
     */
    function initialize(
        address positionManager_,
        address swapRouter_,
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_,
        address upgrader_
    ) public initializer {
        __BaseTickRangeHookUpgradeable_init(
            poolManager_,
            tickLowerBound_,
            tickUpperBound_,
            admin_,
            manager_,
            upgrader_
        );

        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        _setPositionManager($, positionManager_, true);
        _setSwapRouter($, swapRouter_, true);
        _setLiquidityProvidersAllowlist($, true);
        _setSwappersAllowlist($, true);
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
        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        if ($.isSwappersAllowlistEnabled) {
            if (!$.swapRouters[sender_]) {
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
        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        if ($.isLiquidityProvidersAllowlistEnabled) {
            if ($.positionManagers[sender_] != PositionManagerStatus.ALLOWED) {
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
        _setLiquidityProvidersAllowlist(_getAllowlistHookStorage(), isEnabled_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwappersAllowlist(bool isEnabled_) external onlyRole(MANAGER_ROLE) {
        _setSwappersAllowlist(_getAllowlistHookStorage(), isEnabled_);
    }

    /// @inheritdoc IAllowlistHook
    function setLiquidityProvider(address liquidityProvider_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setLiquidityProvider(_getAllowlistHookStorage(), liquidityProvider_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setLiquidityProviders(
        address[] calldata liquidityProviders_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (liquidityProviders_.length != isAllowed_.length) revert ArrayLengthMismatch();

        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        for (uint256 i_; i_ < liquidityProviders_.length; ++i_) {
            _setLiquidityProvider($, liquidityProviders_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setSwapper(address swapper_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setSwapper(_getAllowlistHookStorage(), swapper_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwappers(address[] calldata swappers_, bool[] calldata isAllowed_) external onlyRole(MANAGER_ROLE) {
        if (swappers_.length != isAllowed_.length) revert ArrayLengthMismatch();

        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        for (uint256 i_; i_ < swappers_.length; ++i_) {
            _setSwapper($, swappers_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setPositionManager(address positionManager_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setPositionManager(_getAllowlistHookStorage(), positionManager_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setPositionManagers(
        address[] calldata positionManagers_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (positionManagers_.length != isAllowed_.length) revert ArrayLengthMismatch();

        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        for (uint256 i_; i_ < positionManagers_.length; ++i_) {
            _setPositionManager($, positionManagers_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setSwapRouter(address swapRouter_, bool isAllowed_) external onlyRole(MANAGER_ROLE) {
        _setSwapRouter(_getAllowlistHookStorage(), swapRouter_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwapRouters(
        address[] calldata swapRouters_,
        bool[] calldata isAllowed_
    ) external onlyRole(MANAGER_ROLE) {
        if (swapRouters_.length != isAllowed_.length) revert ArrayLengthMismatch();

        AllowlistHookStorage storage $ = _getAllowlistHookStorage();

        for (uint256 i_; i_ < swapRouters_.length; ++i_) {
            _setSwapRouter($, swapRouters_[i_], isAllowed_[i_]);
        }
    }

    /* ============ External/Public view functions ============ */

    /// @inheritdoc IAllowlistHook
    function isLiquidityProvidersAllowlistEnabled() external view returns (bool) {
        return _getAllowlistHookStorage().isLiquidityProvidersAllowlistEnabled;
    }

    /// @inheritdoc IAllowlistHook
    function isSwappersAllowlistEnabled() external view returns (bool) {
        return _getAllowlistHookStorage().isSwappersAllowlistEnabled;
    }

    /// @inheritdoc IAllowlistHook
    function getPositionManagerStatus(address positionManager_) external view returns (PositionManagerStatus) {
        return _getAllowlistHookStorage().positionManagers[positionManager_];
    }

    /// @inheritdoc IAllowlistHook
    function isSwapRouterTrusted(address swapRouter_) external view returns (bool) {
        return _getAllowlistHookStorage().swapRouters[swapRouter_];
    }

    /// @inheritdoc IAllowlistHook
    function isLiquidityProviderAllowed(address liquidityProvider_) public view returns (bool) {
        return _getAllowlistHookStorage().liquidityProvidersAllowlist[liquidityProvider_];
    }

    /// @inheritdoc IAllowlistHook
    function isSwapperAllowed(address swapper_) public view returns (bool) {
        return _getAllowlistHookStorage().swappersAllowlist[swapper_];
    }

    /* ============ Internal Interactive functions ============ */

    /**
     * @notice Sets the liquidity providers allowlist status.
     * @param  $          The AllowlistHookStorage struct.
     * @param  isEnabled_ Boolean indicating whether the liquidity providers allowlist is enabled or not.
     */
    function _setLiquidityProvidersAllowlist(AllowlistHookStorage storage $, bool isEnabled_) internal {
        if ($.isLiquidityProvidersAllowlistEnabled == isEnabled_) return;

        $.isLiquidityProvidersAllowlistEnabled = isEnabled_;
        emit LiquidityProvidersAllowlistSet(isEnabled_);
    }

    /**
     * @notice Sets the swappers allowlist status.
     * @param  $          The AllowlistHookStorage struct.
     * @param  isEnabled_ Boolean indicating whether the swappers allowlist is enabled or not.
     */
    function _setSwappersAllowlist(AllowlistHookStorage storage $, bool isEnabled_) internal {
        if ($.isSwappersAllowlistEnabled == isEnabled_) return;

        $.isSwappersAllowlistEnabled = isEnabled_;
        emit SwappersAllowlistSet(isEnabled_);
    }

    /**
     * @dev   Sets the allowlist status of a liquidity provider.
     * @param $                  The AllowlistHookStorage struct.
     * @param liquidityProvider_ The address of the liquidity provider.
     * @param isAllowed_         Boolean indicating whether the liquidity provider is allowed or not.
     */
    function _setLiquidityProvider(
        AllowlistHookStorage storage $,
        address liquidityProvider_,
        bool isAllowed_
    ) internal {
        if (liquidityProvider_ == address(0)) revert ZeroLiquidityProvider();
        if ($.liquidityProvidersAllowlist[liquidityProvider_] == isAllowed_) return;

        $.liquidityProvidersAllowlist[liquidityProvider_] = isAllowed_;
        emit LiquidityProviderSet(liquidityProvider_, isAllowed_);
    }

    /**
     * @dev   Sets the Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param $                The AllowlistHookStorage struct.
     * @param positionManager_ The address of the Position Manager to set.
     * @param isAllowed_       Whether the Position Manager is allowed to modify liquidity or not.
     */
    function _setPositionManager(AllowlistHookStorage storage $, address positionManager_, bool isAllowed_) internal {
        if (positionManager_ == address(0)) revert ZeroPositionManager();

        // Return early if the position manager is already in the desired state.
        if (($.positionManagers[positionManager_] == PositionManagerStatus.ALLOWED) ? isAllowed_ : !isAllowed_) {
            return;
        }

        $.positionManagers[positionManager_] = isAllowed_
            ? PositionManagerStatus.ALLOWED
            : PositionManagerStatus.REDUCE_ONLY;

        emit PositionManagerSet(positionManager_, isAllowed_);
    }

    /**
     * @dev   Sets the allowlist status of a swapper.
     * @param $          The AllowlistHookStorage struct.
     * @param swapper_   The address of the swapper.
     * @param isAllowed_ Boolean indicating whether the swapper is allowed or not.
     */
    function _setSwapper(AllowlistHookStorage storage $, address swapper_, bool isAllowed_) internal {
        if (swapper_ == address(0)) revert ZeroSwapper();
        if ($.swappersAllowlist[swapper_] == isAllowed_) return;

        $.swappersAllowlist[swapper_] = isAllowed_;
        emit SwapperSet(swapper_, isAllowed_);
    }

    /**
     * @dev   Sets the status of the Swap Router contract address.
     * @param $           The AllowlistHookStorage struct.
     * @param swapRouter_ The Swap Router address.
     * @param isAllowed_  Whether the Swap Router is allowed to swap or not.
     */
    function _setSwapRouter(AllowlistHookStorage storage $, address swapRouter_, bool isAllowed_) internal {
        if (swapRouter_ == address(0)) revert ZeroSwapRouter();
        if ($.swapRouters[swapRouter_] == isAllowed_) return;

        $.swapRouters[swapRouter_] = isAllowed_;
        emit SwapRouterSet(swapRouter_, isAllowed_);
    }
}
