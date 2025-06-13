// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { Config } from "../base/Config.sol";

contract MintTokens is Config, Script {
    address public constant MINTER_GATEWAY = 0xf7f9638cb444D65e5A40bF5ff98ebE4ff319F04E;
    address public constant WRAPPED_M_HOLDER = 0xfF95c5f35F4ffB9d5f596F898ac1ae38D62749c2;
}

contract MintWrappedM is MintTokens {
    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address recipient = vm.envAddress("RECIPIENT");
        DeployConfig memory config = _getDeployConfig(block.chainid);
        IERC20 wrappedM = IERC20(WRAPPED_M);

        vm.startBroadcast(WRAPPED_M_HOLDER);

        vm.startPrank(WRAPPED_M_HOLDER);

        wrappedM.transfer(deployer, wrappedM.balanceOf(WRAPPED_M_HOLDER));

        vm.stopPrank();

        vm.stopBroadcast();
    }
}
