// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ownable } from "../src/abstract/Ownable.sol";

import { OwnableHarness } from "./harness/OwnableHarness.sol";

contract OwnableTest is Test {
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    OwnableHarness public ownable;

    function setUp() public {
        ownable = new OwnableHarness(owner);
    }

    /* ============ constructor ============ */

    function test_constructor_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new OwnableHarness(address(0));
    }

    function test_constructor() public {
        vm.expectEmit();
        emit Ownable.OwnershipTransferred(address(0), owner);

        new OwnableHarness(owner);

        assertEq(ownable.owner(), owner);
    }

    /* ============ transferOwnership ============ */

    function test_transferOwnership_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        ownable.transferOwnership(alice);
    }

    function test_transferOwnership_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));

        vm.prank(owner);
        ownable.transferOwnership(address(0));
    }

    function test_transferOwnership() public {
        vm.expectEmit();
        emit Ownable.OwnershipTransferred(owner, alice);

        vm.prank(owner);
        ownable.transferOwnership(alice);

        assertEq(ownable.owner(), alice);
    }

    /* ============ renounceOwnership ============ */

    function test_renounceOwnership_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        ownable.renounceOwnership();
    }

    function test_renounceOwnership() public {
        vm.expectEmit();
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        ownable.renounceOwnership();

        assertEq(ownable.owner(), address(0));
    }
}
