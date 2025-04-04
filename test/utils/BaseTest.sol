// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IHooks } from "../../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { CustomRevert } from "../../lib/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol";
import { Hooks } from "../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { TickMath } from "../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

import { Currency } from "../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolId } from "../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";

import { Deployers } from "../../lib/v4-periphery/lib/v4-core/test/utils/Deployers.sol";
import { LiquidityAmounts } from "../../lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";

import { Actions } from "../../lib/v4-periphery/src/libraries/Actions.sol";
import { ActionConstants } from "../../lib/v4-periphery/src/libraries/ActionConstants.sol";
import { IPositionManager } from "../../lib/v4-periphery/src/interfaces/IPositionManager.sol";
import { IV4Router } from "../../lib/v4-periphery/src/interfaces/IV4Router.sol";

import { StateView } from "../../lib/v4-periphery/src/lens/StateView.sol";

// Needs to be imported otherwise it won't compile
import { PositionDescriptor } from "../../lib/v4-periphery/src/PositionDescriptor.sol";
import { PositionManager } from "../../lib/v4-periphery/src/PositionManager.sol";

import { MockV4Router } from "../../lib/v4-periphery/test/mocks/MockV4Router.sol";

import { Plan, Planner } from "../../lib/v4-periphery/test/shared/Planner.sol";
import { PositionConfig } from "../../lib/v4-periphery/test/shared/PositionConfig.sol";
import { PosmTestSetup } from "../../lib/v4-periphery/test/shared/PosmTestSetup.sol";

import { LiquidityOperationsLib } from "./helpers/LiquidityOperationsLib.sol";

contract BaseTest is Deployers, PosmTestSetup {
    using LiquidityOperationsLib for IPositionManager;

    Currency public tokenZero;
    Currency public tokenOne;

    PoolId public poolId;

    MockV4Router public mockRouter;

    Plan public plan;
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

    address public mockPositionManager = makeAddr("positionManager");
    address public admin = makeAddr("admin");
    address public hookManager = makeAddr("hookManager");
    address public upgrader = makeAddr("upgrader");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    bytes32 internal constant _DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant _MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 internal constant _UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /* ============ SetUp ============ */

    function setUp() public virtual {
        SQRT_PRICE_0_0 = TickMath.getSqrtPriceAtTick(0);

        deployFreshManagerAndRouters();
        (tokenZero, tokenOne) = deployMintAndApprove2Currencies();

        mockRouter = new MockV4Router(manager);

        plan = Planner.init();

        deployAndApprovePosm(manager);
        state = new StateView(manager);
    }

    function initPool(IHooks hook_) public {
        (key, poolId) = initPool(tokenZero, tokenOne, hook_, SWAP_FEE, TICK_SPACING, SQRT_PRICE_0_0);
    }

    function initPool(IHooks hook_, uint160 initSqrtPriceX96_) public {
        (key, poolId) = initPool(tokenZero, tokenOne, hook_, SWAP_FEE, TICK_SPACING, initSqrtPriceX96_);
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

    /* ============ MockRouter Helpers ============ */

    function _prepareSwapExactOutSingle(
        uint256 amountOut_,
        uint256 expectedAmountIn_
    ) internal returns (uint256 inputBalanceBefore_, uint256 outputBalanceBefore_, bytes memory data_, uint256 value_) {
        IV4Router.ExactOutputSingleParams memory params_ = IV4Router.ExactOutputSingleParams(
            key,
            false,
            uint128(amountOut_),
            uint128(expectedAmountIn_),
            bytes("")
        );

        plan = plan.add(Actions.SWAP_EXACT_IN_SINGLE, abi.encode(params_));

        (inputBalanceBefore_, outputBalanceBefore_, data_, value_) = _finalizeSwap(tokenZero, tokenOne, amountOut_);
    }

    function _finalizeSwap(
        Currency inputCurrency_,
        Currency outputCurrency_,
        uint256 amountIn_,
        address takeRecipient_
    )
        internal
        view
        returns (uint256 inputBalanceBefore_, uint256 outputBalanceBefore_, bytes memory data_, uint256 value_)
    {
        inputBalanceBefore_ = inputCurrency_.balanceOfSelf();
        outputBalanceBefore_ = outputCurrency_.balanceOfSelf();

        data_ = plan.finalizeSwap(inputCurrency_, outputCurrency_, takeRecipient_);
        value_ = (inputCurrency_.isAddressZero()) ? amountIn_ : 0;
    }

    function _finalizeSwap(
        Currency inputCurrency_,
        Currency outputCurrency_,
        uint256 amountIn_
    )
        internal
        view
        returns (uint256 inputBalanceBefore_, uint256 outputBalanceBefore_, bytes memory data_, uint256 value_)
    {
        return _finalizeSwap(inputCurrency_, outputCurrency_, amountIn_, ActionConstants.MSG_SENDER);
    }

    function _executeSwap(
        address caller_,
        bytes memory data_,
        uint256 value_,
        Currency inputCurrency_,
        Currency outputCurrency_
    ) internal returns (uint256 inputBalanceAfter_, uint256 outputBalanceAfter_) {
        vm.prank(caller_);
        mockRouter.executeActions{ value: value_ }(data_);

        inputBalanceAfter_ = inputCurrency_.balanceOfSelf();
        outputBalanceAfter_ = outputCurrency_.balanceOfSelf();
    }

    function _executeSwap(
        address caller_,
        bytes memory data_,
        uint256 value_
    ) internal returns (uint256 inputBalanceAfter_, uint256 outputBalanceAfter_) {
        return _executeSwap(caller_, data_, value_, tokenZero, tokenOne);
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
