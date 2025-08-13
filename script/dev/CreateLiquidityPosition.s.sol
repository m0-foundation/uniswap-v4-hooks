// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { StateLibrary } from "../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency, CurrencyLibrary } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { LiquidityAmounts } from "../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";

import { Deploy } from "../base/Deploy.s.sol";

import { LiquidityOperationsLib } from "../../test/utils/helpers/LiquidityOperationsLib.sol";

contract CreateLiquidityPosition is Deploy {
    using CurrencyLibrary for Currency;
    using LiquidityOperationsLib for IPositionManager;
    using StateLibrary for IPoolManager;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address hook = vm.envAddress("UNISWAP_HOOK");

        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");

        DeployConfig memory config = _getDeployConfig(block.chainid, tokenA, tokenB);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(WRAPPED_M),
            currency1: Currency.wrap(USDC_ETHEREUM),
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(hook)
        });

        PositionConfig memory positionConfig = PositionConfig({
            poolKey: poolKey,
            tickLower: config.tickLowerBound,
            tickUpper: config.tickUpperBound
        });

        uint128 positionLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(config.tickLowerBound),
            TickMath.getSqrtPriceAtTick(config.tickUpperBound),
            10e6,
            10e6
        );

        vm.startBroadcast(caller);

        if (IERC20(WRAPPED_M).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(WRAPPED_M).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 wrappedMPermit2Allowance, , ) = PERMIT2.allowance(caller, WRAPPED_M, config.posm);

        if (wrappedMPermit2Allowance == 0) {
            PERMIT2.approve(WRAPPED_M, config.posm, type(uint160).max, type(uint48).max);
        }

        if (IERC20(USDC_ETHEREUM).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(USDC_ETHEREUM).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 usdcPermit2Allowance, , ) = PERMIT2.allowance(caller, USDC_ETHEREUM, config.posm);

        if (usdcPermit2Allowance == 0) {
            PERMIT2.approve(USDC_ETHEREUM, config.posm, type(uint160).max, type(uint48).max);
        }

        IPositionManager(POSM_ETHEREUM).mint(positionConfig, positionLiquidity, caller, "");

        vm.stopBroadcast();
    }
}
