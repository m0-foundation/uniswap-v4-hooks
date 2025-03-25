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
     * @notice Sets the status of the Uniswap V4 Position Manager contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  positionManager The Uniswap V4 Position Manager address.
     * @param  isAllowed       Boolean indicating whether the Position Manager is allowed to modify liquidity or not.
     */
    function setPositionManagerStatus(address positionManager, bool isAllowed) external;

    /**
     * @notice Sets the status of multiple Uniswap V4 Position Manager contract addresses.
     * @dev    MUST only be callable by the current owner.
     * @param  positionManagers The array of Position Manager addresses.
     * @param  isAllowed        The array of boolean values indicating the allowed status for each Position Manager.
     */
    function setPositionManagerStatuses(address[] calldata positionManagers, bool[] calldata isAllowed) external;

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
     * @notice Sets the status of the Swap Router contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  swapRouter The Swap Router address.
     * @param  isAllowed  Boolean indicating whether the Swap Router is allowed to swap or not.
     */
    function setSwapRouterStatus(address swapRouter, bool isAllowed) external;

    /**
     * @notice Sets the status of the Swap Router contract address.
     * @dev    MUST only be callable by the current owner.
     * @param  swapRouters The array of Swap Router addresses.
     * @param  isAllowed   The array of boolean values indicating the allowed status for each Swap Router.
     */
    function setSwapRouterStatuses(address[] calldata swapRouters, bool[] calldata isAllowed) external;

    /* ============ External/Public view functions ============ */

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
}
