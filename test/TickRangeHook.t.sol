// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    IAccessControl
} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Actions } from "../lib/v4-periphery/src/libraries/Actions.sol";
import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { SafeCast } from "../lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Planner, Plan } from "../lib/v4-periphery/test/shared/Planner.sol";

import { Fuzzers } from "../lib/v4-periphery/lib/v4-core/src/test/Fuzzers.sol";
import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { IBaseHook } from "../src/interfaces/IBaseHook.sol";
import { IBaseTickRangeHook } from "../src/interfaces/IBaseTickRangeHook.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { TickRangeHookHarness } from "./harness/TickRangeHookHarness.sol";

import { BaseTest } from "./utils/BaseTest.sol";
import { TickRangeHookUpgrade } from "./utils/Mocks.sol";
import { LiquidityOperationsLib } from "./utils/helpers/LiquidityOperationsLib.sol";

contract TickRangeHookTest is BaseTest {
    using SafeCast for int256;

    // Deploy the implementation contract
    TickRangeHookHarness public tickRangeHookImplementation = new TickRangeHookHarness();
    TickRangeHookHarness public tickRangeHook;

    bytes public proxyConstructorArgs;
    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        // Deploy the proxy contract to the mined address
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager, upgrader)
        );

        proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 144)); // Namespace the hook to avoid collisions

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
        Hooks.validateHookPermissions(tickRangeHook, tickRangeHook.getHookPermissions());

        initPool(tickRangeHook);

        IERC721Like(address(lpm)).setApprovalForAll(address(tickRangeHook), true);
    }

    /* ============ initialize ============ */

    function test_initialize_ticksOutOfOrder_lowerGTUpper() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_UPPER_BOUND, TICK_LOWER_BOUND, admin, hookManager, upgrader)
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_LOWER_BOUND)
        );

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    function test_initialize_ticksOutOfOrder_lowerEqualUpper() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_UPPER_BOUND, TICK_UPPER_BOUND, admin, hookManager, upgrader)
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_UPPER_BOUND)
        );

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    function test_initialize_zeroPoolManager() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(0), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager, upgrader)
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(abi.encodeWithSelector(IBaseHook.ZeroPoolManager.selector));

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    function test_initialize_zeroAdmin() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, address(0), hookManager, upgrader)
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(abi.encodeWithSelector(IBaseTickRangeHook.ZeroAdmin.selector));

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    function test_initialize_zeroManager() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, address(0), upgrader)
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(abi.encodeWithSelector(IBaseTickRangeHook.ZeroManager.selector));

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    function test_initialize_zeroUpgrader() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHookHarness.initialize,
            (address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager, address(0))
        );

        bytes memory proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 145));

        vm.expectRevert(abi.encodeWithSelector(IBaseTickRangeHook.ZeroUpgrader.selector));

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );
        tickRangeHook = TickRangeHookHarness(namespacedFlags);
    }

    /* ============ Role Management ============ */

    function test_grantRole_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _DEFAULT_ADMIN_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.grantRole(_DEFAULT_ADMIN_ROLE, alice);
    }

    function test_grantRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleGranted(_DEFAULT_ADMIN_ROLE, alice, admin);

        vm.prank(admin);
        tickRangeHook.grantRole(_DEFAULT_ADMIN_ROLE, alice);
    }

    function test_revokeRole_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _DEFAULT_ADMIN_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.revokeRole(_DEFAULT_ADMIN_ROLE, alice);
    }

    function test_revokeRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleRevoked(_MANAGER_ROLE, hookManager, admin);

        vm.prank(admin);
        tickRangeHook.revokeRole(_MANAGER_ROLE, hookManager);
    }

    function test_renounceRole_onlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlBadConfirmation.selector));

        vm.prank(alice);
        tickRangeHook.renounceRole(_DEFAULT_ADMIN_ROLE, admin);
    }

    function test_renounceRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleRevoked(_DEFAULT_ADMIN_ROLE, admin, admin);

        vm.prank(admin);
        tickRangeHook.renounceRole(_DEFAULT_ADMIN_ROLE, admin);
    }

    /* ============ afterSwap ============ */

    function test_afterSwap_invalidTick_outsideLowerBound() public {
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = -1;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1e6, // Exact output for input
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap_invalidTick_outsideUpperBound() public {
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = 2;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000_000e6, // Exact input for output
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap_invalidTick_equalUpperBound() public {
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        int24 tick_ = 1;

        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.afterSwap.selector,
            abi.encodeWithSelector(IBaseTickRangeHook.InvalidTick.selector, tick_, TICK_LOWER_BOUND, TICK_UPPER_BOUND)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000_000e6, // Exact input for output
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tick_)
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );
    }

    function test_afterSwap() public {
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 10_000e6, // Exact input for output swap
                sqrtPriceLimitX96: SQRT_PRICE_0_0 + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            ""
        );

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0 + 1);
        assertEq(tick_, 0);
    }

    function testFuzz_checkTick(int24 tick_) public {
        if (tick_ < TICK_LOWER_BOUND || tick_ >= TICK_UPPER_BOUND) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IBaseTickRangeHook.InvalidTick.selector,
                    tick_,
                    TICK_LOWER_BOUND,
                    TICK_UPPER_BOUND
                )
            );
        }

        tickRangeHook.checkTick(tick_);
    }

    /* ============ beforeAddLiquidity ============ */

    function test_beforeAddLiquidity_invalidTickRange_outsideLowerBound() public {
        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                IBaseTickRangeHook.InvalidTickRange.selector,
                TICK_LOWER_BOUND - 1,
                TICK_UPPER_BOUND,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND
            )
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND - 1, TICK_UPPER_BOUND, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity_invalidTickRange_outsideUpperBound() public {
        expectWrappedRevert(
            address(tickRangeHook),
            IHooks.beforeAddLiquidity.selector,
            abi.encodeWithSelector(
                IBaseTickRangeHook.InvalidTickRange.selector,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND + 1,
                TICK_LOWER_BOUND,
                TICK_UPPER_BOUND
            )
        );

        mintNewPosition(SQRT_PRICE_0_0, TICK_LOWER_BOUND, TICK_UPPER_BOUND + 1, 1_000_000e6, 1_000_000e6);
    }

    function test_beforeAddLiquidity() public {
        (uint128 positionLiquidity_, uint256 tokenId_) = mintNewPosition(
            SQRT_PRICE_0_0,
            TICK_LOWER_BOUND,
            TICK_UPPER_BOUND,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(lpm.getPositionLiquidity(tokenId_), positionLiquidity_);

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0);
        assertEq(tick_, 0);
    }

    function testFuzz_beforeAddLiquidity(IPoolManager.ModifyLiquidityParams memory params_) public {
        params_ = Fuzzers.createFuzzyLiquidityParams(key, params_, SQRT_PRICE_0_0);

        Plan memory planner = Planner.init().add(
            Actions.MINT_POSITION,
            abi.encode(
                key,
                params_.tickLower,
                params_.tickUpper,
                uint256(params_.liquidityDelta),
                LiquidityOperationsLib.MAX_SLIPPAGE_INCREASE,
                LiquidityOperationsLib.MAX_SLIPPAGE_INCREASE,
                address(this),
                ""
            )
        );

        bytes memory calls = planner.finalizeModifyLiquidityWithClose(key);

        if (params_.tickLower < TICK_LOWER_BOUND || params_.tickUpper > TICK_UPPER_BOUND) {
            expectWrappedRevert(
                address(tickRangeHook),
                IHooks.beforeAddLiquidity.selector,
                abi.encodeWithSelector(
                    IBaseTickRangeHook.InvalidTickRange.selector,
                    params_.tickLower,
                    params_.tickUpper,
                    TICK_LOWER_BOUND,
                    TICK_UPPER_BOUND
                )
            );
        }

        lpm.modifyLiquidities(calls, block.timestamp + 1);

        if (params_.tickLower < TICK_LOWER_BOUND || params_.tickUpper > TICK_UPPER_BOUND) return;

        (uint160 sqrtPriceX96_, int24 tick_, , ) = state.getSlot0(poolId);

        assertEq(sqrtPriceX96_, SQRT_PRICE_0_0);
        assertEq(tick_, 0);
    }

    /* ============ setTickRange ============ */

    function test_setTickRange_onlyHookManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _MANAGER_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.setTickRange(1, 2);
    }

    function test_setTickRange_ticksOutOfOrder_lowerGTUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_LOWER_BOUND)
        );

        vm.prank(hookManager);
        tickRangeHook.setTickRange(TICK_UPPER_BOUND, TICK_LOWER_BOUND);
    }

    function test_setTickRange_ticksOutOfOrder_lowerEqualUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_UPPER_BOUND)
        );

        vm.prank(hookManager);
        tickRangeHook.setTickRange(TICK_UPPER_BOUND, TICK_UPPER_BOUND);
    }

    function test_setTickRange() public {
        int24 tickLower = 1;
        int24 tickUpper = 2;

        vm.expectEmit();
        emit IBaseTickRangeHook.TickRangeSet(tickLower, tickUpper);

        vm.prank(hookManager);
        tickRangeHook.setTickRange(tickLower, tickUpper);

        assertEq(tickRangeHook.tickLowerBound(), tickLower);
        assertEq(tickRangeHook.tickUpperBound(), tickUpper);
    }

    function testFuzz_setTickRange(int24 tickLower_, int24 tickUpper_) public {
        if (tickLower_ >= tickUpper_) {
            vm.expectRevert(
                abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, tickLower_, tickUpper_)
            );
        } else {
            vm.expectEmit();
            emit IBaseTickRangeHook.TickRangeSet(tickLower_, tickUpper_);
        }

        vm.prank(hookManager);
        tickRangeHook.setTickRange(tickLower_, tickUpper_);

        if (tickLower_ >= tickUpper_) return;

        assertEq(tickRangeHook.tickLowerBound(), tickLower_);
        assertEq(tickRangeHook.tickUpperBound(), tickUpper_);
    }

    /* ============ upgrade ============ */

    function test_upgrade_onlyUpgrader() public {
        address v2implementation = address(new TickRangeHookUpgrade());

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, _UPGRADER_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.upgradeToAndCall(v2implementation, "");
    }

    function test_upgrade() public {
        address v2implementation = address(new TickRangeHookUpgrade());

        vm.prank(upgrader);
        tickRangeHook.upgradeToAndCall(v2implementation, "");

        assertEq(TickRangeHookUpgrade(address(tickRangeHook)).bar(), 1);
    }
}
