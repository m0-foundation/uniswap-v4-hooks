// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Ownable2Step, Ownable } from "../src/abstract/Ownable2Step.sol";

import { Ownable2StepHarness } from "./harness/Ownable2StepHarness.sol";

contract Ownable2StepTest is Test {
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    Ownable2StepHarness public ownable2Step;

    function setUp() public {
        ownable2Step = new Ownable2StepHarness(owner);
    }

    /* ============ transferOwnership ============ */

    function test_transferOwnership_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        ownable2Step.transferOwnership(alice);
    }

    function test_transferOwnership_cancel() public {
        vm.prank(owner);
        ownable2Step.transferOwnership(alice);

        assertEq(ownable2Step.pendingOwner(), alice);

        // Cancel the ownership transfer (pendingOwner => zero)
        vm.expectEmit();
        emit Ownable2Step.OwnershipTransferStarted(owner, address(0));

        vm.prank(owner);
        ownable2Step.transferOwnership(address(0));

        assertEq(ownable2Step.pendingOwner(), address(0));

        // Now alice can no longer accept
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        ownable2Step.acceptOwnership();
    }

    function test_transferOwnership() public {
        vm.expectEmit();
        emit Ownable2Step.OwnershipTransferStarted(owner, alice);

        vm.prank(owner);
        ownable2Step.transferOwnership(alice);

        assertEq(ownable2Step.owner(), owner);
        assertEq(ownable2Step.pendingOwner(), alice);
    }

    /* ============ acceptOwnership ============ */

    function test_acceptOwnership_unauthorizedAccount() public {
        vm.prank(owner);
        ownable2Step.transferOwnership(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));

        vm.prank(bob);
        ownable2Step.acceptOwnership();
    }

    function test_acceptOwnership() public {
        vm.prank(owner);
        ownable2Step.transferOwnership(alice);

        vm.expectEmit();
        emit Ownable.OwnershipTransferred(owner, alice);

        vm.prank(alice);
        ownable2Step.acceptOwnership();

        assertEq(ownable2Step.owner(), alice);
        assertEq(ownable2Step.pendingOwner(), address(0));
    }

    /* ============ renounceOwnership ============ */

    function test_renounceOwnership() public {
        vm.expectEmit();
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        ownable2Step.renounceOwnership();

        assertEq(ownable2Step.owner(), address(0));
    }

    function test_renounceOwnership_pendingOwnerReset() public {
        vm.prank(owner);
        ownable2Step.transferOwnership(alice);

        assertEq(ownable2Step.pendingOwner(), alice);

        vm.prank(owner);
        ownable2Step.renounceOwnership();

        assertEq(ownable2Step.pendingOwner(), address(0));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));

        vm.prank(alice);
        ownable2Step.acceptOwnership();
    }
}
