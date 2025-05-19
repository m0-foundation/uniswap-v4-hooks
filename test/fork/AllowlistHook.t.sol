// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { PoolSwapTest } from "../../lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";
import { LiquidityAmounts } from "../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { IV4Router } from "../../lib/v4-periphery/src/interfaces/IV4Router.sol";
import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { Actions } from "../../lib/v4-periphery/src/libraries/Actions.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { IAllowlistHook } from "../../src/interfaces/IAllowlistHook.sol";
import { IBaseHook } from "../../src/interfaces/IBaseHook.sol";

import { AllowlistHook } from "../../src/AllowlistHook.sol";

import { Deploy } from "../../script/base/Deploy.s.sol";

import { LiquidityOperationsLib } from "../utils/helpers/LiquidityOperationsLib.sol";
import { IUniversalRouterLike } from "../utils/interfaces/IUniversalRouterLike.sol";

contract DeployTest is Deploy, Test {
    using LiquidityOperationsLib for IPositionManager;
    using StateLibrary for IPoolManager;

    DeployConfig public config;

    AllowlistHook public allowlistHook;
    PoolKey public poolKey;
    IUniversalRouterLike public swapRouter;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public constant DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address public constant ADMIN = 0x7F7489582b64ABe46c074A45d758d701c2CA5446; // MXON
    address public constant MANAGER = 0x431169728D75bd02f4053435b87D15c8d1FB2C72; // M0 Labs

    address public constant ZEROX_SETTLER = 0x0d0E364aa7852291883C162B22D6D81f6355428F;

    address public constant WRAPPED_M_HOLDER = 0xfF95c5f35F4ffB9d5f596F898ac1ae38D62749c2;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        config = _getDeployConfig(block.chainid);

        vm.prank(DEPLOYER);
        address allowlistHook_ = _deployAllowlistHook(ADMIN, MANAGER, config);

        poolKey = _deployPool(config, IHooks(allowlistHook_));
        allowlistHook = AllowlistHook(allowlistHook_);

        swapRouter = IUniversalRouterLike(config.swapRouter);
    }

    /* ============ swap ============ */

    function testFork_swapViaUniswapRouter() public {
        vm.selectFork(mainnetFork);

        vm.prank(MANAGER);
        allowlistHook.setSwapRouter(ZEROX_SETTLER, true);

        vm.prank(MANAGER);
        allowlistHook.setLiquidityProvider(alice, true);

        vm.prank(MANAGER);
        allowlistHook.setSwapper(bob, true);

        uint128 amount0 = 10_000_000e6;
        uint128 amount1 = 10_000_000e6;
        uint128 swapAmountOut = 1_000_000e6;
        uint128 swapAmountIn = type(uint128).max;

        vm.prank(WRAPPED_M_HOLDER);
        IERC20(WRAPPED_M).transfer(alice, amount0);

        deal(USDC_ETHEREUM, alice, amount1);
        deal(USDC_ETHEREUM, bob, swapAmountIn);

        vm.startPrank(alice);

        IERC20(WRAPPED_M).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(WRAPPED_M, config.posm, type(uint160).max, type(uint48).max);

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
            uint8(Actions.TAKE_ALL),
            uint8(Actions.SETTLE_ALL)
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactOutputSingleParams({
                poolKey: poolKey,
                zeroForOne: false,
                amountOut: swapAmountOut,
                amountInMaximum: swapAmountIn,
                hookData: bytes("")
            })
        );

        params[1] = abi.encode(poolKey.currency0, swapAmountOut);
        params[2] = abi.encode(poolKey.currency1, swapAmountIn);

        inputs[0] = abi.encode(actions, params);

        vm.prank(bob);
        swapRouter.execute(commands, inputs, block.timestamp + 1);
    }
}
