// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
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
        uint256 liquidityAmountA = _liquidityAmountPrompt(tokenA, caller);

        address tokenB = vm.envAddress("TOKEN_B");
        uint256 liquidityAmountB = _liquidityAmountPrompt(tokenB, caller);

        DeployConfig memory config = _getDeployConfig(block.chainid, tokenA, tokenB);

        PoolKey memory poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
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
            liquidityAmountA,
            liquidityAmountB
        );

        vm.startBroadcast(caller);

        if (IERC20(tokenA).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(tokenA).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 tokenAPermit2Allowance, , ) = PERMIT2.allowance(caller, tokenA, config.posm);

        if (tokenAPermit2Allowance == 0) {
            PERMIT2.approve(tokenA, config.posm, type(uint160).max, type(uint48).max);
        }

        if (IERC20(tokenB).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(tokenB).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 tokenBPermit2Allowance, , ) = PERMIT2.allowance(caller, tokenB, config.posm);

        if (tokenBPermit2Allowance == 0) {
            PERMIT2.approve(tokenB, config.posm, type(uint160).max, type(uint48).max);
        }

        IPositionManager(POSM_ETHEREUM).mint(positionConfig, positionLiquidity, caller, "");

        vm.stopBroadcast();
    }

    function _liquidityAmountPrompt(address token, address account) internal returns (uint256 amount) {
        uint256 balance = IERC20(token).balanceOf(account);
        string memory symbol = IERC20(token).symbol();

        amount = vm.parseUint(vm.prompt(string.concat("Enter amount of ", symbol, " to add")));

        if (amount > balance) {
            revert(string.concat("Insufficient ", symbol, " balance for account ", vm.toString(account)));
        }
    }
}
