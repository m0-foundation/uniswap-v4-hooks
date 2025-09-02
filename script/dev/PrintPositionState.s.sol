// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { UniswapV4Helpers } from "./helpers/UniswapV4Helpers.sol";

contract PrintPositionState is UniswapV4Helpers {
    function run() public view {
        _getPoolAndPositionState(vm.envUint("TOKEN_ID"));
    }
}
