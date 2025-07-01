// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitEnrollEventTest
 * @dev Unit tests for LetsCommit contract focusing on enrollEvent function
 */
contract LetsCommitEnrollEventTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public organizer = makeAddr("organizer");

    // Test data
    string constant TITLE = "Test Event";
    string constant DESCRIPTION = "Test Description";
    string constant LOCATION = "Online Event";
    string constant IMAGE_URI = "https://example.com/image.jpg";
    uint256 constant PRICE_AMOUNT = 1000;
    uint256 constant COMMITMENT_AMOUNT = 500;
    uint8 constant MAX_PARTICIPANT = 50; // Maximum participants allowed
    string[5] TAGS = ["tag1", "tag2", "", "", ""];

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        vm.startPrank(deployer);
        mIDRXToken = new mIDRX();
        letsCommit = new LetsCommit(address(mIDRXToken));
        vm.stopPrank();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function createMultipleSessions(uint8 count) internal view returns (LetsCommit.Session[] memory) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](count);

        for (uint8 i = 0; i < count; i++) {
            sessions[i] = LetsCommit.Session({
                startSessionTime: block.timestamp + 10 days + (i * 1 days),
                endSessionTime: block.timestamp + 10 days + (i * 1 days) + 2 hours
            });
        }

        return sessions;
    }

    function createTestEvent() internal returns (uint256 eventId) {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;

        vm.prank(organizer);
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );

        return 1; // First event ID
    }

    function createTestEventWithAmounts(uint256 priceAmount, uint256 commitmentAmount)
        internal
        returns (uint256 eventId)
    {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;

        vm.prank(organizer);
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, priceAmount, commitmentAmount, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );

        return letsCommit.eventId(); // Return the current event ID
    }

    // ============================================================================
    // SUCCESS CASES
    // ============================================================================

    function test_EnrollEventSuccess() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 commitmentFeeWithDecimals = COMMITMENT_AMOUNT * (10 ** tokenDecimals);
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = commitmentFeeWithDecimals + eventFeeWithDecimals;

        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Test enrollment
        vm.expectEmit(true, true, false, true);
        emit IEventIndexer.EnrollEvent(eventId, alice, totalPayment);

        vm.prank(alice);
        bool success = letsCommit.enrollEvent(eventId);

        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), commitmentFeeWithDecimals);

        // Check organizer balances
        uint256 expectedClaimable = eventFeeWithDecimals / 2;
        uint256 expectedVested = eventFeeWithDecimals - expectedClaimable;
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), expectedVested);

        // Check token balance transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment);
        assertEq(mIDRXToken.balanceOf(alice), 0);
    }

    function test_EnrollEventWithMoreThanNeededApproval() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        uint256 excessiveApproval = totalPayment * 2; // Double the required amount

        // Mint tokens to alice and approve excessive amount
        vm.prank(deployer);
        mIDRXToken.mint(alice, excessiveApproval);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), excessiveApproval);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Enrollment should succeed even with excess approval
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(eventId);

        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));

        // Check that only the required amount was transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment);
        assertEq(mIDRXToken.balanceOf(alice), excessiveApproval - totalPayment);

        // Check remaining allowance
        assertEq(mIDRXToken.allowance(alice, address(letsCommit)), excessiveApproval - totalPayment);
    }

    function test_EnrollEventMultipleParticipants() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        // Mint tokens to both alice and bob
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);
        vm.prank(deployer);
        mIDRXToken.mint(bob, totalPayment);

        // Approve tokens
        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        vm.prank(bob);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Both should be able to enroll
        vm.prank(alice);
        bool successAlice = letsCommit.enrollEvent(eventId);

        vm.prank(bob);
        bool successBob = letsCommit.enrollEvent(eventId);

        assertTrue(successAlice);
        assertTrue(successBob);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertTrue(letsCommit.isParticipantEnrolled(eventId, bob));

        // Check organizer balances (should be doubled from two participants)
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 expectedClaimable = (eventFeeWithDecimals / 2) * 2; // From both participants
        uint256 expectedVested = (eventFeeWithDecimals - (eventFeeWithDecimals / 2)) * 2;
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), expectedVested);

        // Check total tokens transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment * 2);
    }

    // ============================================================================
    // ZERO AMOUNT TESTS
    // ============================================================================

    function test_EnrollEventWithZeroCommitmentFee() public {
        uint256 eventId = createTestEventWithAmounts(PRICE_AMOUNT, 0); // Zero commitment

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = eventFeeWithDecimals; // Only event fee, no commitment fee

        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Enrollment should succeed
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(eventId);

        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), 0);

        // Check organizer balances (only from event fee)
        uint256 expectedClaimable = eventFeeWithDecimals / 2;
        uint256 expectedVested = eventFeeWithDecimals - expectedClaimable;
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), expectedVested);
    }

    function test_EnrollEventWithZeroEventFee() public {
        uint256 eventId = createTestEventWithAmounts(0, COMMITMENT_AMOUNT); // Zero event fee

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 commitmentFeeWithDecimals = COMMITMENT_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = commitmentFeeWithDecimals; // Only commitment fee, no event fee

        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Enrollment should succeed
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(eventId);

        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), commitmentFeeWithDecimals);

        // Check organizer balances (should be zero since no event fee)
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), 0);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), 0);
    }

    function test_EnrollEventWithBothFeesZero() public {
        uint256 eventId = createTestEventWithAmounts(0, 0); // Both fees zero

        // Don't need to mint or approve any tokens

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Enrollment should succeed even with zero payment
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(eventId);

        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), 0);

        // Check organizer balances (should be zero)
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), 0);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), 0);

        // Check no tokens were transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), 0);
    }

    // ============================================================================
    // REVERT CASES
    // ============================================================================

    function test_RevertWhen_EnrollNonExistentEvent() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.enrollEvent(999);
    }

    function test_RevertWhen_ParticipantAlreadyEnrolled() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        // Mint tokens to alice and approve double amount
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment * 2);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment * 2);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // First enrollment - should succeed
        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // Second enrollment - should revert
        vm.prank(alice);
        vm.expectRevert(LetsCommit.ParticipantAlreadyEnrolled.selector);
        letsCommit.enrollEvent(eventId);
    }

    function test_RevertWhen_EnrollEventSaleNotStarted() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Try to enroll before sale starts (current time is before startSaleDate)
        vm.prank(alice);
        vm.expectRevert(LetsCommit.EventNotInSalePeriod.selector);
        letsCommit.enrollEvent(eventId);
    }

    function test_RevertWhen_EnrollEventSaleFinished() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to after sale period ends
        vm.warp(block.timestamp + 7 days + 1 hours);

        // Try to enroll after sale ends
        vm.prank(alice);
        vm.expectRevert(LetsCommit.EventNotInSalePeriod.selector);
        letsCommit.enrollEvent(eventId);
    }

    function test_RevertWhen_UserNotApprovedContract() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        // Mint tokens to alice but DON'T approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Try to enroll without approval
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InsufficientAllowance.selector, totalPayment, 0));
        letsCommit.enrollEvent(eventId);
    }

    function test_RevertWhen_UserApprovedInsufficientAmount() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        uint256 insufficientApproval = totalPayment - 1; // 1 wei less than required

        // Mint tokens to alice and approve insufficient amount
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), insufficientApproval);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Try to enroll with insufficient approval
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.InsufficientAllowance.selector, totalPayment, insufficientApproval)
        );
        letsCommit.enrollEvent(eventId);
    }

    function test_RevertWhen_UserInsufficientTokenBalance() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        uint256 insufficientBalance = totalPayment - 1; // 1 wei less than required

        // Mint insufficient tokens to alice but approve full amount
        vm.prank(deployer);
        mIDRXToken.mint(alice, insufficientBalance);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Try to enroll with insufficient balance - should revert with specific error
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.InsufficientBalance.selector, totalPayment, insufficientBalance)
        );
        letsCommit.enrollEvent(eventId);
    }
}
