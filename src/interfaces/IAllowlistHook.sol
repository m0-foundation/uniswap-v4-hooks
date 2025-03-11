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
     * @notice Emitted when the allowlist status of a liquidity provider is set.
     * @param  liquidityProvider The address of the liquidity provider.
     * @param  isAllowed         Boolean indicating whether the liquidity provider is allowed or not. */
    event LiquidityProviderStatusSet(address indexed liquidityProvider, bool isAllowed);

    /**
     * @notice Emitted when the allowlist status of a swapper is set. @param  swapper   The address of the swapper.
     * @param  isAllowed Boolean indicating whether the swapper is allowed or not.
     */
    event SwapperStatusSet(address indexed swapper, bool isAllowed);

    /**
     * @notice Emitted when the Uniswap V4 Position Manager address is set.
     * @param  positionManager The address of the Uniswap V4 Position Manager contract.
     */
    event PositionManagerSet(address indexed positionManager);

    /**
     * @notice Emitted when the Uniswap V4 Router address is set.
     * @param  swapRouter The address of the Uniswap V4 Router contract.
     */
    event SwapRouterSet(address indexed swapRouter);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the lengths of input arrays do not match.
    error ArrayLengthMismatch();

    /**
     * @notice Error emitted in beforeAddLiquidity if the caller is not allowed to provide liquidity.
     * @param  liquidityProvider The address of the liquidity provider that is not allowed.
     */
    error LiquidityProviderNotAllowed(address liquidityProvider);

    /**
     * @notice Error emitted in beforeSwap if the Uniswap V4 Position Manager address is not allowed.
     * @param  positionManager The address of the Uniswap V4 Position Manager contract.
     */
    error PositionManagerNotAllowed(address positionManager);

    /**
     * @notice Error emitted in beforeSwap if the caller is not allowed to swap.
     * @param  swapper The address of the swapper that is not allowed.
     */
    error SwapperNotAllowed(address swapper);

    /**
     * @notice Error emitted in beforeSwap if the Uniswap V4 Router address is not allowed.
     * @param  swapRouter The address of the Uniswap V4 Router contract.
     */
    error SwapRouterNotAllowed(address swapRouter);

    /// @notice Error emitted when a swapper status is set for address zero.
    error ZeroSwapper();

    /// @notice Error emitted when a liquidity provider status is set for address zero.
    error ZeroLiquidityProvider();

    /// @notice Error emitted when the Uniswap V4 Position Manager address is set to the zero address.
    error ZeroPositionManager();

    /// @notice Error emitted when the Uniswap V4 Router address is set to the zero address.
    error ZeroSwapRouter();

    /* ============ External Interactive functions ============ */

    /**
     * @notice Sets the allowlist status of a liquidity provider.
     * @dev    MUST only be callable by the current owner.
     * @param  liquidityProvider The address of the liquidity provider.
     * @param  isAllowed         Boolean indicating whether the liquidity provider is allowed or not.
     */
    function setLiquidityProviderStatus(address liquidityProvider, bool isAllowed) external;

    /**
     * @notice Sets the allowlist status for multiple liquidity providers.
     * @dev    MUST only be callable by the current owner.
     * @param  liquidityProviders The array of liquidity provider addresses.
     * @param  isAllowed          The array of boolean values indicating the allowed status for each liquidity provider.
     */
    function setLiquidityProviderStatuses(address[] calldata liquidityProviders, bool[] calldata isAllowed) external;

    /**
     * @notice Sets the allowlist status of a swapper.
     * @dev    MUST only be callable by the current owner.
     * @param  swapper   The address of the swapper.
     * @param  isAllowed Boolean indicating whether the swapper is allowed or not.
     */
    function setSwapperStatus(address swapper, bool isAllowed) external;

    /**
     * @notice Sets the allowlist status for multiple swappers.
     * @dev    MUST only be callable by the current owner.
     * @param  swappers  The array of swapper addresses.
     * @param  isAllowed The array of boolean values indicating the allowed status for each swapper.
     */
    function setSwapperStatuses(address[] calldata swappers, bool[] calldata isAllowed) external;

    /**
     * @notice Sets the Uniswap V4 Position Manager contract address allowed to modify liquidity.
     * @dev    MUST only be callable by the current owner.
     * @param  positionManager_ The Uniswap V4 Position Manager contract address.
     */
    function setPositionManager(address positionManager_) external;

    /**
     * @notice Sets the Uniswap V4 Router contract address allowed to swap.
     * @dev    MUST only be callable by the current owner.
     * @param  swapRouter_ The Uniswap V4 Router contract address.
     */
    function setSwapRouter(address swapRouter_) external;

    /* ============ External/Public view functions ============ */

    /**
     * @notice Checks if a swapper is allowed.
     * @param  swapper The address of the swapper.
     * @return True if the swapper is allowed, false otherwise.
     */
    function isSwapperAllowed(address swapper) external view returns (bool);

    /**
     * @notice Checks if a liquidity provider is allowed.
     * @param  liquidityProvider The address of the liquidity provider.
     * @return True if the liquidity provider is allowed, false otherwise.
     */
    function isLiquidityProviderAllowed(address liquidityProvider) external view returns (bool);

    /// @notice The address of the Uniswap V4 Position Manager contract allowed to modify liquidity.
    function positionManager() external view returns (address);

    /// @notice The address of the Uniswap V4 Router contract allowed to swap.
    function swapRouter() external view returns (address);
}
