// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitSetSessionCodeTest
 * @dev Unit tests for LetsCommit contract focusing on setSessionCode function
 */
contract LetsCommitSetSessionCodeTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken;

    address public deployer = makeAddr("deployer");
    address public organizer = makeAddr("organizer");
    address public notOrganizer = makeAddr("notOrganizer");
    address public participant = makeAddr("participant");

    // Test data
    string constant TITLE = "Test Event";
    string constant DESCRIPTION = "Test Description";
    string constant IMAGE_URI = "https://example.com/image.jpg";
    string constant LOCATION = "Online Event";
    uint256 constant PRICE_AMOUNT = 1000; // 1000 tokens (without decimals)
    uint256 constant COMMITMENT_AMOUNT = 500; // 500 tokens (without decimals)
    uint8 constant MAX_PARTICIPANT = 50; // Maximum participants allowed
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

    // Session code
    string constant VALID_SESSION_CODE = "ABC1";
    string constant INVALID_SHORT_CODE = "AB";
    string constant INVALID_LONG_CODE = "ABCDE";

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

        // Create a test event and enroll a participant to generate vested amounts
        testEventId = _createTestEventWithEnrollment();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function _createBasicSession() internal view returns (LetsCommit.Session memory) {
        return
            LetsCommit.Session({startSessionTime: sessionStartTime, endSessionTime: sessionEndTime, attendedCount: 0});
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
            LOCATION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            MAX_PARTICIPANT,
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

    function _createEventWithMultipleSessions() internal returns (uint256 eventId) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](3);
        sessions[0] =
            LetsCommit.Session({startSessionTime: sessionStartTime, endSessionTime: sessionEndTime, attendedCount: 0});
        sessions[1] = LetsCommit.Session({
            startSessionTime: sessionStartTime + 1 days,
            endSessionTime: sessionEndTime + 1 days,
            attendedCount: 0
        });
        sessions[2] = LetsCommit.Session({
            startSessionTime: sessionStartTime + 2 days,
            endSessionTime: sessionEndTime + 2 days,
            attendedCount: 0
        });

        // Ensure we're at a time before startSaleDate when creating event
        vm.warp(startSaleDate - 1 hours);

        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            LOCATION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            MAX_PARTICIPANT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );

        require(success, "Event creation failed");
        return letsCommit.eventId();
    }

    function _getExpectedVestedAmountPerSession(uint256 eventId) internal view returns (uint256) {
        return letsCommit.getOrganizerVestedAmountPerSession(eventId);
    }

    // ============================================================================
    // TESTS FOR SETSESSIONCODE FUNCTION
    // ============================================================================

    function testSetSessionCode_RevertWhen_EventDoesNotExist() public {
        uint256 nonExistentEventId = 999;

        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, nonExistentEventId));
        letsCommit.setSessionCode(nonExistentEventId, 0, VALID_SESSION_CODE);
    }

    function testSetSessionCode_RevertWhen_SessionIndexDoesNotExist() public {
        uint8 invalidSessionIndex = 5; // Event only has 1 session (index 0)

        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InvalidSessionIndex.selector));
        letsCommit.setSessionCode(testEventId, invalidSessionIndex, VALID_SESSION_CODE);
    }

    function testSetSessionCode_RevertWhen_SenderIsNotOrganizer() public {
        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(notOrganizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotEventOrganizer.selector));
        letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
    }

    function testSetSessionCode_RevertWhen_NotWithinSessionTimePeriod_BeforeSession() public {
        vm.warp(sessionStartTime - 1 hours); // Before session starts

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotWithinSessionTime.selector));
        letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
    }

    function testSetSessionCode_RevertWhen_NotWithinSessionTimePeriod_AfterSession() public {
        vm.warp(sessionEndTime + 1 hours); // After session ends

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotWithinSessionTime.selector));
        letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
    }

    function testSetSessionCode_RevertWhen_CodeIsNotExactly4Characters_TooShort() public {
        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InvalidSessionCodeLength.selector));
        letsCommit.setSessionCode(testEventId, 0, INVALID_SHORT_CODE);
    }

    function testSetSessionCode_RevertWhen_CodeIsNotExactly4Characters_TooLong() public {
        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InvalidSessionCodeLength.selector));
        letsCommit.setSessionCode(testEventId, 0, INVALID_LONG_CODE);
    }

    function testSetSessionCode_RevertWhen_SessionCodeAlreadySet() public {
        vm.warp(sessionStartTime + 1 hours); // Within session time

        // First call should succeed
        vm.prank(organizer);
        bool success = letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
        assertTrue(success);

        // Second call should fail
        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.SessionCodeAlreadySet.selector));
        letsCommit.setSessionCode(testEventId, 0, "XYZ2");
    }

    function testSetSessionCode_RevertWhen_NoVestedAmountToRelease() public {
        // Create event with multiple sessions to drain vested amount
        uint256 multiSessionEventId = _createEventWithMultipleSessions();

        // Enroll participant to create vested amount
        uint256 totalPayment = PRICE_WITH_DECIMALS + COMMITMENT_WITH_DECIMALS;
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalPayment);

        vm.warp(startSaleDate + 1 hours);
        vm.startPrank(participant);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        letsCommit.enrollEvent(multiSessionEventId);
        vm.stopPrank();

        // Set session codes for all sessions to drain vested amount
        vm.warp(sessionStartTime + 1 hours);
        vm.startPrank(organizer);
        letsCommit.setSessionCode(multiSessionEventId, 0, "AAA1");

        vm.warp(sessionStartTime + 1 days + 1 hours);
        letsCommit.setSessionCode(multiSessionEventId, 1, "BBB2");

        vm.warp(sessionStartTime + 2 days + 1 hours);
        letsCommit.setSessionCode(multiSessionEventId, 2, "CCC3");
        vm.stopPrank();

        // Verify vested amount is 0
        uint256 vestedAmount = letsCommit.getOrganizerVestedAmount(multiSessionEventId, organizer);
        assertEq(vestedAmount, 0, "Should be no vested amount left");

        // Create a new session event and try to set code without vested amount
        uint256 newEventId = _createTestEvent();
        vm.warp(sessionStartTime + 1 hours);

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NoVestedAmountToRelease.selector));
        letsCommit.setSessionCode(newEventId, 0, "DDD4");
    }

    function testSetSessionCode_Success_CheckAmountChanges() public {
        // Get initial amounts
        uint256 initialVestedAmount = letsCommit.getOrganizerVestedAmount(testEventId, organizer);
        uint256 initialClaimedAmount = letsCommit.getOrganizerClaimedAmount(testEventId, organizer);
        uint256 initialOrganizerBalance = mIDRXToken.balanceOf(organizer);
        uint256 initialContractBalance = mIDRXToken.balanceOf(address(letsCommit));
        uint256 expectedReleaseAmount = _getExpectedVestedAmountPerSession(testEventId);

        // Verify initial state
        assertGt(initialVestedAmount, 0, "Initial vested amount should be greater than 0");
        assertGe(initialVestedAmount, expectedReleaseAmount, "Vested amount should be sufficient");

        vm.warp(sessionStartTime + 1 hours); // Within session time

        vm.prank(organizer);
        bool success = letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
        assertTrue(success);

        // Check amount changes
        uint256 finalVestedAmount = letsCommit.getOrganizerVestedAmount(testEventId, organizer);
        uint256 finalClaimedAmount = letsCommit.getOrganizerClaimedAmount(testEventId, organizer);

        // Check token transfer
        uint256 finalOrganizerBalance = mIDRXToken.balanceOf(organizer);
        uint256 finalContractBalance = mIDRXToken.balanceOf(address(letsCommit));

        assertEq(finalVestedAmount, initialVestedAmount - expectedReleaseAmount, "Vested amount should decrease");
        assertEq(finalClaimedAmount, initialClaimedAmount + expectedReleaseAmount, "Claimed amount should increase");

        assertEq(
            finalOrganizerBalance, initialOrganizerBalance + expectedReleaseAmount, "Organizer should receive tokens"
        );
        assertEq(finalContractBalance, initialContractBalance - expectedReleaseAmount, "Contract should lose tokens");
    }

    function testSetSessionCode_Success_CheckEventEmitted() public {
        uint256 expectedReleaseAmount = _getExpectedVestedAmountPerSession(testEventId);

        vm.warp(sessionStartTime + 1 hours); // Within session time

        // Expect the SetSessionCode event
        vm.expectEmit(true, true, true, true);
        emit IEventIndexer.SetSessionCode({
            eventId: testEventId,
            session: 0,
            organizer: organizer,
            releasedAmount: expectedReleaseAmount
        });

        vm.prank(organizer);
        bool success = letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
        assertTrue(success);
    }

    function testSetSessionCode_Success_MultipleSessions() public {
        uint256 multiSessionEventId = _createEventWithMultipleSessions();

        // Enroll participant to create vested amount
        uint256 totalPayment = PRICE_WITH_DECIMALS + COMMITMENT_WITH_DECIMALS;
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalPayment);

        vm.warp(startSaleDate + 1 hours);
        vm.startPrank(participant);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        letsCommit.enrollEvent(multiSessionEventId);
        vm.stopPrank();

        uint256 initialVestedAmount = letsCommit.getOrganizerVestedAmount(multiSessionEventId, organizer);

        // Set codes for different sessions
        vm.startPrank(organizer);

        // Session 0
        vm.warp(sessionStartTime + 1 hours);
        bool success1 = letsCommit.setSessionCode(multiSessionEventId, 0, "AAA1");
        assertTrue(success1);

        // Session 1
        vm.warp(sessionStartTime + 1 days + 1 hours);
        bool success2 = letsCommit.setSessionCode(multiSessionEventId, 1, "BBB2");
        assertTrue(success2);

        // Session 2
        vm.warp(sessionStartTime + 2 days + 1 hours);
        bool success3 = letsCommit.setSessionCode(multiSessionEventId, 2, "CCC3");
        assertTrue(success3);

        vm.stopPrank();

        // Verify all vested amount is released
        uint256 finalVestedAmount = letsCommit.getOrganizerVestedAmount(multiSessionEventId, organizer);
        uint256 totalClaimed = letsCommit.getOrganizerClaimedAmount(multiSessionEventId, organizer);

        assertEq(finalVestedAmount, 0, "All vested amount should be released");
        assertEq(totalClaimed, initialVestedAmount, "Total claimed should equal initial vested amount");
    }

    function testSetSessionCode_EdgeCase_ExactlyAtSessionBoundaries() public {
        // Test at exact session start time
        vm.warp(sessionStartTime);
        vm.prank(organizer);
        bool successStart = letsCommit.setSessionCode(testEventId, 0, VALID_SESSION_CODE);
        assertTrue(successStart);

        // Reset for next test by creating new event
        uint256 newEventId = _createTestEventWithEnrollment();

        // Test at exact session end time
        vm.warp(sessionEndTime);
        vm.prank(organizer);
        bool successEnd = letsCommit.setSessionCode(newEventId, 0, "XYZ9");
        assertTrue(successEnd);
    }
}
