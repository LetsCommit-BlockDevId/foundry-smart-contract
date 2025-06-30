// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol"; // Import mIDRX token contract if needed

/**
 * @title LetsCommitTest
 * @dev Unit tests for LetsCommit contract focusing on createEvent function
 */
contract LetsCommitTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken; // mIDRX token contract instance
    
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public organizer = makeAddr("organizer");

    // Test data
    string constant TITLE = "Test Event";
    string constant DESCRIPTION = "Test Description";
    string constant IMAGE_URI = "https://example.com/image.jpg";
    uint256 constant PRICE_AMOUNT = 1000;
    uint256 constant COMMITMENT_AMOUNT = 500;
    string[5] TAGS = ["tag1", "tag2", "", "", ""];

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        vm.startPrank(deployer);
        mIDRXToken = new mIDRX(); // Deploy mIDRX token contract
        letsCommit = new LetsCommit(address(mIDRXToken));
        vm.stopPrank();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function createBasicSession() internal view returns (LetsCommit.Session memory) {
        return LetsCommit.Session({
            startSessionTime: block.timestamp + 10 days,
            endSessionTime: block.timestamp + 10 days + 2 hours
        });
    }

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

    // ============================================================================
    // SUCCESS CASES
    // ============================================================================

    function test_CreateEventSuccess() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
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
        
        assertTrue(success);
        assertEq(letsCommit.eventId(), 1);
        
        // Verify event data
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.organizer, organizer);
        assertEq(eventData.priceAmount, PRICE_AMOUNT);
        assertEq(eventData.commitmentAmount, COMMITMENT_AMOUNT);
        assertEq(eventData.totalSession, 2);
        assertEq(eventData.startSaleDate, startSaleDate);
        assertEq(eventData.endSaleDate, endSaleDate);
        assertEq(eventData.lastSessionEndTime, sessions[1].endSessionTime);
    }

    function test_CreateEventWithSingleSession() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(1);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
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
        
        assertTrue(success);
        
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.totalSession, 1);
        assertEq(eventData.lastSessionEndTime, sessions[0].endSessionTime);
        
        // Verify session data
        LetsCommit.Session memory sessionData = letsCommit.getSession(1, 0);
        assertEq(sessionData.startSessionTime, sessions[0].startSessionTime);
        assertEq(sessionData.endSessionTime, sessions[0].endSessionTime);
    }

    function test_CreateEventWithMaxSessions() public {
        uint8 maxSessions = letsCommit.maxSessionsPerEvent();
        LetsCommit.Session[] memory sessions = createMultipleSessions(maxSessions);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
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
        
        assertTrue(success);
        
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.totalSession, maxSessions);
        assertEq(eventData.lastSessionEndTime, sessions[maxSessions - 1].endSessionTime);
    }

    function test_CreateEventWithZeroPriceAmount() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            0, // Zero price amount
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
        assertTrue(success);
        
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.priceAmount, 0);
        assertEq(eventData.commitmentAmount, COMMITMENT_AMOUNT);
    }

    function test_CreateEventWithZeroCommitmentAmount() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            0, // Zero commitment amount
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
        assertTrue(success);
        
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.priceAmount, PRICE_AMOUNT);
        assertEq(eventData.commitmentAmount, 0);
    }

    function test_CreateEventWithBothAmountsZero() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            0, // Zero price amount
            0, // Zero commitment amount
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
        assertTrue(success);
        
        LetsCommit.Event memory eventData = letsCommit.getEvent(1);
        assertEq(eventData.priceAmount, 0);
        assertEq(eventData.commitmentAmount, 0);
    }

    // ============================================================================
    // REVERT CASES - DATE VALIDATION
    // ============================================================================

    function test_RevertWhen_StartSaleDateInPast() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        // Set a future timestamp for our test
        uint256 futureTime = block.timestamp + 10 days;
        vm.warp(futureTime);
        
        // Now set sale dates relative to the new "current" time
        uint256 startSaleDate = futureTime - 1 days; // Past date (1 day ago)
        uint256 endSaleDate = futureTime + 7 days;   // Future date
        
        vm.prank(organizer);
        vm.expectRevert(LetsCommit.StartSaleDateInPast.selector);
        letsCommit.createEvent(
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
    }

    function test_RevertWhen_EndSaleDateInPast() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        // Set a future timestamp for our test
        uint256 futureTime = block.timestamp + 10 days;
        vm.warp(futureTime);
        
        // Now set sale dates relative to the new "current" time
        uint256 startSaleDate = futureTime + 1 days;  // Future date
        uint256 endSaleDate = futureTime - 1 days;    // Past date (1 day ago)
        
        vm.prank(organizer);
        vm.expectRevert(LetsCommit.EndSaleDateInPast.selector);
        letsCommit.createEvent(
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
    }

    function test_RevertWhen_InvalidSaleDateRange() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 7 days;
        uint256 endSaleDate = block.timestamp + 1 days; // End before start
        
        vm.prank(organizer);
        vm.expectRevert(LetsCommit.InvalidSaleDateRange.selector);
        letsCommit.createEvent(
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
    }

    // ============================================================================
    // REVERT CASES - SESSION VALIDATION
    // ============================================================================

    function test_RevertWhen_TotalSessionsZero() public {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](0); // Empty array
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        vm.expectRevert(LetsCommit.TotalSessionsZero.selector);
        letsCommit.createEvent(
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
    }

    function test_RevertWhen_TotalSessionsExceedsMax() public {
        uint8 maxSessions = letsCommit.maxSessionsPerEvent();
        LetsCommit.Session[] memory sessions = createMultipleSessions(maxSessions + 1); // Exceed max
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        vm.expectRevert(
            abi.encodeWithSelector(
                LetsCommit.TotalSessionsExceedsMax.selector,
                maxSessions + 1,
                maxSessions
            )
        );
        letsCommit.createEvent(
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
    }

    function test_RevertWhen_LastSessionMustBeAfterSaleEnd() public {
        // Create session that ends before sale period ends
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = LetsCommit.Session({
            startSessionTime: block.timestamp + 2 days,
            endSessionTime: block.timestamp + 5 days // Ends before sale end date
        });
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days; // Sale ends after session
        
        vm.prank(organizer);
        vm.expectRevert(LetsCommit.LastSessionMustBeAfterSaleEnd.selector);
        letsCommit.createEvent(
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
    }

    // ============================================================================
    // EVENT EMISSION TESTS
    // ============================================================================

    function test_CreateEventEmitsCorrectEvents() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        // Expect CreateEvent emission
        vm.expectEmit(true, false, false, true);
        emit IEventIndexer.CreateEvent(
            1, // eventId
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            2, // totalSession
            startSaleDate,
            endSaleDate,
            organizer,
            TAGS
        );
        
        // Expect CreateSession emissions
        vm.expectEmit(true, true, false, true);
        emit IEventIndexer.CreateSession(
            1, // eventId
            0, // session index
            "Session 1",
            sessions[0].startSessionTime,
            sessions[0].endSessionTime
        );
        
        vm.expectEmit(true, true, false, true);
        emit IEventIndexer.CreateSession(
            1, // eventId
            1, // session index
            "Session 2",
            sessions[1].startSessionTime,
            sessions[1].endSessionTime
        );
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
    }

    // ============================================================================
    // ADMIN FUNCTION TESTS - setMaxSessionsPerEvent
    // ============================================================================

    function test_SetMaxSessionsPerEvent_ProtocolAdminCanChange() public {
        uint8 newMaxSessions = 20;
        
        // Check initial value
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
        assertEq(letsCommit.protocolAdmin(), deployer);
        
        // Protocol admin (deployer) should be able to change it
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(newMaxSessions);
        
        // Verify the change
        assertEq(letsCommit.maxSessionsPerEvent(), newMaxSessions);
    }

    function test_RevertWhen_NonProtocolAdminTriesToChangeMaxSessions() public {
        uint8 newMaxSessions = 20;
        
        // Non-admin user tries to change max sessions
        vm.prank(alice);
        vm.expectRevert(LetsCommit.NotProtocolAdmin.selector);
        letsCommit.setMaxSessionsPerEvent(newMaxSessions);
        
        // Verify no change occurred
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
    }

    function test_RevertWhen_SetMaxSessionsToZero() public {
        // Protocol admin tries to set max sessions to zero
        vm.prank(deployer);
        vm.expectRevert(LetsCommit.MaxSessionsZero.selector);
        letsCommit.setMaxSessionsPerEvent(0);
        
        // Verify no change occurred
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
    }

    function test_SetMaxSessionsPerEvent_EdgeCases() public {
        // Test setting to 1 (minimum valid value)
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(1);
        assertEq(letsCommit.maxSessionsPerEvent(), 1);
        
        // Test setting to maximum uint8 value
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(255);
        assertEq(letsCommit.maxSessionsPerEvent(), 255);
    }

    function test_SetMaxSessionsPerEvent_AffectsEventCreation() public {
        // Reduce max sessions to 2
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(2);
        
        // Creating event with 2 sessions should work
        LetsCommit.Session[] memory sessions2 = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
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
            sessions2
        );
        assertTrue(success);
        
        // Creating event with 3 sessions should fail
        LetsCommit.Session[] memory sessions3 = createMultipleSessions(3);
        
        vm.prank(organizer);
        vm.expectRevert(
            abi.encodeWithSelector(
                LetsCommit.TotalSessionsExceedsMax.selector,
                3,
                2
            )
        );
        letsCommit.createEvent(
            "Event 2",
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions3
        );
    }

    // ============================================================================
    // MULTIPLE EVENTS TESTS
    // ============================================================================

    function test_CreateMultipleEvents() public {
        LetsCommit.Session[] memory sessions1 = createMultipleSessions(1);
        LetsCommit.Session[] memory sessions2 = createMultipleSessions(3);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        // Create first event
        vm.prank(alice);
        letsCommit.createEvent(
            "Event 1",
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions1
        );
        
        // Create second event
        vm.prank(bob);
        letsCommit.createEvent(
            "Event 2",
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT * 2,
            COMMITMENT_AMOUNT * 2,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions2
        );
        
        assertEq(letsCommit.eventId(), 2);
        
        // Verify first event
        LetsCommit.Event memory event1 = letsCommit.getEvent(1);
        assertEq(event1.organizer, alice);
        assertEq(event1.totalSession, 1);
        
        // Verify second event
        LetsCommit.Event memory event2 = letsCommit.getEvent(2);
        assertEq(event2.organizer, bob);
        assertEq(event2.totalSession, 3);
        assertEq(event2.priceAmount, PRICE_AMOUNT * 2);
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_RevertWhen_GetNonExistentEvent() public {
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999)
        );
        letsCommit.getEvent(999);
    }

    function test_GetSessionData() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        
        // Test getting session data
        LetsCommit.Session memory session0 = letsCommit.getSession(1, 0);
        assertEq(session0.startSessionTime, sessions[0].startSessionTime);
        assertEq(session0.endSessionTime, sessions[0].endSessionTime);
        
        LetsCommit.Session memory session1 = letsCommit.getSession(1, 1);
        assertEq(session1.startSessionTime, sessions[1].startSessionTime);
        assertEq(session1.endSessionTime, sessions[1].endSessionTime);
    }

    // ============================================================================
    // ENROLL EVENT TESTS
    // ============================================================================

    function test_EnrollEventSuccess() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        vm.warp(startSaleDate + 1 hours);
        
        // Test enrollment
        vm.expectEmit(true, true, false, true);
        emit IEventIndexer.EnrollEvent(1, alice, totalPayment);
        
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(1);
        
        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(1, alice), commitmentFeeWithDecimals);
        
        // Check organizer balances
        uint256 expectedClaimable = eventFeeWithDecimals / 2;
        uint256 expectedVested = eventFeeWithDecimals - expectedClaimable;
        assertEq(letsCommit.getOrganizerClaimableAmount(1, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(1, organizer), expectedVested);
        
        // Check token balance transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment);
        assertEq(mIDRXToken.balanceOf(alice), 0);
    }

    function test_RevertWhen_EnrollNonExistentEvent() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999)
        );
        letsCommit.enrollEvent(999);
    }

    function test_RevertWhen_ParticipantAlreadyEnrolled() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        
        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        
        // Mint tokens to alice and approve double amount
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment * 2);
        
        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment * 2);
        
        // Move to sale period
        vm.warp(startSaleDate + 1 hours);
        
        // First enrollment - should succeed
        vm.prank(alice);
        letsCommit.enrollEvent(1);
        
        // Second enrollment - should revert
        vm.prank(alice);
        vm.expectRevert(LetsCommit.ParticipantAlreadyEnrolled.selector);
        letsCommit.enrollEvent(1);
    }

    function test_RevertWhen_EnrollEventSaleNotStarted() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        letsCommit.enrollEvent(1);
    }

    function test_RevertWhen_EnrollEventSaleFinished() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        
        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        
        // Mint tokens to alice and approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);
        
        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);
        
        // Move to after sale period ends
        vm.warp(endSaleDate + 1 hours);
        
        // Try to enroll after sale ends
        vm.prank(alice);
        vm.expectRevert(LetsCommit.EventNotInSalePeriod.selector);
        letsCommit.enrollEvent(1);
    }

    function test_RevertWhen_UserNotApprovedContract() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        
        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);
        
        // Mint tokens to alice but DON'T approve
        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);
        
        // Move to sale period
        vm.warp(startSaleDate + 1 hours);
        
        // Try to enroll without approval
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.InsufficientAllowance.selector, totalPayment, 0)
        );
        letsCommit.enrollEvent(1);
    }

    function test_RevertWhen_UserApprovedInsufficientAmount() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        vm.warp(startSaleDate + 1 hours);
        
        // Try to enroll with insufficient approval
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.InsufficientAllowance.selector, totalPayment, insufficientApproval)
        );
        letsCommit.enrollEvent(1);
    }

    function test_EnrollEventWithMoreThanNeededApproval() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        vm.warp(startSaleDate + 1 hours);
        
        // Enrollment should succeed even with excess approval
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(1);
        
        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        
        // Check that only the required amount was transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment);
        assertEq(mIDRXToken.balanceOf(alice), excessiveApproval - totalPayment);
        
        // Check remaining allowance
        assertEq(mIDRXToken.allowance(alice, address(letsCommit)), excessiveApproval - totalPayment);
    }

    function test_RevertWhen_UserInsufficientTokenBalance() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        vm.warp(startSaleDate + 1 hours);
        
        // Try to enroll with insufficient balance - should revert with specific error
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                LetsCommit.InsufficientBalance.selector,
                totalPayment,
                insufficientBalance
            )
        );
        letsCommit.enrollEvent(1);
    }

    function test_EnrollEventWithZeroCommitmentFee() public {
        // Create an event with zero commitment fee
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            0, // Zero commitment amount
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
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
        vm.warp(startSaleDate + 1 hours);
        
        // Enrollment should succeed
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(1);
        
        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(1, alice), 0);
        
        // Check organizer balances (only from event fee)
        uint256 expectedClaimable = eventFeeWithDecimals / 2;
        uint256 expectedVested = eventFeeWithDecimals - expectedClaimable;
        assertEq(letsCommit.getOrganizerClaimableAmount(1, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(1, organizer), expectedVested);
    }

    function test_EnrollEventWithZeroEventFee() public {
        // Create an event with zero event fee
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            0, // Zero price amount
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
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
        vm.warp(startSaleDate + 1 hours);
        
        // Enrollment should succeed
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(1);
        
        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(1, alice), commitmentFeeWithDecimals);
        
        // Check organizer balances (should be zero since no event fee)
        assertEq(letsCommit.getOrganizerClaimableAmount(1, organizer), 0);
        assertEq(letsCommit.getOrganizerVestedAmount(1, organizer), 0);
    }

    function test_EnrollEventWithBothFeesZero() public {
        // Create an event with both fees as zero
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
            TITLE,
            DESCRIPTION,
            IMAGE_URI,
            0, // Zero price amount
            0, // Zero commitment amount
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions
        );
        
        // Don't need to mint or approve any tokens
        
        // Move to sale period
        vm.warp(startSaleDate + 1 hours);
        
        // Enrollment should succeed even with zero payment
        vm.prank(alice);
        bool success = letsCommit.enrollEvent(1);
        
        assertTrue(success);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        assertEq(letsCommit.getParticipantCommitmentFee(1, alice), 0);
        
        // Check organizer balances (should be zero)
        assertEq(letsCommit.getOrganizerClaimableAmount(1, organizer), 0);
        assertEq(letsCommit.getOrganizerVestedAmount(1, organizer), 0);
        
        // Check no tokens were transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), 0);
    }

    function test_EnrollEventMultipleParticipants() public {
        // Create an event first
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;
        
        vm.prank(organizer);
        letsCommit.createEvent(
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
        vm.warp(startSaleDate + 1 hours);
        
        // Both should be able to enroll
        vm.prank(alice);
        bool successAlice = letsCommit.enrollEvent(1);
        
        vm.prank(bob);
        bool successBob = letsCommit.enrollEvent(1);
        
        assertTrue(successAlice);
        assertTrue(successBob);
        assertTrue(letsCommit.isParticipantEnrolled(1, alice));
        assertTrue(letsCommit.isParticipantEnrolled(1, bob));
        
        // Check organizer balances (should be doubled from two participants)
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 expectedClaimable = (eventFeeWithDecimals / 2) * 2; // From both participants
        uint256 expectedVested = (eventFeeWithDecimals - (eventFeeWithDecimals / 2)) * 2;
        assertEq(letsCommit.getOrganizerClaimableAmount(1, organizer), expectedClaimable);
        assertEq(letsCommit.getOrganizerVestedAmount(1, organizer), expectedVested);
        
        // Check total tokens transferred
        assertEq(mIDRXToken.balanceOf(address(letsCommit)), totalPayment * 2);
    }
}
