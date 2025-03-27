// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  Allowlist Hook Interface
 * @author M^0 Labs
 * @notice Hook restricting liquidity provision and token swaps to a specific tick range and allowlisted addresses.
 */
interface IAllowlistHook {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the liquidity providers allowlist status is set.
     * @param  isEnabled Boolean indicating whether the liquidity providers allowlist is enabled or not.
     */
    event LiquidityProvidersAllowlistSet(bool isEnabled);

    /**
     * @notice Emitted when the swappers allowlist status is set.
     * @param  isEnabled Boolean indicating whether the swappers allowlist is enabled or not.
     */
    event SwappersAllowlistSet(bool isEnabled);

    /**
     * @notice Emitted when the allowlist status of a liquidity provider is set.
     * @param  liquidityProvider The address of the liquidity provider.
     * @param  isAllowed         Boolean indicating whether the liquidity provider is allowed or not.
     */
    event LiquidityProviderSet(address indexed liquidityProvider, bool isAllowed);

    /**
     * @notice Emitted when the allowlist status of a swapper is set.
     * @param  swapper   The address of the swapper.
     * @param  isAllowed Boolean indicating whether the swapper is allowed or not.
     */
    event SwapperSet(address indexed swapper, bool isAllowed);

    /**
     * @notice Emitted when the status of the Uniswap V4 Position Manager contract address is set.
     * @param  positionManager The address of the Uniswap V4 Position Manager.
     * @param  isAllowed       Boolean indicating whether the Position Manager is allowed to modify liquidity or not.
     */
    event PositionManagerSet(address indexed positionManager, bool isAllowed);

    /**
     * @notice Emitted when the status of the Swap Router contract address is set.
     * @param  swapRouter The address of the Swap Router.
     * @param  isAllowed  Boolean indicating whether the Swap Router is allowed to swap or not.
     */
    event SwapRouterSet(address indexed swapRouter, bool isAllowed);

    /// @notice Emitted when the total amount swapped is reset.
    event TotalSwapReset();

    /**
     * @notice Emitted when the swap cap is set.
     * @param  swapCap The new swap cap amount.
     */
    event SwapCapSet(uint256 swapCap);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the lengths of input arrays do not match.
    error ArrayLengthMismatch();

    /**
     * @notice Error emitted in beforeAddLiquidity if the caller is not allowed to provide liquidity.
     * @param  liquidityProvider The address of the liquidity provider that is not allowed.
     */
    error LiquidityProviderNotAllowed(address liquidityProvider);

    /**
     * @notice Error emitted in beforeSwap if the Uniswap V4 Position Manager address is not trusted.
     * @param  positionManager The address of the Uniswap V4 Position Manager contract.
     */
    error PositionManagerNotTrusted(address positionManager);

    /**
     * @notice Error emitted in beforeSwap if the caller is not allowed to swap.
     * @param  swapper The address of the swapper that is not allowed.
     */
    error SwapperNotAllowed(address swapper);

    /**
     * @notice Error emitted in beforeSwap if the Swap Router address is not trusted.
     * @param  swapRouter The address of the Swap Router contract.
     */
    error SwapRouterNotTrusted(address swapRouter);

    /**
     * @notice Error emitted in beforeSwap if the swap cap is reached.
     * @param  totalSwap The total amount that would have been swapped across token0 and token1 if the cap was not reached.
     * @param  swapCap   The maximum amount that can be swapped across token0 and token1.
     */
    error SwapCapExceeded(uint256 totalSwap, uint256 swapCap);

    /// @notice Error emitted when a swapper status is set for address zero.
    error ZeroSwapper();

    /// @notice Error emitted when a liquidity provider status is set for address zero.
    error ZeroLiquidityProvider();

    /// @notice Error emitted when the Uniswap V4 Position Manager address is set to the zero address.
    error ZeroPositionManager();

    /// @notice Error emitted when the Uniswap V4 Router address is set to the zero address.
    error ZeroSwapRouter();

    /* ============ Enums ============ */

    /// @notice The status for a Position Manager contract.
    enum PositionManagerStatus {
        /// @dev This contract cannot be used to manage positions (the default value).
        FORBIDDEN,
        /// @dev This contract can be used for all liquidity operations.
        ALLOWED,
        /// @dev This contract can only be used to reduce or close a liquidity position.
        REDUCE_ONLY
    }

    /* ============ External Interactive functions ============ */

    /**
     * @notice Sets the liquidity providers allowlist status.
     * @dev    MUST only be callable by the current owner.
     * @param  isEnabled Boolean indicating whether the liquidity providers allowlist is enabled or not.
     */
    function setLiquidityProvidersAllowlist(bool isEnabled) external;

    /**
     * @notice Sets the swappers allowlist status.
     * @dev    MUST only be callable by the current owner.
     * @param  isEnabled Boolean indicating whether the swappers allowlist is enabled or not.
     */
    function setSwappersAllowlist(bool isEnabled) external;

    /**
     * @notice Sets the allowlist status of a liquidity provider.
     * @dev    MUST only be callable by the current owner.
     * @param  liquidityProvider The address of the liquidity provider.
     * @param  isAllowed         Boolean indicating whether the liquidity provider is allowed or not.
     */
    function setLiquidityProvider(address liquidityProvider, bool isAllowed) external;

    /**
     * @notice Sets the allowlist status for multiple liquidity providers.
     * @dev    MUST only be callable by the current owner.
     * @param  liquidityProviders The array of liquidity provider addresses.
     * @param  isAllowed          The array of boolean values indicating the allowed status for each liquidity provider.
     */
    function setLiquidityProviders(address[] calldata liquidityProviders, bool[] calldata isAllowed) external;

    /**
     * @notice Sets the status of the Uniswap V4 Position Manager contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  positionManager The Uniswap V4 Position Manager address.
     * @param  isAllowed       Boolean indicating whether the Position Manager is allowed to modify liquidity or not.
     */
    function setPositionManager(address positionManager, bool isAllowed) external;

    /**
     * @notice Sets the status of multiple Uniswap V4 Position Manager contract addresses.
     * @dev    MUST only be callable by the current owner.
     * @param  positionManagers The array of Position Manager addresses.
     * @param  isAllowed        The array of boolean values indicating the allowed status for each Position Manager.
     */
    function setPositionManagers(address[] calldata positionManagers, bool[] calldata isAllowed) external;

    /**
     * @notice Sets the allowlist status of a swapper.
     * @dev    MUST only be callable by the current owner.
     * @param  swapper   The address of the swapper.
     * @param  isAllowed Boolean indicating whether the swapper is allowed or not.
     */
    function setSwapper(address swapper, bool isAllowed) external;

    /**
     * @notice Sets the allowlist status for multiple swappers.
     * @dev    MUST only be callable by the current owner.
     * @param  swappers  The array of swapper addresses.
     * @param  isAllowed The array of boolean values indicating the allowed status for each swapper.
     */
    function setSwappers(address[] calldata swappers, bool[] calldata isAllowed) external;

    /**
     * @notice Sets the status of the Swap Router contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  swapRouter The Swap Router address.
     * @param  isAllowed  Boolean indicating whether the Swap Router is allowed to swap or not.
     */
    function setSwapRouter(address swapRouter, bool isAllowed) external;

    /**
     * @notice Sets the status of the Swap Router contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  swapRouters The array of Swap Router addresses.
     * @param  isAllowed   The array of boolean values indicating the allowed status for each Swap Router.
     */
    function setSwapRouters(address[] calldata swapRouters, bool[] calldata isAllowed) external;

    /**
     * @notice Resets the total amount swapped across token0 and token1.
     * @dev    MUST only be callable by the current owner.
     */
    function resetTotalSwap() external;

    /**
     * @notice Sets the swap cap amount.
     * @dev    MUST only be callable by the current owner.
     * @dev    Caller MUST ensure that the amount set follows the decimal precision of the token with the higher decimals.
     * @dev    MUST reset the totapSwap amount if swapCap is lower than the totalSwap amount.
     * @param  swapCap_ The new swap cap amount.
     */
    function setSwapCap(uint256 swapCap_) external;

    /* ============ External/Public view functions ============ */

    /**
     * @notice Whether the liquidity providers allowlist is enabled or not.
     * @dev    Enabled by default at deployment.
     */
    function isLiquidityProvidersAllowlistEnabled() external view returns (bool);

    /**
     * @notice Whether the swappers allowlist is enabled or not.
     * @dev    Enabled by default at deployment.
     */
    function isSwappersAllowlistEnabled() external view returns (bool);

    /**
     * @notice Gets the status of a given Position Manager.
     * @param  positionManager The address of the Position Manager.
     * @return The status of the Position Manager.
     */
    function getPositionManagerStatus(address positionManager) external view returns (PositionManagerStatus);

    /**
     * @notice Checks if a liquidity provider is allowed.
     * @param  liquidityProvider The address of the liquidity provider.
     * @return True if the liquidity provider is allowed, false otherwise.
     */
    function isLiquidityProviderAllowed(address liquidityProvider) external view returns (bool);

    /**
     * @notice Checks if a swapper is allowed.
     * @param  swapper The address of the swapper.
     * @return True if the swapper is allowed, false otherwise.
     */
    function isSwapperAllowed(address swapper) external view returns (bool);

    /**
     * @notice Checks if a Swap Router is trusted.
     * @param  swapRouter The address of the Swap Router.
     * @return True if the Swap Router is trusted, false otherwise.
     */
    function isSwapRouterTrusted(address swapRouter) external view returns (bool);

    /**
     * @notice Gets the maximum amount of token0 or token1 that can currently be swapped for a given amount.
     * @param  amount The amount of token0 or token1 to get the maximum swappable amount for.
     * @return The maximum swappable amount.
     */
    function getSwappableAmount(uint256 amount) external view returns (uint256);

    /// @notice The maximum amount, across token0 and token1, that can be swapped before swapping is restricted.
    function swapCap() external view returns (uint256);

    /// @notice The total amount, across token0 and token1, that has been swapped since the last reset.
    function totalSwap() external view returns (uint256);

    /// @notice The number of decimals to scale swapCap and totalSwap amounts to.
    function referenceDecimals() external view returns (uint8);
}
