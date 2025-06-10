// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPredicateClient, PredicateMessage } from "../lib/predicate-contracts/src/interfaces/IPredicateClient.sol";
import { PredicateClient } from "../lib/predicate-contracts/src/mixins/PredicateClient.sol";

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
contract AllowlistHook is IAllowlistHook, BaseTickRangeHook, PredicateClient {
    using CurrencyLibrary for Currency;

    /* ============ Variables ============ */

    /// @inheritdoc IAllowlistHook
    bool public isLiquidityProvidersAllowlistEnabled;

    /// @inheritdoc IAllowlistHook
    bool public isPredicateCheckEnabled;

    /// @inheritdoc IAllowlistHook
    bool public isSwappersAllowlistEnabled;

    /**
     * @notice Mapping of Position Managers to their trusted status.
     * @dev    Only trusted Position Managers can invoke the beforeAddLiquidity hook.
     */
    mapping(address positionManager => bool isPositionManagerTrusted) internal _positionManagers;

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
     * @param  serviceManager_  Predicate's service manager contract address.
     * @param  policyID_        Predicate's policy ID.
     * @param  tickLowerBound_  The lower tick of the range to limit the liquidity provision and token swaps to.
     * @param  tickUpperBound_  The upper tick of the range to limit the liquidity provision and token swaps to.
     * @param  admin_           The address administrating the hook. Can grant and revoke roles.
     * @param  manager_         The address managing the hook.
     */
    constructor(
        address positionManager_,
        address swapRouter_,
        address poolManager_,
        address serviceManager_,
        string memory policyID_,
        int24 tickLowerBound_,
        int24 tickUpperBound_,
        address admin_,
        address manager_
    ) BaseTickRangeHook(poolManager_, tickLowerBound_, tickUpperBound_, admin_, manager_) {
        _initPredicateClient(serviceManager_, policyID_);
        emit PredicateManagerUpdated(serviceManager_);
        emit PolicyUpdated(policyID_);

        _setPositionManager(positionManager_, true);
        _setSwapRouter(swapRouter_, true);
        _setLiquidityProvidersAllowlist(true);
        _setPredicateCheck(true);
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
     * @param  sender_   The address of the sender initiating the swap (i.e. most commonly the Swap Router).
     * @param  key_      Underlying pool configuration information.
     * @param  params_   Swap parameters including direction and amount.
     * @param  hookData_ Encoded authorization message from Predicate.
     * @return A tuple containing the selector of this function, the delta for the swap, and the LP fee.
     */
    function _beforeSwap(
        address sender_,
        PoolKey calldata key_,
        IPoolManager.SwapParams calldata params_,
        bytes calldata hookData_
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        if (isSwappersAllowlistEnabled) {
            // NOTE: Revert early if the Swap Router is not trusted.
            if (!isSwapRouterTrusted(sender_)) {
                revert SwapRouterNotTrusted(sender_);
            }

            address caller_ = IBaseActionsRouterLike(sender_).msgSender();

            // NOTE: Revert early if the caller is not allowed to swap.
            if (!isSwapperAllowed(caller_)) {
                revert SwapperNotAllowed(caller_);
            }

            // NOTE: Bypass the Predicate check if disabled.
            if (!isPredicateCheckEnabled) {
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
            }

            // NOTE: Otherwise, perform the check.
            PredicateMessage memory predicateMessage_ = abi.decode(hookData_, (PredicateMessage));

            bytes memory encodeSigAndArgs_ = abi.encodeWithSignature(
                "_beforeSwap(address,address,address,uint24,int24,address,bool,int256)",
                caller_,
                key_.currency0,
                key_.currency1,
                key_.fee,
                key_.tickSpacing,
                address(key_.hooks),
                params_.zeroForOne,
                params_.amountSpecified
            );

            if (!_authorizeTransaction(predicateMessage_, encodeSigAndArgs_, caller_, 0)) {
                revert PredicateAuthorizationFailed(caller_);
            }
        }

        super._beforeSwap(key_);
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
     * @param  sender_   The address of the sender initiating the addition of liquidity (i.e. most commonly the Position Manager).
     * @param  params_   The parameters for modifying liquidity.
     * @return The selector of this function.
     */
    function _beforeAddLiquidity(
        address sender_,
        PoolKey calldata /* key_ */,
        IPoolManager.ModifyLiquidityParams calldata params_,
        bytes calldata /* hookData_ */
    ) internal override returns (bytes4) {
        if (isLiquidityProvidersAllowlistEnabled) {
            // NOTE: revert early if the Position Manager is not trusted.
            if (!isPositionManagerTrusted(sender_)) {
                revert PositionManagerNotTrusted(sender_);
            }

            address caller_ = IBaseActionsRouterLike(sender_).msgSender();

            // NOTE: Revert early if the caller is not allowed to add liquidity.
            if (!isLiquidityProviderAllowed(caller_)) {
                revert LiquidityProviderNotAllowed(caller_);
            }
        }

        super._beforeAddLiquidity(params_);
        return this.beforeAddLiquidity.selector;
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IAllowlistHook
    function setPredicateCheck(bool isEnabled_) external onlyRole(MANAGER_ROLE) {
        _setPredicateCheck(isEnabled_);
    }

    /// @inheritdoc IPredicateClient
    function setPredicateManager(address predicateManager_) external onlyRole(MANAGER_ROLE) {
        _setPredicateManager(predicateManager_);
        emit PredicateManagerUpdated(predicateManager_);
    }

    /// @inheritdoc IPredicateClient
    function setPolicy(string memory policyID_) external onlyRole(MANAGER_ROLE) {
        _setPolicy(policyID_);
        emit PolicyUpdated(policyID_);
    }

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

    /* ============ Public view functions ============ */

    /// @inheritdoc IAllowlistHook
    function isPositionManagerTrusted(address positionManager_) public view returns (bool) {
        return _positionManagers[positionManager_];
    }

    /// @inheritdoc IAllowlistHook
    function isSwapRouterTrusted(address swapRouter_) public view returns (bool) {
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
     * @notice Sets the Predicate check status.
     * @param  isEnabled_ Boolean indicating whether the Predicate check is enabled or not.
     */
    function _setPredicateCheck(bool isEnabled_) internal {
        if (isPredicateCheckEnabled == isEnabled_) return;

        isPredicateCheckEnabled = isEnabled_;
        emit PredicateCheckSet(isEnabled_);
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

        // NOTE: Return early if the Position Manager is already in the desired state.
        if (_positionManagers[positionManager_] == isAllowed_) return;

        _positionManagers[positionManager_] = isAllowed_;

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

        // NOTE: Return early if the Swap Router is already in the desired state.
        if (_swapRouters[swapRouter_] == isAllowed_) return;

        _swapRouters[swapRouter_] = isAllowed_;
        emit SwapRouterSet(swapRouter_, isAllowed_);
    }
}
