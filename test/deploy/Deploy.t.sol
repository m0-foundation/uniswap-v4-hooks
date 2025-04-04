// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { console } from "../../lib/forge-std/src/console.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { Ownable } from "../../src/abstract/Ownable.sol";

import { IAllowlistHook } from "../../src/interfaces/IAllowlistHook.sol";
import { IBaseTickRangeHook } from "../../src/interfaces/IBaseTickRangeHook.sol";

import { Config } from "../../script/base/Config.sol";
import { Deploy } from "../../script/base/Deploy.sol";

contract DeployTest is Deploy, Test {
    address public constant OWNER = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;

    uint256 mainnetFork;

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

        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        vm.prank(config_.create2Deployer);
        IHooks allowlistHook_ = _deployAllowlistHook(OWNER, config_);

        assertEq(Ownable(address(allowlistHook_)).owner(), OWNER);
        assertTrue(IAllowlistHook(address(allowlistHook_)).isSwapRouterTrusted(config_.swapRouter));
        assertEq(
            uint8(IAllowlistHook(address(allowlistHook_)).getPositionManagerStatus(address(config_.posm))),
            uint8(IAllowlistHook.PositionManagerStatus.ALLOWED)
        );

        assertEq(IBaseTickRangeHook(address(allowlistHook_)).tickLowerBound(), config_.tickLowerBound);
        assertEq(IBaseTickRangeHook(address(allowlistHook_)).tickUpperBound(), config_.tickUpperBound);
    }

    function testFork_deployAllowlistHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        vm.prank(config_.create2Deployer);
        IHooks allowlistHook_ = _deployAllowlistHook(OWNER, config_);

        PoolKey memory poolKey_ = _deployPool(config_, allowlistHook_);

        assertEq(Currency.unwrap(poolKey_.currency0), address(config_.wrappedM));
        assertEq(Currency.unwrap(poolKey_.currency1), address(config_.usdc));
        assertEq(poolKey_.fee, config_.fee);
        assertEq(poolKey_.tickSpacing, config_.tickSpacing);
        assertEq(address(poolKey_.hooks), address(allowlistHook_));
        // TODO: check that initial tick is 0 by getting the pool info
    }

    /* ============ deployTickRangeHook ============ */

    function testFork_deployTickRangeHook() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        vm.prank(config_.create2Deployer);
        IHooks tickrangeHook_ = _deployTickRangeHook(OWNER, config_);

        assertEq(Ownable(address(tickrangeHook_)).owner(), OWNER);
        assertEq(IBaseTickRangeHook(address(tickrangeHook_)).tickLowerBound(), config_.tickLowerBound);
        assertEq(IBaseTickRangeHook(address(tickrangeHook_)).tickUpperBound(), config_.tickUpperBound);
    }

    function testFork_deployTickRangeHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config_ = _getDeployConfig(block.chainid);

        vm.prank(config_.create2Deployer);
        IHooks tickRangeHook_ = _deployTickRangeHook(OWNER, config_);

        PoolKey memory poolKey_ = _deployPool(config_, tickRangeHook_);

        assertEq(Currency.unwrap(poolKey_.currency0), address(config_.wrappedM));
        assertEq(Currency.unwrap(poolKey_.currency1), address(config_.usdc));
        assertEq(poolKey_.fee, config_.fee);
        assertEq(poolKey_.tickSpacing, config_.tickSpacing);
        assertEq(address(poolKey_.hooks), address(tickRangeHook_));
        // TODO: check that initial tick is 0
    }
}
