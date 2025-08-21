// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { LiquidityAmounts } from "../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { IV4Router } from "../../lib/v4-periphery/src/interfaces/IV4Router.sol";
import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { Actions } from "../../lib/v4-periphery/src/libraries/Actions.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { TickRangeHook } from "../../src/TickRangeHook.sol";

import { Deploy } from "../../script/base/Deploy.s.sol";

import { LiquidityOperationsLib } from "../utils/helpers/LiquidityOperationsLib.sol";
import { IUniversalRouterLike } from "../utils/interfaces/IUniversalRouterLike.sol";

contract TickRangeHookForkTest is Deploy, Test {
    using LiquidityOperationsLib for IPositionManager;
    using StateLibrary for IPoolManager;

    DeployConfig public config;

    TickRangeHook public tickRangeHook;
    PoolKey public poolKey;
    IUniversalRouterLike public swapRouter;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public constant DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address public constant ADMIN = 0x7F7489582b64ABe46c074A45d758d701c2CA5446; // MXON
    address public constant MANAGER = 0x431169728D75bd02f4053435b87D15c8d1FB2C72; // M0 Labs

    address public constant MUSD_HOLDER = 0x98F2b37A1F5e6dB22c4eBa7DE0398fB9be2AF03F;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 23_128_190); // Block number after which MUSD holder has MUSD

        config = _getDeployConfig(block.chainid, MUSD, USDC_ETHEREUM, 0, 1);

        vm.prank(DEPLOYER);
        address tickRangeHook_ = _deployTickRangeHook(ADMIN, MANAGER, config);

        poolKey = _deployPool(config, IHooks(tickRangeHook_));
        tickRangeHook = TickRangeHook(tickRangeHook_);

        swapRouter = IUniversalRouterLike(config.swapRouter);
    }

    /* ============ swap ============ */

    function testFork_swapUSDC_for_MUSD_viaUniswapRouter() public {
        vm.selectFork(mainnetFork);

        uint128 amount0 = 50e6;
        uint128 amount1 = 50e6;
        uint128 swapAmountOut = 10e6;
        uint128 swapAmountIn = type(uint128).max;

        vm.prank(MUSD_HOLDER);
        IERC20(MUSD).transfer(alice, amount0);

        deal(USDC_ETHEREUM, alice, amount1);
        deal(USDC_ETHEREUM, bob, swapAmountIn);

        vm.startPrank(alice);

        IERC20(MUSD).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(MUSD, config.posm, type(uint160).max, type(uint48).max);

        IERC20(USDC_ETHEREUM).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(USDC_ETHEREUM, config.posm, type(uint160).max, type(uint48).max);

        vm.stopPrank();

        PositionConfig memory positionConfig = PositionConfig({
            poolKey: poolKey,
            tickLower: config.tickLowerBound,
            tickUpper: config.tickUpperBound
        });

        uint128 positionLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(config.tickLowerBound),
            TickMath.getSqrtPriceAtTick(config.tickUpperBound),
            amount0,
            amount1
        );

        vm.prank(alice);
        IPositionManager(POSM_ETHEREUM).mint(positionConfig, positionLiquidity, alice, "");

        vm.startPrank(bob);

        IERC20(USDC_ETHEREUM).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(USDC_ETHEREUM, address(swapRouter), type(uint160).max, type(uint48).max);

        vm.stopPrank();

        bytes memory commands = abi.encodePacked(uint8(0x10)); // V4 Swap command
        bytes[] memory inputs = new bytes[](1);
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_OUT_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactOutputSingleParams({
                poolKey: poolKey,
                zeroForOne: true, // USDC is currency 0
                amountOut: swapAmountOut,
                amountInMaximum: swapAmountIn,
                hookData: ""
            })
        );

        params[1] = abi.encode(poolKey.currency0, swapAmountIn);
        params[2] = abi.encode(poolKey.currency1, swapAmountOut);

        inputs[0] = abi.encode(actions, params);

        uint256 bobUSDCBalanceBefore = IERC20(USDC_ETHEREUM).balanceOf(bob);
        uint256 bobMUSDBalanceBefore = IERC20(MUSD).balanceOf(bob);

        vm.prank(bob);
        swapRouter.execute(commands, inputs, block.timestamp + 1);

        assertEq(IERC20(USDC_ETHEREUM).balanceOf(bob), bobUSDCBalanceBefore - 10_000100);
        assertEq(IERC20(MUSD).balanceOf(bob), bobMUSDBalanceBefore + swapAmountOut);
    }
}
