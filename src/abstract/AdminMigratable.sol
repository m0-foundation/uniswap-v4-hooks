// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import { Migratable } from "../../lib/common/src/Migratable.sol";

import { IAdminMigratable } from "../interfaces/IAdminMigratable.sol";

/**
 * @title  AdminMigratable extends Migratable with a priviliged migrate function.
 * @author M^0 Labs
 */
abstract contract AdminMigratable is Migratable, IAdminMigratable {
    /// @inheritdoc IAdminMigratable
    address public immutable migrationAdmin;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the AdminMigratable contract.
     * @param  migrationAdmin_ The admin of the contract.
     */
    constructor(address migrationAdmin_) {
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IAdminMigratable
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev Not used since only the admin can perform the migration.
     * @dev The unprivileged migrate() function will revert if called.
     */
    function _getMigrator() internal pure override returns (address) {
        return address(0);
    }
}
