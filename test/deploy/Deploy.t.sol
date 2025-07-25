// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

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

    uint256 public mainnetFork;
    uint256 public optimismFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        optimismFork = vm.createFork(vm.envString("OPTIMISM_RPC_URL"));
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

        vm.prank(CREATE2_DEPLOYER);
        address allowlistHook_ = _deployAllowlistHook(ADMIN, MANAGER, config);

        assertTrue(IAccessControl(allowlistHook_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(allowlistHook_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));

        assertTrue(IAllowlistHook(allowlistHook_).isSwapRouterTrusted(config.swapRouter));
        assertTrue(IAllowlistHook(allowlistHook_).isPositionManagerTrusted(address(config.posm)));

        int24 tickLowerBound_ = IBaseTickRangeHook(allowlistHook_).tickLowerBound();
        int24 tickUpperBound_ = IBaseTickRangeHook(allowlistHook_).tickUpperBound();

        assertEq(tickLowerBound_, -1);
        assertEq(tickUpperBound_, 1);
        assertEq(getPriceAtTick(tickLowerBound_), 999900009999000099);
        assertEq(getPriceAtTick(tickUpperBound_), 1000100000000000000);
    }

    function testFork_deployAllowlistHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address allowlistHook_ = _deployAllowlistHook(ADMIN, MANAGER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(allowlistHook_));

        assertEq(Currency.unwrap(poolKey_.currency0), WRAPPED_M);
        assertEq(Currency.unwrap(poolKey_.currency1), USDC_ETHEREUM);
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), address(allowlistHook_));

        (, int24 tickCurrent_, , ) = IBaseHook(allowlistHook_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }

    function testFork_deployAllowlistHook_optimism() public {
        // TODO: skipping for now since Predicate's service manager is not deployed on optimism yet
        //       and deployment fails when initializing it.
        vm.skip(true);
        vm.selectFork(optimismFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address allowlistHook_ = _deployAllowlistHook(ADMIN, MANAGER, config);

        assertTrue(IAccessControl(allowlistHook_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(allowlistHook_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));

        assertTrue(IAllowlistHook(allowlistHook_).isSwapRouterTrusted(config.swapRouter));
        assertTrue(IAllowlistHook(allowlistHook_).isPositionManagerTrusted(address(config.posm)));

        int24 tickLowerBound_ = IBaseTickRangeHook(allowlistHook_).tickLowerBound();
        int24 tickUpperBound_ = IBaseTickRangeHook(allowlistHook_).tickUpperBound();

        assertEq(tickLowerBound_, -1);
        assertEq(tickUpperBound_, 1);
        assertEq(getPriceAtTick(tickLowerBound_), 999900009999000099);
        assertEq(getPriceAtTick(tickUpperBound_), 1000100000000000000);
    }

    function testFork_deployAllowlistHookAndPool_optimism() public {
        // TODO: skipping for now since Predicate's service manager is not deployed on optimism yet
        //       and deployment fails when initializing it.
        vm.skip(true);
        vm.selectFork(optimismFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address allowlistHook_ = _deployAllowlistHook(ADMIN, MANAGER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(allowlistHook_));

        assertEq(Currency.unwrap(poolKey_.currency0), WRAPPED_M);
        assertEq(Currency.unwrap(poolKey_.currency1), USDC_ETHEREUM);
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), address(allowlistHook_));

        (, int24 tickCurrent_, , ) = IBaseHook(allowlistHook_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }

    /* ============ deployTickRangeHook ============ */

    function testFork_deployTickRangeHook() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address tickRangeHook_ = _deployTickRangeHook(ADMIN, MANAGER, config);

        assertTrue(IAccessControl(tickRangeHook_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(tickRangeHook_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));

        assertEq(IBaseTickRangeHook(tickRangeHook_).tickLowerBound(), config.tickLowerBound);
        assertEq(IBaseTickRangeHook(tickRangeHook_).tickUpperBound(), config.tickUpperBound);
    }

    function testFork_deployTickRangeHookAndPool() public {
        vm.selectFork(mainnetFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address tickRangeHook_ = _deployTickRangeHook(ADMIN, MANAGER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(tickRangeHook_));

        assertEq(Currency.unwrap(poolKey_.currency0), WRAPPED_M);
        assertEq(Currency.unwrap(poolKey_.currency1), USDC_ETHEREUM);
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), tickRangeHook_);

        (, int24 tickCurrent_, , ) = IBaseHook(tickRangeHook_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }

    function testFork_deployTickRangeHook_optimism() public {
        vm.selectFork(optimismFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address tickRangeHook_ = _deployTickRangeHook(ADMIN, MANAGER, config);

        assertTrue(IAccessControl(tickRangeHook_).hasRole(bytes32(0x00), ADMIN));
        assertTrue(IAccessControl(tickRangeHook_).hasRole(keccak256("MANAGER_ROLE"), MANAGER));

        int24 tickLowerBound_ = IBaseTickRangeHook(tickRangeHook_).tickLowerBound();
        int24 tickUpperBound_ = IBaseTickRangeHook(tickRangeHook_).tickUpperBound();

        assertEq(tickLowerBound_, -1);
        assertEq(tickUpperBound_, 1);
        assertEq(getPriceAtTick(tickLowerBound_), 999900009999000099);
        assertEq(getPriceAtTick(tickUpperBound_), 1000100000000000000);
    }

    function testFork_deployTickRangeHookAndPool_optimism() public {
        vm.selectFork(optimismFork);

        DeployConfig memory config = _getDeployConfig(block.chainid);

        vm.prank(CREATE2_DEPLOYER);
        address tickRangeHook_ = _deployTickRangeHook(ADMIN, MANAGER, config);

        PoolKey memory poolKey_ = _deployPool(config, IHooks(tickRangeHook_));

        assertEq(Currency.unwrap(poolKey_.currency0), USDC_OPTIMISM);
        assertEq(Currency.unwrap(poolKey_.currency1), WRAPPED_M);
        assertEq(poolKey_.fee, config.fee);
        assertEq(poolKey_.tickSpacing, config.tickSpacing);
        assertEq(address(poolKey_.hooks), tickRangeHook_);

        (, int24 tickCurrent_, , ) = IBaseHook(tickRangeHook_).poolManager().getSlot0(poolKey_.toId());
        assertEq(tickCurrent_, 0);
    }

    /* ============ Utils ============ */

    function getPriceAtTick(int24 tick) public pure returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        require(priceX192 > 0, "Invalid sqrtPrice");

        return (priceX192 * 1e18) / (1 << 192);
    }
}
