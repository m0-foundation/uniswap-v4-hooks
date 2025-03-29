// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Ownable2Step, Ownable } from "../../src/abstract/Ownable2Step.sol";

contract Ownable2StepHarness is Ownable2Step {
    constructor(address initialOwner_) Ownable(initialOwner_) {}
}
