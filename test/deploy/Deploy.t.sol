// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    IAccessControl
} from "../../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";

import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IAllowlistHook } from "../../src/interfaces/IAllowlistHook.sol";
import { IBaseHook } from "../../src/interfaces/IBaseHook.sol";
import { IBaseTickRangeHook } from "../../src/interfaces/IBaseTickRangeHook.sol";

import { Config } from "../../script/base/Config.sol";
import { Deploy } from "../../script/base/Deploy.s.sol";

contract DeployTest is Deploy, Test {
    using StateLibrary for IPoolManager;

    address public constant DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address public constant ADMIN = 0x7F7489582b64ABe46c074A45d758d701c2CA5446; // MXON
    address public constant MANAGER = 0x431169728D75bd02f4053435b87D15c8d1FB2C72; // M0 Labs
    address public constant UPGRADER = 0x431169728D75bd02f4053435b87D15c8d1FB2C72; // M0 Labs

    uint256 public mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
    }

    /* ============ getConfig ============ */

    /// forge-config: default.allow_internal_expect_revert = true
    function testFork_getConfig_unsupportedChain() public {
        vm.expectRevert(abi.encodeWithSelector(Config.UnsupportedChain.selector, block.chainid));
        _getDeployConfig(block.chainid);
    }

    /* ============ deployAllowlistHook ============ */

    function testFork_deployAllowlistHook() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(DEPLOYER);
        (, address allowlistHookProxy_) = _deployAllowlistHook(DEPLOYER, ADMIN, MANAGER, UPGRADER, config);

        assertTrue(IAccessControl(allowlistHookProxy_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(allowlistHookProxy_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));
        assertTrue(IAccessControl(allowlistHookProxy_).hasRole(keccak256("UPGRADER_ROLE"), UPGRADER));

        assertTrue(IAllowlistHook(allowlistHookProxy_).isSwapRouterTrusted(config.swapRouter));
        assertEq(
            uint8(IAllowlistHook(allowlistHookProxy_).getPositionManagerStatus(address(config.posm))),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        assertEq(IBaseTickRangeHook(allowlistHookProxy_).tickLowerBound(), config.tickLowerBound);
        assertEq(IBaseTickRangeHook(allowlistHookProxy_).tickUpperBound(), config.tickUpperBound);
    }

    function testFork_deployAllowlistHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(DEPLOYER);
        (, address allowlistHookProxy_) = _deployAllowlistHook(DEPLOYER, ADMIN, MANAGER, UPGRADER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(allowlistHookProxy_));

        assertEq(Currency.unwrap(poolKey_.currency0), address(config.wrappedM));
        assertEq(Currency.unwrap(poolKey_.currency1), address(config.usdc));
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), address(allowlistHookProxy_));

        (, int24 tickCurrent_, , ) = IBaseHook(allowlistHookProxy_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }

    /* ============ deployTickRangeHook ============ */

    function testFork_deployTickRangeHook() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(DEPLOYER);
        (, address tickRangeHookProxy_) = _deployTickRangeHook(DEPLOYER, ADMIN, MANAGER, UPGRADER, config);

        assertTrue(IAccessControl(tickRangeHookProxy_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(tickRangeHookProxy_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));
        assertTrue(IAccessControl(tickRangeHookProxy_).hasRole(keccak256("UPGRADER_ROLE"), UPGRADER));

        assertEq(IBaseTickRangeHook(tickRangeHookProxy_).tickLowerBound(), config.tickLowerBound);
        assertEq(IBaseTickRangeHook(tickRangeHookProxy_).tickUpperBound(), config.tickUpperBound);
    }

    function testFork_deployTickRangeHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(DEPLOYER);
        (, address tickRangeHookProxy_) = _deployTickRangeHook(DEPLOYER, ADMIN, MANAGER, UPGRADER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(tickRangeHookProxy_));

        assertEq(Currency.unwrap(poolKey_.currency0), address(config.wrappedM));
        assertEq(Currency.unwrap(poolKey_.currency1), address(config.usdc));
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), tickRangeHookProxy_);

        (, int24 tickCurrent_, , ) = IBaseHook(tickRangeHookProxy_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }
}
