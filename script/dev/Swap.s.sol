// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { PredicateMessage } from "../../lib/predicate-contracts/src/interfaces/IPredicateClient.sol";

import { IAllowanceTransfer } from "../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Currency, CurrencyLibrary } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { Actions } from "../../lib/v4-periphery/src/libraries/Actions.sol";

import { IV4Router } from "../../lib/v4-periphery/src/interfaces/IV4Router.sol";

import { IUniversalRouterLike } from "../../test/utils/interfaces/IUniversalRouterLike.sol";

import { PredicateHelpers } from "./helpers/PredicateHelpers.sol";
import { UniswapV4Helpers } from "./helpers/UniswapV4Helpers.sol";

contract Swap is PredicateHelpers, UniswapV4Helpers {
    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address hook = vm.envAddress("UNISWAP_HOOK");

        bool withPredicateMessage = vm.envBool("WITH_PREDICATE_MESSAGE");

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            vm.envAddress("TOKEN_0"),
            vm.envAddress("TOKEN_1"),
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

        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);

        bool zeroForOne = vm.envBool("ZERO_FOR_ONE");
        uint256 swapAmount = _swapAmount(zeroForOne, token0, token1, caller);

        console.log("Pool state and liquidity before swap.");
        _printPoolState(poolKey, token0, token1, config.tickLowerBound, config.tickUpperBound);

        vm.startBroadcast(caller);

        _approvePermit2(caller, zeroForOne ? token0 : token1, config.swapRouter);
        _swap(config, hook, poolKey, caller, swapAmount, zeroForOne, withPredicateMessage);

        vm.stopBroadcast();

        console.log("Pool state and liquidity after swap.");
        _printPoolState(poolKey, token0, token1, config.tickLowerBound, config.tickUpperBound);
    }

    function _swapAmount(
        bool zeroForOne,
        address token0,
        address token1,
        address account
    ) internal returns (uint256 amount) {
        string memory token0Symbol = IERC20(token0).symbol();
        string memory token1Symbol = IERC20(token1).symbol();

        if (zeroForOne) {
            amount = _swapAmountPrompt(token0, token0Symbol, zeroForOne, account);
            console.log("Swapping %s %s for %s...", vm.toString(amount), token0Symbol, token1Symbol);
        } else {
            amount = _swapAmountPrompt(token0, token0Symbol, zeroForOne, account);
            console.log("Swapping %s %s for %s...", vm.toString(amount), token1Symbol, token0Symbol);
        }
    }

    function _swapAmountPrompt(
        address token,
        string memory symbol,
        bool zeroForOne,
        address account
    ) internal returns (uint256 amount) {
        uint256 balance = IERC20(token).balanceOf(account);

        amount = vm.parseUint(
            vm.prompt(string.concat("Enter amount of ", symbol, zeroForOne ? " to swap" : " to receive"))
        );

        if (amount > balance) {
            revert(string.concat("Insufficient ", symbol, " balance for account ", vm.toString(account)));
        }
    }

    function _swap(
        DeployConfig memory config,
        address hook,
        PoolKey memory poolKey,
        address caller,
        uint256 swapAmount,
        bool zeroForOne,
        bool withPredicateMessage
    ) internal {
        bytes memory actions;
        bytes[] memory inputs = new bytes[](1);
        bytes[] memory swapParams = new bytes[](3);

        uint128 swapAmountOut;
        uint128 swapAmountIn;

        if (zeroForOne) {
            actions = abi.encodePacked(
                uint8(Actions.SWAP_EXACT_IN_SINGLE),
                uint8(Actions.SETTLE_ALL),
                uint8(Actions.TAKE_ALL)
            );

            swapAmountOut = uint128(_getAmountWithSlippage(swapAmount, uint16(vm.envUint("SLIPPAGE")), false));
            swapAmountIn = uint128(swapAmount);

            swapParams[0] = abi.encode(
                IV4Router.ExactInputSingleParams({
                    poolKey: poolKey,
                    zeroForOne: zeroForOne,
                    amountIn: swapAmountIn,
                    amountOutMinimum: swapAmountOut,
                    hookData: withPredicateMessage
                        ? abi.encode(_getPredicateMessage(caller, poolKey, hook, zeroForOne, int256(swapAmount)))
                        : abi.encode("")
                })
            );

            swapParams[1] = abi.encode(poolKey.currency0, swapAmountIn);
            swapParams[2] = abi.encode(poolKey.currency1, swapAmountOut);
        } else {
            actions = abi.encodePacked(
                uint8(Actions.SWAP_EXACT_OUT_SINGLE),
                uint8(Actions.SETTLE_ALL),
                uint8(Actions.TAKE_ALL)
            );

            swapAmountOut = uint128(swapAmount);
            swapAmountIn = uint128(_getAmountWithSlippage(swapAmount, uint16(vm.envUint("SLIPPAGE")), true));

            swapParams[0] = abi.encode(
                IV4Router.ExactOutputSingleParams({
                    poolKey: poolKey,
                    zeroForOne: zeroForOne,
                    amountOut: swapAmountOut,
                    amountInMaximum: swapAmountIn,
                    hookData: withPredicateMessage
                        ? abi.encode(_getPredicateMessage(caller, poolKey, hook, zeroForOne, int256(swapAmount)))
                        : abi.encode("")
                })
            );

            swapParams[1] = abi.encode(poolKey.currency1, swapAmountIn);
            swapParams[2] = abi.encode(poolKey.currency0, swapAmountOut);
        }

        inputs[0] = abi.encode(actions, swapParams);

        // V4 Swap command
        IUniversalRouterLike(config.swapRouter).execute(abi.encodePacked(uint8(0x10)), inputs, block.timestamp + 1000);
    }
}
