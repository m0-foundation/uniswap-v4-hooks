// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    IAccessControl
} from "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { PoolSwapTest } from "../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";

import { IBaseHook } from "../src/interfaces/IBaseHook.sol";
import { IBaseTickRangeHook } from "../src/interfaces/IBaseTickRangeHook.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { TickRangeHook } from "../src/TickRangeHook.sol";

import { BaseTest } from "./utils/BaseTest.sol";
import { TickRangeHookUpgrade } from "./utils/Mocks.sol";

contract TickRangeHookTest is BaseTest {
    // Deploy the implementation contract
    TickRangeHook public tickRangeHookImplementation = new TickRangeHook();
    TickRangeHook public tickRangeHook;

    bytes public proxyConstructorArgs;
    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);

    function setUp() public override {
        super.setUp();

        // Deploy the proxy contract to the mined address
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
            (address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager, upgrader)
        );

        proxyConstructorArgs = abi.encode(tickRangeHookImplementation, implementationInitializeCall);
        address namespacedFlags = address(flags ^ (0x4444 << 144)); // Namespace the hook to avoid collisions

        deployCodeTo(
            "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            proxyConstructorArgs,
            namespacedFlags
        );

        tickRangeHook = TickRangeHook(namespacedFlags);
        Hooks.validateHookPermissions(tickRangeHook, tickRangeHook.getHookPermissions());

        initPool(tickRangeHook);

        IERC721Like(address(lpm)).setApprovalForAll(address(tickRangeHook), true);
    }

    /* ============ initialize ============ */

    function test_initialize_ticksOutOfOrder_lowerGTUpper() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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

        tickRangeHook = TickRangeHook(namespacedFlags);
    }

    function test_initialize_ticksOutOfOrder_lowerEqualUpper() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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

        tickRangeHook = TickRangeHook(namespacedFlags);
    }

    function test_initialize_zeroPoolManager() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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

        tickRangeHook = TickRangeHook(namespacedFlags);
    }

    function test_initialize_zeroAdmin() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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

        tickRangeHook = TickRangeHook(namespacedFlags);
    }

    function test_initialize_zeroManager() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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

        tickRangeHook = TickRangeHook(namespacedFlags);
    }

    function test_initialize_zeroUpgrader() public {
        bytes memory implementationInitializeCall = abi.encodeCall(
            TickRangeHook.initialize,
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
        tickRangeHook = TickRangeHook(namespacedFlags);
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
        vm.expectEmit();
        emit IBaseTickRangeHook.TickRangeSet(1, 2);

        vm.prank(hookManager);
        tickRangeHook.setTickRange(1, 2);
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
