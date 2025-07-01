// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitCreateEventTest
 * @dev Unit tests for LetsCommit contract focusing on createEvent function
 */
contract LetsCommitCreateEventTest is Test {
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
    uint8 constant MAX_PARTICIPANT = 50;
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
            LOCATION,
            IMAGE_URI,
            0, // Zero price amount
            COMMITMENT_AMOUNT,
            MAX_PARTICIPANT,
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
            LOCATION,
            IMAGE_URI,
            PRICE_AMOUNT,
            0, // Zero commitment amount
            MAX_PARTICIPANT,
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
            LOCATION,
            IMAGE_URI,
            0, // Zero price amount
            0, // Zero commitment amount
            MAX_PARTICIPANT,
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
            LOCATION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            MAX_PARTICIPANT,
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
            LOCATION,
            IMAGE_URI,
            PRICE_AMOUNT * 2,
            COMMITMENT_AMOUNT * 2,
            MAX_PARTICIPANT,
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
    // REVERT CASES - DATE VALIDATION
    // ============================================================================

    function test_RevertWhen_StartSaleDateInPast() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);

        // Set a future timestamp for our test
        uint256 futureTime = block.timestamp + 10 days;
        vm.warp(futureTime);

        // Now set sale dates relative to the new "current" time
        uint256 startSaleDate = futureTime - 1 days; // Past date (1 day ago)
        uint256 endSaleDate = futureTime + 7 days; // Future date

        vm.prank(organizer);
        vm.expectRevert(LetsCommit.StartSaleDateInPast.selector);
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );
    }

    function test_RevertWhen_EndSaleDateInPast() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);

        // Set a future timestamp for our test
        uint256 futureTime = block.timestamp + 10 days;
        vm.warp(futureTime);

        // Now set sale dates relative to the new "current" time
        uint256 startSaleDate = futureTime + 1 days; // Future date
        uint256 endSaleDate = futureTime - 1 days; // Past date (1 day ago)

        vm.prank(organizer);
        vm.expectRevert(LetsCommit.EndSaleDateInPast.selector);
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );
    }

    function test_RevertWhen_InvalidSaleDateRange() public {
        LetsCommit.Session[] memory sessions = createMultipleSessions(2);

        uint256 startSaleDate = block.timestamp + 7 days;
        uint256 endSaleDate = block.timestamp + 1 days; // End before start

        vm.prank(organizer);
        vm.expectRevert(LetsCommit.InvalidSaleDateRange.selector);
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );
    }

    function test_RevertWhen_TotalSessionsExceedsMax() public {
        uint8 maxSessions = letsCommit.maxSessionsPerEvent();
        LetsCommit.Session[] memory sessions = createMultipleSessions(maxSessions + 1); // Exceed max

        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;

        vm.prank(organizer);
        vm.expectRevert(
            abi.encodeWithSelector(LetsCommit.TotalSessionsExceedsMax.selector, maxSessions + 1, maxSessions)
        );
        letsCommit.createEvent(
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
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
        vm.expectEmit(true, true, false, true);
        emit IEventIndexer.CreateEvent(
            1, // eventId
            organizer, // organizer
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            2, // totalSession
            MAX_PARTICIPANT,
            startSaleDate,
            endSaleDate
        );

        // Expect CreateEventMetadata emission
        vm.expectEmit(true, false, false, true);
        emit IEventIndexer.CreateEventMetadata(
            1, // eventId
            TITLE,
            DESCRIPTION,
            LOCATION,
            IMAGE_URI,
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
            TITLE, DESCRIPTION, LOCATION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, MAX_PARTICIPANT, startSaleDate, endSaleDate, TAGS, sessions
        );
    }
}
