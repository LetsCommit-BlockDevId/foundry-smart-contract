// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title mIDRXTest
 * @dev Unit tests for mIDRX token contract
 */
contract mIDRXTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    mIDRX public token;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Deploy mIDRX token
        vm.startPrank(deployer);
        token = new mIDRX();
        vm.stopPrank();
    }

    // ============================================================================
    // TOKEN METADATA TESTS
    // ============================================================================

    function test_TokenDecimals() public view {
        assertEq(token.decimals(), 2);
    }

    // ============================================================================
    // MINTING TESTS
    // ============================================================================

    function test_MintToAddress() public {
        uint256 mintAmount = 1000 * 10 ** 2; // 1000 tokens with 2 decimals

        // Check initial balance
        assertEq(token.balanceOf(alice), 0);

        // Mint tokens to Alice
        token.mint(alice, mintAmount);

        // Check balance after minting
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function test_MintMultipleAddresses() public {
        uint256 aliceAmount = 1000 * 10 ** 2; // 1000 tokens
        uint256 bobAmount = 2000 * 10 ** 2; // 2000 tokens

        // Mint to Alice
        token.mint(alice, aliceAmount);

        // Mint to Bob
        token.mint(bob, bobAmount);

        // Check balances
        assertEq(token.balanceOf(alice), aliceAmount);
        assertEq(token.balanceOf(bob), bobAmount);
        assertEq(token.totalSupply(), aliceAmount + bobAmount);
    }

    function test_MintZeroAmount() public {
        uint256 initialBalance = token.balanceOf(alice);
        uint256 initialSupply = token.totalSupply();

        // Mint zero tokens
        token.mint(alice, 0);

        // Balance and supply should remain unchanged
        assertEq(token.balanceOf(alice), initialBalance);
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_MintLargeAmount() public {
        uint256 largeAmount = 1_000_000_000 * 10 ** 2; // 1 billion tokens

        token.mint(alice, largeAmount);

        assertEq(token.balanceOf(alice), largeAmount);
        assertEq(token.totalSupply(), largeAmount);
    }

    // ============================================================================
    // TRANSFER TESTS
    // ============================================================================

    function test_TransferAfterMint() public {
        uint256 mintAmount = 1000 * 10 ** 2;
        uint256 transferAmount = 300 * 10 ** 2;

        // Mint tokens to Alice
        token.mint(alice, mintAmount);

        // Alice transfers to Bob
        vm.prank(alice);
        token.transfer(bob, transferAmount);

        // Check balances
        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.totalSupply(), mintAmount); // Total supply unchanged
    }

    function test_ApprovalAndTransferFrom() public {
        uint256 mintAmount = 1000 * 10 ** 2;
        uint256 approveAmount = 500 * 10 ** 2;
        uint256 transferAmount = 300 * 10 ** 2;

        // Mint tokens to Alice
        token.mint(alice, mintAmount);

        // Alice approves Bob to spend tokens
        vm.prank(alice);
        token.approve(bob, approveAmount);

        // Check allowance
        assertEq(token.allowance(alice, bob), approveAmount);

        // Bob transfers from Alice to Charlie
        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        // Check balances and allowance
        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(alice, bob), approveAmount - transferAmount);
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    function testFuzz_MintAnyAmount(uint256 amount) public {
        // Assume reasonable bounds to avoid overflow
        vm.assume(amount <= type(uint256).max / 2);

        uint256 initialSupply = token.totalSupply();

        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), initialSupply + amount);
    }

    function testFuzz_MintToAnyAddress(address to, uint256 amount) public {
        // Exclude zero address (invalid for ERC20)
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint256).max / 2);

        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
    }

    // ============================================================================
    // EDGE CASE TESTS
    // ============================================================================

    function test_MintToZeroAddressReverts() public {
        uint256 mintAmount = 1000 * 10 ** 6;

        // Minting to zero address should revert
        vm.expectRevert();
        token.mint(address(0), mintAmount);
    }

    function test_MultipleMintsSameAddress() public {
        uint256 firstMint = 1000 * 10 ** 2;
        uint256 secondMint = 500 * 10 ** 2;
        uint256 thirdMint = 750 * 10 ** 2;

        // Multiple mints to same address
        token.mint(alice, firstMint);
        token.mint(alice, secondMint);
        token.mint(alice, thirdMint);

        uint256 expectedTotal = firstMint + secondMint + thirdMint;
        assertEq(token.balanceOf(alice), expectedTotal);
        assertEq(token.totalSupply(), expectedTotal);
    }
}
