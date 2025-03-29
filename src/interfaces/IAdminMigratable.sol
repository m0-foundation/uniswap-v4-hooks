// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

/**
 * @title  Interface extending IMigratable with a priviliged migrate function.
 * @author M^0 Labs
 */
interface IAdminMigratable is IMigratable {
    /* ============ Custom Errors ============ */

    /// @notice Emitted when the non-governance migrate function is called by an account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted when the migration admin address is zero.
    error ZeroMigrationAdmin();

    /* ============ External Interactive functions ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @dev    MUST only be callable by the migration admin.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ Internal View/Pure Functions ============ */

    /// @notice Address of the migration admin that can perform migrations.
    function migrationAdmin() external view returns (address);
}
