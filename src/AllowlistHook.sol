// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";

import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "../lib/v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";
import { BalanceDelta } from "../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { PoolKey } from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { BaseTickRangeHook } from "./abstract/BaseTickRangeHook.sol";

import { IAllowlistHook } from "./interfaces/IAllowlistHook.sol";
import { IBaseActionsRouterLike } from "./interfaces/IBaseActionsRouterLike.sol";

/**
 * @title  Allowlist Hook
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range and allowlisted addresses.
 */
contract AllowlistHook is BaseTickRangeHook, IAllowlistHook {
    /* ============ Variables ============ */

    /// @inheritdoc IAllowlistHook
    address public positionManager;

    /// @inheritdoc IAllowlistHook
    address public swapRouter;

    /// @notice Mapping of liquidity providers to their allowed status.
    mapping(address liquidityProvider => bool isLiquidityProviderAllowed) internal _liquidityProvidersAllowlist;

    /// @notice Mapping of swappers to their allowed status.
    mapping(address swapper => bool isSwapperAllowed) internal _swappersAllowlist;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the AllowlistHook contract.
     * @param  positionManager_ The Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param  swapRouter_      The Uniswap V4 Router contract address allowed to swap.
     * @param  poolManager_     The Uniswap V4 Pool Manager contract address.
     * @param  tickLowerBound_  The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_  The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  owner_           The owner of the contract.
     */
    constructor(
        address positionManager_,
        address swapRouter_,
        address poolManager_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address owner_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, owner_) {
        _setPositionManager(positionManager_);
        _setSwapRouter(swapRouter_);
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
                afterInitialize: true,
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
        if (sender_ != swapRouter) {
            revert SwapRouterNotAllowed(sender_);
        }

        address caller_ = IBaseActionsRouterLike(sender_).msgSender();

        if (!isSwapperAllowed(caller_)) {
            revert SwapperNotAllowed(caller_);
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
        if (sender_ != positionManager) {
            revert PositionManagerNotAllowed(sender_);
        }

        address caller_ = IBaseActionsRouterLike(sender_).msgSender();

        if (!isLiquidityProviderAllowed(caller_)) {
            revert LiquidityProviderNotAllowed(caller_);
        }

        super._beforeAddLiquidity(params_);
        return this.beforeAddLiquidity.selector;
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IAllowlistHook
    function setLiquidityProviderStatus(address liquidityProvider_, bool isAllowed_) external onlyOwner {
        _setLiquidityProviderStatus(liquidityProvider_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setLiquidityProviderStatuses(
        address[] calldata liquidityProviders_,
        bool[] calldata isAllowed_
    ) external onlyOwner {
        if (liquidityProviders_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < liquidityProviders_.length; ++i_) {
            _setLiquidityProviderStatus(liquidityProviders_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setSwapperStatus(address swapper_, bool isAllowed_) external onlyOwner {
        _setSwapperStatus(swapper_, isAllowed_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwapperStatuses(address[] calldata swappers_, bool[] calldata isAllowed_) external onlyOwner {
        if (swappers_.length != isAllowed_.length) revert ArrayLengthMismatch();

        for (uint256 i_; i_ < swappers_.length; ++i_) {
            _setSwapperStatus(swappers_[i_], isAllowed_[i_]);
        }
    }

    /// @inheritdoc IAllowlistHook
    function setPositionManager(address positionManager_) external onlyOwner {
        _setPositionManager(positionManager_);
    }

    /// @inheritdoc IAllowlistHook
    function setSwapRouter(address swapRouter_) external onlyOwner {
        _setSwapRouter(swapRouter_);
    }

    /* ============ External/Public view functions ============ */

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
     * @dev   Sets the allowlist status of a liquidity provider.
     * @param liquidityProvider_ The address of the liquidity provider.
     * @param isAllowed_         Boolean indicating whether the liquidity provider is allowed or not.
     */
    function _setLiquidityProviderStatus(address liquidityProvider_, bool isAllowed_) internal {
        if (liquidityProvider_ == address(0)) revert ZeroLiquidityProvider();

        _liquidityProvidersAllowlist[liquidityProvider_] = isAllowed_;
        emit LiquidityProviderStatusSet(liquidityProvider_, isAllowed_);
    }

    /**
     * @dev   Sets the allowlist status of a swapper.
     * @param swapper_   The address of the swapper.
     * @param isAllowed_ Boolean indicating whether the swapper is allowed or not.
     */
    function _setSwapperStatus(address swapper_, bool isAllowed_) internal {
        if (swapper_ == address(0)) revert ZeroSwapper();

        _swappersAllowlist[swapper_] = isAllowed_;
        emit SwapperStatusSet(swapper_, isAllowed_);
    }

    /**
     * @dev   Sets the Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @param positionManager_ The Uniswap V4 Position Manager contract address.
     */
    function _setPositionManager(address positionManager_) internal {
        if ((positionManager = positionManager_) == address(0)) revert ZeroPositionManager();
        emit PositionManagerSet(positionManager_);
    }

    /**
     * @dev   Sets the Uniswap V4 Router contract address allowed to swap.
     * @param swapRouter_ The Uniswap V4 Router contract address.
     */
    function _setSwapRouter(address swapRouter_) internal {
        if ((swapRouter = swapRouter_) == address(0)) revert ZeroSwapRouter();
        emit SwapRouterSet(swapRouter_);
    }
}
