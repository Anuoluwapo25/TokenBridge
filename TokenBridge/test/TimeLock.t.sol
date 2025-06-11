//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Timelock} from "../src/Timelock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";



contract TimelockTest is Test {
    Timelock public timelock;
    MockERC20 public token;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    uint256 AMOUNT = 100e18;
    uint256 id = 0;

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20("Annie", "ANN", 18);
        timelock = new Timelock(token);

        vm.stopPrank();
        token.mint(user, AMOUNT * 10);
    }

    function test_deposit() public {
        vm.startPrank(user);

        token.approve(address(timelock), AMOUNT);
        timelock.depositeFund(AMOUNT);
        id = 0;

        (uint256 amount, ,bool withdraw, ) = timelock.pools(id);
        assertEq(amount, AMOUNT, "Deposit not True");
        assertEq(withdraw, false, "Should not be withdrawn before time");

        vm.stopPrank();
    }
    function test_withdraw() public {
        test_deposit();

        vm.warp(block.timestamp + 8 days);

        vm.startPrank(user);

        uint256 userBalanceBefore = token.balanceOf(user);
        timelock.withdraw(id);

        ( , ,bool withdraw, ) = timelock.pools(id);
        assertEq(withdraw, true, "Withdrawal false");
        assertEq(token.balanceOf(user), userBalanceBefore + AMOUNT , "No withdrawal");

        vm.stopPrank();
    }
    function test_revertEarlyWithdrawal() public {
        test_deposit();

        vm.startPrank(user);
        vm.expectRevert("Lock period not reached");
        timelock.withdraw(id);
        vm.stopPrank();
    }

    function test_getId() public {
        vm.startPrank(owner);

        timelock.getUserPoolIds(user);
    }
}