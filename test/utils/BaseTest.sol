// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { CustomRevert } from "../../lib/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol";
import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolId } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";

import { Deployers } from "../../lib/v4-periphery/lib/v4-core/test/utils/Deployers.sol";
import { LiquidityAmounts } from "../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";

import { StateView } from "../../lib/v4-periphery/src/lens/StateView.sol";

// Needs to be imported otherwise it won't compile
import { PositionDescriptor } from "../../lib/v4-periphery/src/PositionDescriptor.sol";
import { PositionManager } from "../../lib/v4-periphery/src/PositionManager.sol";

import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";
import { PosmTestSetup } from "../../lib/v4-periphery/test/shared/PosmTestSetup.sol";

import { LiquidityOperationsLib } from "./helpers/LiquidityOperationsLib.sol";

contract BaseTest is Deployers, PosmTestSetup {
    using LiquidityOperationsLib for IPositionManager;

    Currency public tokenOne;
    Currency public tokenTwo;

    PoolId public poolId;

    StateView public state;

    // Swap Fee in bps
    uint24 public constant SWAP_FEE = 100;

    // Initial Sqrt(P) value = 0
    uint160 public SQRT_PRICE_0_0;

    int24 public constant TICK_LOWER_BOUND = 0;
    int24 public constant TICK_UPPER_BOUND = 1;
    int24 public constant TICK_SPACING = 1;

    // Token ID for positions incremented each time mintNewPosition is called
    uint256 public tokenId;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    /* ============ SetUp ============ */

    function setUp() public virtual {
        SQRT_PRICE_0_0 = TickMath.getSqrtPriceAtTick(0);

        deployFreshManagerAndRouters();
        (tokenOne, tokenTwo) = deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);
        state = new StateView(manager);
    }

    function initPool(IHooks hook_) public {
        (key, poolId) = initPool(tokenOne, tokenTwo, hook_, SWAP_FEE, TICK_SPACING, SQRT_PRICE_0_0);
    }

    /* ============ Helpers ============ */

    function mintNewPosition(
        uint160 sqrtPriceX96_,
        int24 tickLower_,
        int24 tickUpper_,
        uint256 amount0,
        uint256 amount1
    ) public returns (uint128 positionLiquidity_, uint256 tokenId_) {
        tokenId_ = ++tokenId;

        PositionConfig memory positionConfig_ = PositionConfig({
            poolKey: key,
            tickLower: tickLower_,
            tickUpper: tickUpper_
        });

        positionLiquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96_,
            TickMath.getSqrtPriceAtTick(tickLower_),
            TickMath.getSqrtPriceAtTick(tickUpper_),
            amount0,
            amount1
        );

        lpm.mint(positionConfig_, positionLiquidity_, address(this), "");
    }

    /* ============ Assertions ============ */

    function expectWrappedRevert(address hook_, bytes4 hookSelector_, bytes memory errorSelector_) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                hook_,
                hookSelector_,
                errorSelector_,
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
    }
}
