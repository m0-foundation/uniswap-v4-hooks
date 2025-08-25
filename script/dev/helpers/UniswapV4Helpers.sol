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

import { StateView } from "../../../lib/v4-periphery/src/lens/StateView.sol";

import { Deploy } from "../../base/Deploy.s.sol";

contract UniswapV4Helpers is Deploy {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    StateView public state;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function _approvePermit2(address caller, address token, address posm) internal {
        if (IERC20(token).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(token).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 tokenPermit2Allowance, , ) = PERMIT2.allowance(caller, token, posm);

        if (tokenPermit2Allowance == 0) {
            PERMIT2.approve(token, posm, type(uint160).max, type(uint48).max);
        }
    }

    function _liquidityAmountPrompt(address token, address account) internal returns (uint256 amount) {
        uint256 balance = IERC20(token).balanceOf(account);
        string memory symbol = IERC20(token).symbol();

        amount = vm.parseUint(vm.prompt(string.concat("Enter amount of ", symbol, " to add")));

        if (amount > balance) {
            revert(string.concat("Insufficient ", symbol, " balance for account ", vm.toString(account)));
        }
    }

    function _getLiquidityForAmounts(
        PoolKey memory key,
        address tokenA,
        address tokenB,
        int24 tickLowerBound,
        int24 tickUpperBound,
        address caller
    ) internal returns (uint128) {
        (, int24 currentTick, , ) = _getPoolState(key);

        console.log("Current tick: %s", currentTick);

        return
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(currentTick),
                TickMath.getSqrtPriceAtTick(tickLowerBound),
                TickMath.getSqrtPriceAtTick(tickUpperBound),
                _liquidityAmountPrompt(tokenA, caller),
                _liquidityAmountPrompt(tokenB, caller)
            );
    }

    function _getPoolState(
        PoolKey memory key
    ) internal view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) {
        return IPoolManager(POOL_MANAGER_ETHEREUM).getSlot0(key.toId());
    }
}
