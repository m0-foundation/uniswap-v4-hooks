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

contract Swap is PredicateHelpers {
    using CurrencyLibrary for Currency;

    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function run() public {
        address caller = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address hook = vm.envAddress("UNISWAP_HOOK");

        bool withPredicateMessage = vm.envBool("WITH_PREDICATE_MESSAGE");

        DeployConfig memory config = _getDeployConfig(
            block.chainid,
            vm.envAddress("TOKEN_A"),
            vm.envAddress("TOKEN_B"),
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
        string memory token0Symbol = IERC20(token0).symbol();

        address token1 = Currency.unwrap(poolKey.currency1);
        string memory token1Symbol = IERC20(token1).symbol();

        bool zeroForOne = false;

        uint256 swapAmount = zeroForOne
            ? _swapAmountPrompt(token0, token0Symbol, caller)
            : _swapAmountPrompt(token1, token1Symbol, caller);

        zeroForOne
            ? console.log("Swapping %s %s for %s...", vm.toString(swapAmount), token0Symbol, token1Symbol)
            : console.log("Swapping %s %s for %s...", vm.toString(swapAmount), token1Symbol, token0Symbol);

        vm.startBroadcast(caller);

        _approvePermit2(caller, zeroForOne ? token0 : token1, config.swapRouter);
        _swap(config, hook, poolKey, caller, swapAmount, zeroForOne, withPredicateMessage);

        vm.stopBroadcast();
    }

    function _approvePermit2(address caller, address token, address swapRouter) internal {
        if (IERC20(token).allowance(caller, address(PERMIT2)) == 0) {
            IERC20(token).approve(address(PERMIT2), type(uint256).max);
        }

        (uint160 tokenPermit2Allowance, , ) = PERMIT2.allowance(caller, token, swapRouter);

        if (tokenPermit2Allowance == 0) {
            PERMIT2.approve(token, swapRouter, type(uint160).max, type(uint48).max);
        }
    }

    function _swapAmountPrompt(address token, string memory symbol, address account) internal returns (uint256 amount) {
        uint256 balance = IERC20(token).balanceOf(account);

        amount = vm.parseUint(vm.prompt(string.concat("Enter amount of ", symbol, " to swap")));

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
        bytes[] memory inputs = new bytes[](1);
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_OUT_SINGLE),
            uint8(Actions.TAKE_ALL),
            uint8(Actions.SETTLE_ALL)
        );

        uint128 swapAmountOut = uint128(swapAmount);
        uint128 swapAmountIn = type(uint128).max;

        bytes[] memory swapParams = new bytes[](3);
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

        swapParams[1] = abi.encode(poolKey.currency0, swapAmountOut);
        swapParams[2] = abi.encode(poolKey.currency1, swapAmountIn);

        inputs[0] = abi.encode(actions, swapParams);

        // V4 Swap command
        IUniversalRouterLike(config.swapRouter).execute(abi.encodePacked(uint8(0x10)), inputs, block.timestamp + 1000);
    }
}
