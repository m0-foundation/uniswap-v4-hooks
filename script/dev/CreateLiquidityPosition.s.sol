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
        address tokenB = vm.envAddress("TOKEN_B");

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            tokenA,
            tokenB,
            int24(vm.envInt("TICK_LOWER_BOUND")),
            int24(vm.envInt("TICK_UPPER_BOUND"))
        );

        PoolKey memory poolKey = PoolKey({
            currency0: config.currency0,
            currency1: config.currency1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            hooks: IHooks(hook)
        });

        vm.startBroadcast(caller);

        _approvePermit2(caller, tokenA, config.posm);
        _approvePermit2(caller, tokenB, config.posm);

        IPositionManager(POSM_ETHEREUM).mint(
            PositionConfig({ poolKey: poolKey, tickLower: config.tickLowerBound, tickUpper: config.tickUpperBound }),
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(config.tickLowerBound),
                TickMath.getSqrtPriceAtTick(config.tickUpperBound),
                _liquidityAmountPrompt(tokenA, caller),
                _liquidityAmountPrompt(tokenB, caller)
            ),
            caller,
            ""
        );

        vm.stopBroadcast();
    }

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
}
