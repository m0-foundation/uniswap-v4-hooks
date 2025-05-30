// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

/**
 * @title  ERC20 Like interface.
 * @author M0 Labs
 */
interface IERC20Like {
    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
}
