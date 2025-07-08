// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title  Base Tick Range Hook Interface
 * @author M0 Labs
 * @notice Base Hook allowing users to provide liquidity to a specific tick range only.
 */
interface IBaseTickRangeHook {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the tick range is set.
     * @param  tickLowerBound The lower tick of the range.
     * @param  tickUpperBound The upper tick of the range.
     */
    event TickRangeSet(int24 tickLowerBound, int24 tickUpperBound);

    /* ============ Custom Errors ============ */

    /**
     * @notice Emitted when the selected tick range to provide liquidity to is invalid.
     * @param  tickLower      The lower tick of the selected range.
     * @param  tickUpper      The upper tick of the selected range.
     * @param  tickLowerBound The lower tick of the range to limit liquidity provision and token swaps to.
     * @param  tickUpperBound The upper tick of the range to limit liquidity provision and token swaps to.
     */
    error InvalidTickRange(int24 tickLower, int24 tickUpper, int24 tickLowerBound, int24 tickUpperBound);

    /**
     * @notice Emitted when setting the tick range if the lower tick is greater than or equal to the upper tick.
     * @param  tickLowerBound The lower tick of the range.
     * @param  tickUpperBound The upper tick of the range.
     */
    error TicksOutOfOrder(int24 tickLowerBound, int24 tickUpperBound);

    /// @notice Emitted when the admin address in `initialize` is zero.
    error ZeroAdmin();

    /// @notice Emitted when the manager address in `initialize` is zero.
    error ZeroManager();

    /* ============ External / Interactive functions ============ */

    /**
     * @notice Sets the tick range to limit the liquidity provision and token swaps to.
     * @dev    MUST only be callable by the current manager.
     * @param  tickLowerBound The lower tick of the range.
     * @param  tickUpperBound The upper tick of the range.
     */
    function setTickRange(int24 tickLowerBound, int24 tickUpperBound) external;

    /* ============ External / View functions ============ */

    /// @notice The role that can manage the hook.
    function MANAGER_ROLE() external pure returns (bytes32);

    /// @notice Returns the lower tick of the range to limit the liquidity provision and token swaps to.
    function tickLowerBound() external view returns (int24);

    /// @notice Returns the upper tick of the range to limit the liquidity provision and token swaps to.
    function tickUpperBound() external view returns (int24);
}
