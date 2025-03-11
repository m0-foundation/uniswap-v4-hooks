// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  Base Actions Router Like interface.
 * @author M^0 Labs
 */
interface IBaseActionsRouterLike {
    /// @notice function that returns address considered executor of the actions
    /// @dev The other context functions, _msgData and _msgValue, are not supported by this contract
    /// In many contracts this will be the address that calls the initial entry point that calls `_executeActions`
    /// `msg.sender` shouldn't be used, as this will be the v4 pool manager contract that calls `unlockCallback`
    /// If using ReentrancyLock.sol, this function can return _getLocker()
    function msgSender() external returns (address);
}
