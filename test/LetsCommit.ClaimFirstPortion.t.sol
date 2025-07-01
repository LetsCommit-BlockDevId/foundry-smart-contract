// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitClaimFirstPortionTest
 * @dev Unit tests for LetsCommit contract focusing on claimFirstPortion function
 */
contract LetsCommitClaimFirstPortionTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken;
    
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public organizer = makeAddr("organizer");
    address public notOrganizer = makeAddr("notOrganizer");
    address public participant = makeAddr("participant");

    // Test data
    string constant TITLE = "Test Event";
    string constant DESCRIPTION = "Test Description";
    string constant IMAGE_URI = "https://example.com/image.jpg";
    uint256 constant PRICE_AMOUNT = 1000; // 1000 tokens (without decimals)
    uint256 constant COMMITMENT_AMOUNT = 500; // 500 tokens (without decimals)
    string[5] TAGS = ["tag1", "tag2", "", "", ""];

    uint256 constant TOKEN_DECIMALS = 2;
    uint256 constant PRICE_WITH_DECIMALS = PRICE_AMOUNT * (10 ** TOKEN_DECIMALS);
    uint256 constant COMMITMENT_WITH_DECIMALS = COMMITMENT_AMOUNT * (10 ** TOKEN_DECIMALS);

    // Event times
    uint256 public startSaleDate;
    uint256 public endSaleDate;
    uint256 public sessionStartTime;
    uint256 public sessionEndTime;

    // Test event ID
    uint256 public testEventId;

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Start at a fixed timestamp to have predictable time handling
        vm.warp(1000000000); // Set to a fixed timestamp
        
        vm.startPrank(deployer);
        mIDRXToken = new mIDRX();
        letsCommit = new LetsCommit(address(mIDRXToken));
        vm.stopPrank();

        // Setup time variables relative to current timestamp
        startSaleDate = block.timestamp + 1 days;
        endSaleDate = block.timestamp + 7 days;
        sessionStartTime = block.timestamp + 10 days;
        sessionEndTime = block.timestamp + 11 days;

        // Create a test event and enroll a participant to generate claimable amounts
        testEventId = _createTestEventWithEnrollment();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function _createBasicSession() internal view returns (LetsCommit.Session memory) {
        return LetsCommit.Session({
            startSessionTime: sessionStartTime,
            endSessionTime: sessionEndTime
        });
    }

    function _createTestEvent() internal returns (uint256 eventId) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = _createBasicSession();

        // Ensure we're at a time before startSaleDate when creating event
        vm.warp(startSaleDate - 1 hours);

        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );

        require(success, "Event creation failed");
        return letsCommit.eventId();
    }

    function _createTestEventWithEnrollment() internal returns (uint256 eventId) {
        // Create event
        eventId = _createTestEvent();

        // Mint tokens to participant
        uint256 totalPayment = PRICE_WITH_DECIMALS + COMMITMENT_WITH_DECIMALS;
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalPayment);

        // Move to sale period
        vm.warp(startSaleDate + 1 hours);

        // Approve and enroll participant
        vm.startPrank(participant);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        bool enrollSuccess = letsCommit.enrollEvent(eventId);
        vm.stopPrank();

        require(enrollSuccess, "Enrollment failed");
        return eventId;
    }

    function _getExpectedClaimableAmount() internal pure returns (uint256) {
        // 50% of the price amount (event fee)
        return PRICE_WITH_DECIMALS / 2;
    }

    // ============================================================================
    // TESTS FOR CLAIMFIRSTPORTION FUNCTION
    // ============================================================================

    /**
     * @dev Test Case 1: Should revert when event ID does not exist
     */
    function test_claimFirstPortion_RevertWhen_EventDoesNotExist() public {
        uint256 nonExistentEventId = 999;

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, nonExistentEventId));
        letsCommit.claimFirstPortion(nonExistentEventId);
    }

    /**
     * @dev Test Case 2: Should revert when msg.sender is not the event organizer
     */
    function test_claimFirstPortion_RevertWhen_NotEventOrganizer() public {
        vm.prank(notOrganizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotEventOrganizer.selector));
        letsCommit.claimFirstPortion(testEventId);
    }

    /**
     * @dev Test Case 3: Should revert when claimable amount is 0
     */
    function test_claimFirstPortion_RevertWhen_NoClaimableAmount() public {
        // Create a new event without any enrollments (no claimable amount)
        uint256 emptyEventId = _createTestEvent();

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NoClaimableAmount.selector));
        letsCommit.claimFirstPortion(emptyEventId);
    }

    /**
     * @dev Test Case 4: Should successfully transfer mIDRX tokens to organizer
     */
    function test_claimFirstPortion_TransfersTokensToOrganizer() public {
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();
        uint256 organizerBalanceBefore = mIDRXToken.balanceOf(organizer);
        uint256 contractBalanceBefore = mIDRXToken.balanceOf(address(letsCommit));

        vm.prank(organizer);
        bool success = letsCommit.claimFirstPortion(testEventId);

        // Verify success
        assertTrue(success, "Claim should be successful");

        // Verify token transfer
        uint256 organizerBalanceAfter = mIDRXToken.balanceOf(organizer);
        uint256 contractBalanceAfter = mIDRXToken.balanceOf(address(letsCommit));

        assertEq(
            organizerBalanceAfter,
            organizerBalanceBefore + expectedClaimAmount,
            "Organizer should receive expected claim amount"
        );

        assertEq(
            contractBalanceAfter,
            contractBalanceBefore - expectedClaimAmount,
            "Contract balance should decrease by claim amount"
        );
    }

    /**
     * @dev Test Case 5: Should update getOrganizerClaimedAmount correctly
     */
    function test_claimFirstPortion_UpdatesClaimedAmount() public {
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();

        // Check claimed amount before
        uint256 claimedBefore = letsCommit.getOrganizerClaimedAmount(testEventId, organizer);
        assertEq(claimedBefore, 0, "Claimed amount should be 0 before claiming");

        // Claim first portion
        vm.prank(organizer);
        bool success = letsCommit.claimFirstPortion(testEventId);
        assertTrue(success, "Claim should be successful");

        // Check claimed amount after
        uint256 claimedAfter = letsCommit.getOrganizerClaimedAmount(testEventId, organizer);
        assertEq(
            claimedAfter,
            expectedClaimAmount,
            "Claimed amount should equal the claimed amount"
        );
    }

    /**
     * @dev Test Case 6: Should reset organizer claimable amount to 0 after claiming
     */
    function test_claimFirstPortion_ResetsClaimableAmount() public {
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();

        // Check claimable amount before
        uint256 claimableBefore = letsCommit.getOrganizerClaimableAmount(testEventId, organizer);
        assertEq(claimableBefore, expectedClaimAmount, "Should have claimable amount before claiming");

        // Claim first portion
        vm.prank(organizer);
        bool success = letsCommit.claimFirstPortion(testEventId);
        assertTrue(success, "Claim should be successful");

        // Check claimable amount after
        uint256 claimableAfter = letsCommit.getOrganizerClaimableAmount(testEventId, organizer);
        assertEq(claimableAfter, 0, "Claimable amount should be 0 after claiming");
    }

    /**
     * @dev Test Case 7: Should emit OrganizerFirstClaim event with correct parameters
     */
    function test_claimFirstPortion_EmitsCorrectEvent() public {
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IEventIndexer.OrganizerFirstClaim({
            eventId: testEventId,
            organizer: organizer,
            claimAmount: expectedClaimAmount
        });

        vm.prank(organizer);
        bool success = letsCommit.claimFirstPortion(testEventId);
        assertTrue(success, "Claim should be successful");
    }

    /**
     * @dev Test Case 8: Should revert when trying to claim twice (double claiming prevention)
     */
    function test_claimFirstPortion_RevertWhen_AlreadyClaimed() public {
        // First claim should succeed
        vm.prank(organizer);
        bool success = letsCommit.claimFirstPortion(testEventId);
        assertTrue(success, "First claim should be successful");

        // Second claim should revert
        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NoClaimableAmount.selector));
        letsCommit.claimFirstPortion(testEventId);
    }

    /**
     * @dev Test Case 9: Should handle multiple events correctly
     */
    function test_claimFirstPortion_HandlesMultipleEvents() public {
        // Create second event with enrollment
        uint256 secondEventId = _createTestEventWithEnrollment();
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();

        // Claim from first event
        vm.prank(organizer);
        bool success1 = letsCommit.claimFirstPortion(testEventId);
        assertTrue(success1, "First event claim should be successful");

        // Claim from second event should still work
        vm.prank(organizer);
        bool success2 = letsCommit.claimFirstPortion(secondEventId);
        assertTrue(success2, "Second event claim should be successful");

        // Verify both events have correct claimed amounts
        uint256 claimed1 = letsCommit.getOrganizerClaimedAmount(testEventId, organizer);
        uint256 claimed2 = letsCommit.getOrganizerClaimedAmount(secondEventId, organizer);

        assertEq(claimed1, expectedClaimAmount, "First event claimed amount should be correct");
        assertEq(claimed2, expectedClaimAmount, "Second event claimed amount should be correct");
    }

    /**
     * @dev Test Case 10: Should work correctly with different organizers
     */
    function test_claimFirstPortion_WorksWithDifferentOrganizers() public {
        address organizer2 = makeAddr("organizer2");
        uint256 expectedClaimAmount = _getExpectedClaimableAmount();

        // Create event with different organizer
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = _createBasicSession();

        // Ensure we're at a time before startSaleDate when creating event
        vm.warp(startSaleDate - 1 hours);

        vm.prank(organizer2);
        bool createSuccess = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        assertTrue(createSuccess, "Event creation should succeed");

        uint256 organizer2EventId = letsCommit.eventId();

        // Enroll participant in second event
        uint256 totalPayment = PRICE_WITH_DECIMALS + COMMITMENT_WITH_DECIMALS;
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalPayment);

        vm.warp(startSaleDate + 1 hours);
        vm.startPrank(participant);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        bool enrollSuccess = letsCommit.enrollEvent(organizer2EventId);
        vm.stopPrank();
        assertTrue(enrollSuccess, "Enrollment should succeed");

        // Both organizers should be able to claim their respective events
        vm.prank(organizer);
        bool claim1 = letsCommit.claimFirstPortion(testEventId);
        assertTrue(claim1, "Organizer 1 claim should succeed");

        vm.prank(organizer2);
        bool claim2 = letsCommit.claimFirstPortion(organizer2EventId);
        assertTrue(claim2, "Organizer 2 claim should succeed");

        // Verify claimed amounts
        assertEq(
            letsCommit.getOrganizerClaimedAmount(testEventId, organizer),
            expectedClaimAmount,
            "Organizer 1 claimed amount should be correct"
        );
        assertEq(
            letsCommit.getOrganizerClaimedAmount(organizer2EventId, organizer2),
            expectedClaimAmount,
            "Organizer 2 claimed amount should be correct"
        );
    }

    // ============================================================================
    // EDGE CASE TESTS
    // ============================================================================

    /**
     * @dev Test Case 11: Should handle zero event ID correctly
     */
    function test_claimFirstPortion_RevertWhen_EventIdIsZero() public {
        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 0));
        letsCommit.claimFirstPortion(0);
    }

    /**
     * @dev Test Case 12: Should work with minimum valid amounts
     */
    function test_claimFirstPortion_WorksWithMinimumAmounts() public {
        // Create event with minimum amounts (1 token each)
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = _createBasicSession();

        // Ensure we're at a time before startSaleDate when creating event
        vm.warp(startSaleDate - 1 hours);

        vm.prank(organizer);
        bool createSuccess = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            1, // 1 token price
            1, // 1 token commitment
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        assertTrue(createSuccess, "Event creation should succeed");

        uint256 minEventId = letsCommit.eventId();

        // Enroll participant
        uint256 totalPayment = 2 * (10 ** TOKEN_DECIMALS); // 2 tokens with decimals
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalPayment);

        vm.warp(startSaleDate + 1 hours);
        vm.startPrank(participant);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        bool enrollSuccess = letsCommit.enrollEvent(minEventId);
        vm.stopPrank();
        assertTrue(enrollSuccess, "Enrollment should succeed");

        // Claim should work
        vm.prank(organizer);
        bool claimSuccess = letsCommit.claimFirstPortion(minEventId);
        assertTrue(claimSuccess, "Claim should succeed with minimum amounts");

        // Should receive 0.5 tokens (50% of 1 token)
        uint256 expectedAmount = (10 ** TOKEN_DECIMALS) / 2;
        assertEq(
            letsCommit.getOrganizerClaimedAmount(minEventId, organizer),
            expectedAmount,
            "Should claim correct minimum amount"
        );
    }
}
