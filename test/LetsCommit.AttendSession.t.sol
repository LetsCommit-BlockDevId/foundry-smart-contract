// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitAttendSessionTest
 * @dev Unit tests for LetsCommit contract focusing on attendSession function
 */
contract LetsCommitAttendSessionTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken;

    address public deployer = makeAddr("deployer");
    address public organizer = makeAddr("organizer");
    address public participant = makeAddr("participant");
    address public participant2 = makeAddr("participant2");
    address public notEnrolled = makeAddr("notEnrolled");

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
    uint256 public session1StartTime;
    uint256 public session1EndTime;
    uint256 public session2StartTime;
    uint256 public session2EndTime;
    uint256 public session3StartTime;
    uint256 public session3EndTime;

    // Test event ID
    uint256 public testEventId;
    uint256 public multiSessionEventId;

    // Session codes
    string constant SESSION_CODE_1 = "ABC1";
    string constant SESSION_CODE_2 = "DEF2";
    string constant SESSION_CODE_3 = "GHI3";
    string constant WRONG_CODE = "XXXX";

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
        
        // Sessions start after sale period
        session1StartTime = block.timestamp + 10 days;
        session1EndTime = block.timestamp + 11 days;
        session2StartTime = block.timestamp + 12 days;
        session2EndTime = block.timestamp + 13 days;
        session3StartTime = block.timestamp + 14 days;
        session3EndTime = block.timestamp + 15 days;

        // Create test events
        testEventId = _createSingleSessionEvent();
        multiSessionEventId = _createMultiSessionEvent();

        // Mint tokens and setup allowances
        _setupTokensAndAllowances();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function _createSingleSessionEvent() internal returns (uint256 eventId) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = LetsCommit.Session({
            startSessionTime: session1StartTime,
            endSessionTime: session1EndTime
        });

        vm.warp(startSaleDate - 1 hours);
        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE, DESCRIPTION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, 
            startSaleDate, endSaleDate, TAGS, sessions
        );

        require(success, "Single session event creation failed");
        return letsCommit.eventId();
    }

    function _createMultiSessionEvent() internal returns (uint256 eventId) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](3);
        sessions[0] = LetsCommit.Session({
            startSessionTime: session1StartTime,
            endSessionTime: session1EndTime
        });
        sessions[1] = LetsCommit.Session({
            startSessionTime: session2StartTime,
            endSessionTime: session2EndTime
        });
        sessions[2] = LetsCommit.Session({
            startSessionTime: session3StartTime,
            endSessionTime: session3EndTime
        });

        vm.warp(startSaleDate - 1 hours);
        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            "Multi Session Event", DESCRIPTION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, 
            startSaleDate, endSaleDate, TAGS, sessions
        );

        require(success, "Multi session event creation failed");
        return letsCommit.eventId();
    }

    function _setupTokensAndAllowances() internal {
        uint256 totalAmount = (PRICE_WITH_DECIMALS + COMMITMENT_WITH_DECIMALS) * 10; // Extra for multiple enrollments

        // Mint tokens
        vm.prank(deployer);
        mIDRXToken.mint(participant, totalAmount);
        vm.prank(deployer);
        mIDRXToken.mint(participant2, totalAmount);

        // Setup allowances
        vm.prank(participant);
        mIDRXToken.approve(address(letsCommit), totalAmount);
        vm.prank(participant2);
        mIDRXToken.approve(address(letsCommit), totalAmount);
    }

    function _enrollParticipant(uint256 eventId, address user) internal {
        vm.warp(startSaleDate + 1 hours); // Within sale period
        vm.prank(user);
        bool success = letsCommit.enrollEvent(eventId);
        require(success, "Enrollment failed");
    }

    function _setSessionCodeAndMoveToSession(uint256 eventId, uint8 sessionIndex, string memory code) internal {
        // Move to session time and set code
        if (sessionIndex == 0) {
            vm.warp(session1StartTime + 1 hours);
        } else if (sessionIndex == 1) {
            vm.warp(session2StartTime + 1 hours);
        } else if (sessionIndex == 2) {
            vm.warp(session3StartTime + 1 hours);
        }

        vm.prank(organizer);
        bool success = letsCommit.setSessionCode(eventId, sessionIndex, code);
        require(success, "Session code setting failed");
    }

    // ============================================================================
    // TESTS: VALIDATION ERRORS
    // ============================================================================

    function test_RevertWhen_EventDoesNotExist() public {
        uint256 nonExistentEventId = 999;
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, nonExistentEventId));
        vm.prank(participant);
        letsCommit.attendSession(nonExistentEventId, 0, SESSION_CODE_1);
    }

    function test_RevertWhen_SessionIndexInvalid() public {
        _enrollParticipant(testEventId, participant);
        uint8 invalidSessionIndex = 5; // Single session event only has index 0
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InvalidSessionIndex.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, invalidSessionIndex, SESSION_CODE_1);
    }

    function test_RevertWhen_ParticipantNotEnrolled() public {
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.ParticipantNotEnrolled.selector));
        vm.prank(notEnrolled);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
    }

    function test_RevertWhen_SessionCodeNotSet() public {
        _enrollParticipant(testEventId, participant);
        
        vm.warp(session1StartTime + 1 hours); // Within session time but no code set
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.SessionCodeNotSet.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
    }

    function test_RevertWhen_SessionCodeInvalid() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.InvalidSessionCode.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, WRONG_CODE);
    }

    function test_RevertWhen_NotWithinSessionTime_BeforeStart() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        vm.warp(session1StartTime - 1 hours); // Before session starts
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotWithinSessionTime.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
    }

    function test_RevertWhen_NotWithinSessionTime_AfterEnd() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        vm.warp(session1EndTime + 1 hours); // After session ends
        
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.NotWithinSessionTime.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
    }

    function test_RevertWhen_AlreadyAttended() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        // First attendance - should succeed
        vm.prank(participant);
        bool success = letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
        assertTrue(success);
        
        // Second attendance - should fail
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.ParticipantAlreadyAttended.selector));
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
    }

    // ============================================================================
    // TESTS: SUCCESSFUL ATTENDANCE
    // ============================================================================

    function test_AttendSession_Success_SingleSession() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        uint256 participantBalanceBefore = mIDRXToken.balanceOf(participant);
        uint256 contractBalanceBefore = mIDRXToken.balanceOf(address(letsCommit));
        
        // Attend session
        vm.expectEmit(true, true, true, false);
        emit IEventIndexer.AttendEventSession({
            eventId: testEventId,
            session: 0,
            participant: participant,
            attendToken: "" // We'll check this separately
        });
        
        vm.prank(participant);
        bool success = letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
        assertTrue(success);
        
        // Check attendance timestamp is recorded
        uint256 attendanceTime = letsCommit.getParticipantAttendance(testEventId, participant, 0);
        assertEq(attendanceTime, block.timestamp);
        
        // Check attended sessions count increased
        uint8 attendedCount = letsCommit.getParticipantAttendedSessionsCount(testEventId, participant);
        assertEq(attendedCount, 1);
        
        // Check participant received their full commitment fee (single session)
        uint256 expectedReward = COMMITMENT_WITH_DECIMALS; // Full amount for 1 session
        uint256 participantBalanceAfter = mIDRXToken.balanceOf(participant);
        assertEq(participantBalanceAfter, participantBalanceBefore + expectedReward);
        
        // Check contract balance decreased
        uint256 contractBalanceAfter = mIDRXToken.balanceOf(address(letsCommit));
        assertEq(contractBalanceAfter, contractBalanceBefore - expectedReward);
        
        // Check participant's commitment fee is now zero
        uint256 commitmentFeeAfter = letsCommit.getParticipantCommitmentFee(testEventId, participant);
        assertEq(commitmentFeeAfter, 0);
    }

    function test_AttendSession_Success_MultiSession_Partial() public {
        _enrollParticipant(multiSessionEventId, participant);
        _setSessionCodeAndMoveToSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        uint256 participantBalanceBefore = mIDRXToken.balanceOf(participant);
        uint256 commitmentFeeBefore = letsCommit.getParticipantCommitmentFee(multiSessionEventId, participant);
        
        // Attend first session
        vm.prank(participant);
        bool success = letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        assertTrue(success);
        
        // Check attended sessions count
        uint8 attendedCount = letsCommit.getParticipantAttendedSessionsCount(multiSessionEventId, participant);
        assertEq(attendedCount, 1);
        
        // Check participant received 1/3 of their commitment fee
        uint256 expectedReward = COMMITMENT_WITH_DECIMALS / 3; // 1/3 for 3-session event
        uint256 participantBalanceAfter = mIDRXToken.balanceOf(participant);
        assertEq(participantBalanceAfter, participantBalanceBefore + expectedReward);
        
        // Check remaining commitment fee
        uint256 commitmentFeeAfter = letsCommit.getParticipantCommitmentFee(multiSessionEventId, participant);
        assertEq(commitmentFeeAfter, commitmentFeeBefore - expectedReward);
    }

    function test_AttendSession_Success_MultiSession_AllSessions() public {
        _enrollParticipant(multiSessionEventId, participant);
        
        uint256 participantBalanceBefore = mIDRXToken.balanceOf(participant);
        uint256 originalCommitmentFee = letsCommit.getParticipantCommitmentFee(multiSessionEventId, participant);
        
        // Attend session 1
        _setSessionCodeAndMoveToSession(multiSessionEventId, 0, SESSION_CODE_1);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        // Attend session 2
        _setSessionCodeAndMoveToSession(multiSessionEventId, 1, SESSION_CODE_2);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 1, SESSION_CODE_2);
        
        // Attend session 3 (final session - should include any dust)
        _setSessionCodeAndMoveToSession(multiSessionEventId, 2, SESSION_CODE_3);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 2, SESSION_CODE_3);
        
        // Check all sessions attended
        uint8 attendedCount = letsCommit.getParticipantAttendedSessionsCount(multiSessionEventId, participant);
        assertEq(attendedCount, 3);
        
        // Check participant received their full commitment fee (including any dust)
        uint256 participantBalanceAfter = mIDRXToken.balanceOf(participant);
        assertEq(participantBalanceAfter, participantBalanceBefore + originalCommitmentFee);
        
        // Check participant's commitment fee is now zero (no dust remains)
        uint256 commitmentFeeAfter = letsCommit.getParticipantCommitmentFee(multiSessionEventId, participant);
        assertEq(commitmentFeeAfter, 0);
    }

    function test_AttendSession_Success_DifferentParticipants() public {
        // Enroll both participants
        _enrollParticipant(multiSessionEventId, participant);
        _enrollParticipant(multiSessionEventId, participant2);
        
        _setSessionCodeAndMoveToSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        uint256 participant1BalanceBefore = mIDRXToken.balanceOf(participant);
        uint256 participant2BalanceBefore = mIDRXToken.balanceOf(participant2);
        
        // Both attend the same session
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        vm.prank(participant2);
        letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        // Check both have attended 1 session
        assertEq(letsCommit.getParticipantAttendedSessionsCount(multiSessionEventId, participant), 1);
        assertEq(letsCommit.getParticipantAttendedSessionsCount(multiSessionEventId, participant2), 1);
        
        // Check both received the same reward (1/3 of their commitment fee)
        uint256 expectedReward = COMMITMENT_WITH_DECIMALS / 3;
        assertEq(mIDRXToken.balanceOf(participant), participant1BalanceBefore + expectedReward);
        assertEq(mIDRXToken.balanceOf(participant2), participant2BalanceBefore + expectedReward);
    }

    function test_AttendSession_Success_VerifyAttendanceTimestamp() public {
        _enrollParticipant(testEventId, participant);
        _setSessionCodeAndMoveToSession(testEventId, 0, SESSION_CODE_1);
        
        uint256 expectedTimestamp = block.timestamp;
        
        vm.prank(participant);
        letsCommit.attendSession(testEventId, 0, SESSION_CODE_1);
        
        uint256 actualTimestamp = letsCommit.getParticipantAttendance(testEventId, participant, 0);
        assertEq(actualTimestamp, expectedTimestamp);
    }

    // ============================================================================
    // TESTS: EDGE CASES
    // ============================================================================

    function test_AttendSession_Success_DustHandling() public {
        // Create an event where commitment amount doesn't divide evenly by session count
        // Use COMMITMENT_AMOUNT = 500, with 3 sessions = 166.66... per session
        _enrollParticipant(multiSessionEventId, participant);
        
        uint256 originalCommitmentFee = COMMITMENT_WITH_DECIMALS; // 50000 (500 * 100)
        uint256 expectedPerSession = originalCommitmentFee / 3; // 16666 (with remainder 2)
        
        uint256 balanceBefore = mIDRXToken.balanceOf(participant);
        
        // Attend first two sessions
        _setSessionCodeAndMoveToSession(multiSessionEventId, 0, SESSION_CODE_1);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        _setSessionCodeAndMoveToSession(multiSessionEventId, 1, SESSION_CODE_2);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 1, SESSION_CODE_2);
        
        // Check balance after first two sessions
        uint256 balanceAfterTwo = mIDRXToken.balanceOf(participant);
        assertEq(balanceAfterTwo, balanceBefore + (expectedPerSession * 2));
        
        // Attend final session (should include dust)
        _setSessionCodeAndMoveToSession(multiSessionEventId, 2, SESSION_CODE_3);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 2, SESSION_CODE_3);
        
        // Check final balance includes all original commitment fee + dust
        uint256 balanceAfterAll = mIDRXToken.balanceOf(participant);
        assertEq(balanceAfterAll, balanceBefore + originalCommitmentFee);
        
        // Verify no dust remains in participant's commitment fee
        uint256 remainingCommitmentFee = letsCommit.getParticipantCommitmentFee(multiSessionEventId, participant);
        assertEq(remainingCommitmentFee, 0);
    }

    function test_AttendSession_Success_AttendanceFlags() public {
        _enrollParticipant(multiSessionEventId, participant);
        
        // Initially no sessions attended
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 0));
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 1));
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 2));
        
        // Attend session 0
        _setSessionCodeAndMoveToSession(multiSessionEventId, 0, SESSION_CODE_1);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 0, SESSION_CODE_1);
        
        // Check attendance flags
        assertTrue(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 0));
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 1));
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 2));
        
        // Attend session 2 (skip session 1)
        _setSessionCodeAndMoveToSession(multiSessionEventId, 2, SESSION_CODE_3);
        vm.prank(participant);
        letsCommit.attendSession(multiSessionEventId, 2, SESSION_CODE_3);
        
        // Check attendance flags
        assertTrue(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 0));
        assertFalse(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 1));
        assertTrue(letsCommit.hasParticipantAttendedSession(multiSessionEventId, participant, 2));
        
        // Check attended count
        assertEq(letsCommit.getParticipantAttendedSessionsCount(multiSessionEventId, participant), 2);
    }
}
