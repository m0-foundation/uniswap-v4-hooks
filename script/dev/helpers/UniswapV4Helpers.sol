// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { console } from "../../../lib/forge-std/src/console.sol";
import { IERC20 } from "../../../lib/forge-std/src/interfaces/IERC20.sol";

import { IPoolManager } from "../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import { StateLibrary } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { LiquidityAmounts } from "../../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { Currency, CurrencyLibrary } from "../../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IAllowanceTransfer } from "../../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import { IPositionManager } from "../../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { PositionInfo, PositionInfoLibrary } from "../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";

import { StateView } from "../../../lib/v4-periphery/src/lens/StateView.sol";

import { Deploy } from "../../base/Deploy.s.sol";

contract UniswapV4Helpers is Deploy {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    StateView public state;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function _approvePermit2(address caller, address token, address spender) internal {
        if (IERC20(token).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(token).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 tokenPermit2Allowance, uint48 expiration, ) = PERMIT2.allowance(caller, token, spender);

        if (tokenPermit2Allowance == 0 || expiration < block.timestamp) {
            PERMIT2.approve(token, spender, type(uint160).max, type(uint48).max);
        }
    }

    function _liquidityAmountPrompt(address token, address account) internal returns (uint256 amount) {
        uint256 balance = IERC20(token).balanceOf(account);
        string memory symbol = IERC20(token).symbol();

        amount = vm.parseUint(vm.prompt(string.concat("Enter amount of ", symbol, " to add or remove")));

        if (amount > balance) {
            revert(string.concat("Insufficient ", symbol, " balance for account ", vm.toString(account)));
        }
    }

    function _getLiquidityForAmounts(
        address tokenA,
        address tokenB,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper,
        address caller
    ) internal returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(currentTick),
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                _liquidityAmountPrompt(tokenA, caller),
                _liquidityAmountPrompt(tokenB, caller)
            );
    }

    function _getAmountsForLiquidity(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256 liquidityA, uint256 liquidityB) {
        (liquidityA, liquidityB) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidity
        );
    }

    function _getPoolState(
        PoolKey memory poolKey
    ) internal view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) {
        return IPoolManager(POOL_MANAGER_ETHEREUM).getSlot0(poolKey.toId());
    }

    function _getPoolAndPositionInfo(
        uint256 tokenId
    ) internal view returns (PoolKey memory poolKey, PositionInfo positionInfo) {
        return IPositionManager(POSM_ETHEREUM).getPoolAndPositionInfo(tokenId);
    }

    function _getPoolAndPositionState(
        uint256 tokenId
    )
        internal
        view
        returns (
            PoolKey memory poolKey,
            PositionInfo positionInfo,
            address tokenA,
            address tokenB,
            int24 currentTick,
            int24 tickLower,
            int24 tickUpper,
            uint160 sqrtPriceX96
        )
    {
        (poolKey, positionInfo) = _getPoolAndPositionInfo(tokenId);
        (sqrtPriceX96, currentTick, , ) = _getPoolState(poolKey);

        tokenA = Currency.unwrap(poolKey.currency0);
        tokenB = Currency.unwrap(poolKey.currency1);

        tickLower = positionInfo.tickLower();
        tickUpper = positionInfo.tickUpper();

        console.log("Pool current sqrtPrice: %s", sqrtPriceX96);
        console.log("Pool current tick: %s", currentTick);

        _printPositionState(tokenId, tokenA, tokenB, sqrtPriceX96, tickLower, tickUpper);
    }

    function _getPoolLiquidity(PoolKey memory poolKey) internal view returns (uint128 liquidity) {
        return IPoolManager(POOL_MANAGER_ETHEREUM).getLiquidity(poolKey.toId());
    }

    function _getPositionLiquidity(uint256 tokenId) internal view returns (uint128 liquidity) {
        return IPositionManager(POSM_ETHEREUM).getPositionLiquidity(tokenId);
    }

    function _printPoolState(
        PoolKey memory poolKey,
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper
    ) internal view {
        string memory tokenASymbol = IERC20(tokenA).symbol();
        string memory tokenBSymbol = IERC20(tokenB).symbol();

        uint128 liquidity = _getPoolLiquidity(poolKey);
        (uint160 sqrtPriceX96, int24 currentTick, , ) = _getPoolState(poolKey);

        (uint256 liquidityA, uint256 liquidityB) = _getAmountsForLiquidity(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            liquidity
        );

        console.log("Pool current sqrtPrice: %s", sqrtPriceX96);
        console.log("Pool current tick: %s", currentTick);

        console.log("Liquidity between:");
        console.log("Lower tick: %s", tickLower);
        console.log("Upper tick: %s", tickUpper);
        console.log("%s liquidity: %s", tokenASymbol, liquidityA);
        console.log("%s liquidity: %s", tokenBSymbol, liquidityB);
    }

    function _printPositionState(
        uint256 tokenId,
        address tokenA,
        address tokenB,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) internal view {
        string memory tokenASymbol = IERC20(tokenA).symbol();
        string memory tokenBSymbol = IERC20(tokenB).symbol();

        uint128 liquidity = _getPositionLiquidity(tokenId);
        (uint256 liquidityA, uint256 liquidityB) = _getAmountsForLiquidity(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            liquidity
        );

        console.log("Position Tick Lower : %s", tickLower);
        console.log("Position Tick Upper : %s", tickUpper);
        console.log("%s liquidity: %s", tokenASymbol, liquidityA);
        console.log("%s liquidity: %s", tokenBSymbol, liquidityB);
    }
}
