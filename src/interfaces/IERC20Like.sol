// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  ERC20 Like interface.
 * @author M^0 Labs
 */
interface IERC20Like {
    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
}
