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

    /// @inheritdoc IAdminMigratable
    address public immutable registrar;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the AdminMigratable contract.
     * @param  migrationAdmin_ The admin of the contract.
     * @param  registrar_      The address of the registrar contract.
     */
    constructor(address migrationAdmin_, address registrar_) {
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
    }

    /* ============ External Interactive functions ============ */

    /// @inheritdoc IAdminMigratable
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ External View/Pure Functions ============ */

    /// @inheritdoc IAdminMigratable
    function MIGRATOR_KEY_PREFIX() external pure virtual returns (bytes32) {}
}
