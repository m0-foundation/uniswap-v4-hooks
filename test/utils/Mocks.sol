// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    AccessControlUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {
    UUPSUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

/// @custom:oz-upgrades-from src/TickRangeHook.sol:TickRangeHook
contract TickRangeHookUpgrade is UUPSUpgradeable, AccessControlUpgradeable {
    IPoolManager public poolManager;

    int24 public tickLowerBound;

    int24 public tickUpperBound;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function bar() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}

/// @custom:oz-upgrades-from src/AllowlistHook.sol:AllowlistHook
contract AllowlistHookUpgrade is UUPSUpgradeable, AccessControlUpgradeable {
    IPoolManager public poolManager;

    int24 public tickLowerBound;

    int24 public tickUpperBound;

    uint256 public swapCap;

    uint256 public totalSwap;

    bool public isLiquidityProvidersAllowlistEnabled;

    bool public isSwappersAllowlistEnabled;

    uint8 public referenceDecimals;

    uint8 internal _token0Decimals;

    uint8 internal _token1Decimals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function bar() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
