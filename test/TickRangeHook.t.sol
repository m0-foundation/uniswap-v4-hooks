// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IAccessControl } from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHooks } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { Actions } from "../lib/v4-periphery/src/libraries/Actions.sol";
import { Hooks } from "../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { SafeCast } from "../lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol";

import { Planner, Plan } from "../lib/v4-periphery/test/shared/Planner.sol";

import { Fuzzers } from "../lib/v4-periphery/lib/v4-core/src/test/Fuzzers.sol";

import { IBaseTickRangeHook } from "../src/interfaces/IBaseTickRangeHook.sol";
import { IERC721Like } from "../src/interfaces/IERC721Like.sol";

import { TickRangeHook } from "../src/TickRangeHook.sol";

import { BaseTest } from "./utils/BaseTest.sol";
import { LiquidityOperationsLib } from "./utils/helpers/LiquidityOperationsLib.sol";

contract TickRangeHookTest is BaseTest {
    using SafeCast for int256;

    TickRangeHook public tickRangeHook;

    uint160 public flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG);

    function setUp() public override {
        super.setUp();

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, hookManager),
            address(flags)
        );

        tickRangeHook = TickRangeHook(address(flags));

        initPool(tickRangeHook);

        IERC721Like(address(lpm)).setApprovalForAll(address(tickRangeHook), true);
    }

    /* ============ constructor ============ */

    function test_constructor_ticksOutOfOrder_lowerGTUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_LOWER_BOUND)
        );

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_UPPER_BOUND, TICK_LOWER_BOUND, admin, hookManager),
            address(flags)
        );
    }

    function test_constructor_ticksOutOfOrder_lowerEqualUpper() public {
        vm.expectRevert(
            abi.encodeWithSelector(IBaseTickRangeHook.TicksOutOfOrder.selector, TICK_UPPER_BOUND, TICK_UPPER_BOUND)
        );

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_UPPER_BOUND, TICK_UPPER_BOUND, admin, hookManager),
            address(flags)
        );
    }

    function test_constructor_zeroAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseTickRangeHook.ZeroAdmin.selector));

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, address(0), hookManager),
            address(flags)
        );
    }

    function test_constructor_zeroManager() public {
        vm.expectRevert(abi.encodeWithSelector(IBaseTickRangeHook.ZeroManager.selector));

        deployCodeTo(
            "TickRangeHook.sol",
            abi.encode(address(manager), TICK_LOWER_BOUND, TICK_UPPER_BOUND, admin, address(0)),
            address(flags)
        );
    }

    /* ============ Role Management ============ */

    function test_grantRole_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, DEFAULT_ADMIN_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.grantRole(DEFAULT_ADMIN_ROLE, alice);
    }

    function test_grantRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleGranted(DEFAULT_ADMIN_ROLE, alice, admin);

        vm.prank(admin);
        tickRangeHook.grantRole(DEFAULT_ADMIN_ROLE, alice);
    }

    function test_revokeRole_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, DEFAULT_ADMIN_ROLE)
        );

        vm.prank(alice);
        tickRangeHook.revokeRole(DEFAULT_ADMIN_ROLE, alice);
    }

    function test_revokeRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleRevoked(MANAGER_ROLE, hookManager, admin);

        vm.prank(admin);
        tickRangeHook.revokeRole(MANAGER_ROLE, hookManager);
    }

    function test_renounceRole_onlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlBadConfirmation.selector));

        vm.prank(alice);
        tickRangeHook.renounceRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_renounceRole() public {
        vm.expectEmit();
        emit IAccessControl.RoleRevoked(DEFAULT_ADMIN_ROLE, admin, admin);

        vm.prank(admin);
        tickRangeHook.renounceRole(DEFAULT_ADMIN_ROLE, admin);
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
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, MANAGER_ROLE)
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
}
