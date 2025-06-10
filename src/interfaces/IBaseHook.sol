// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

/**
 * @title  Base Hook interface.
 * @author M0 Labs
 */
interface IBaseHook {
    /* ============ Custom Errors ============ */

    /// @notice Thrown when the hook is called but not implemented.
    error HookNotImplemented();

    /// @notice Thrown when the caller is not the PoolManager.
    error NotPoolManager();

    /// @notice Thrown if the PoolManager is address zero.
    error ZeroPoolManager();

    /* ============ External/Public view functions ============ */

    ///@notice Returns the Uniswap V4 PoolManager contract.
    function poolManager() external view returns (IPoolManager);
}
