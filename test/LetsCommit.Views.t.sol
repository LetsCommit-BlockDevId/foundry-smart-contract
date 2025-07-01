// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitViewsTest
 * @dev Unit tests for LetsCommit contract focusing on view functions
 */
contract LetsCommitViewsTest is Test {
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

    function createMultipleSessions(uint8 count) internal view returns (LetsCommit.Session[] memory) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](count);

        for (uint8 i = 0; i < count; i++) {
            sessions[i] = LetsCommit.Session({
                startSessionTime: block.timestamp + 10 days + (i * 1 days),
                endSessionTime: block.timestamp + 10 days + (i * 1 days) + 2 hours,
                attendedCount: 0
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

        return 1; // First event ID
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_RevertWhen_GetNonExistentEvent() public {
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getEvent(999);
    }

    function test_GetEventData() public {
        uint256 eventId = createTestEvent();

        LetsCommit.Event memory eventData = letsCommit.getEvent(eventId);

        assertEq(eventData.organizer, organizer);
        assertEq(eventData.priceAmount, PRICE_AMOUNT);
        assertEq(eventData.commitmentAmount, COMMITMENT_AMOUNT);
        assertEq(eventData.totalSession, 2);
        assertEq(eventData.startSaleDate, block.timestamp + 1 days);
        assertEq(eventData.endSaleDate, block.timestamp + 7 days);
    }

    function test_GetSessionData() public {
        uint256 eventId = createTestEvent();
        LetsCommit.Session[] memory originalSessions = createMultipleSessions(2);

        // Test getting session data
        LetsCommit.Session memory session0 = letsCommit.getSession(eventId, 0);
        assertEq(session0.startSessionTime, originalSessions[0].startSessionTime);
        assertEq(session0.endSessionTime, originalSessions[0].endSessionTime);

        LetsCommit.Session memory session1 = letsCommit.getSession(eventId, 1);
        assertEq(session1.startSessionTime, originalSessions[1].startSessionTime);
        assertEq(session1.endSessionTime, originalSessions[1].endSessionTime);
    }

    function test_IsParticipantEnrolled() public {
        uint256 eventId = createTestEvent();

        // Before enrollment
        assertFalse(letsCommit.isParticipantEnrolled(eventId, alice));

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period and enroll
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // After enrollment
        assertTrue(letsCommit.isParticipantEnrolled(eventId, alice));
        assertFalse(letsCommit.isParticipantEnrolled(eventId, bob)); // Bob hasn't enrolled
    }

    function test_GetParticipantCommitmentFee() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 commitmentFeeWithDecimals = COMMITMENT_AMOUNT * (10 ** tokenDecimals);
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = commitmentFeeWithDecimals + eventFeeWithDecimals;

        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Before enrollment
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), 0);

        // Move to sale period and enroll
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // After enrollment
        assertEq(letsCommit.getParticipantCommitmentFee(eventId, alice), commitmentFeeWithDecimals);
    }

    function test_GetOrganizerClaimableAmount() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Before enrollment
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), 0);

        // Move to sale period and enroll
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // After enrollment
        uint256 expectedClaimable = eventFeeWithDecimals / 2;
        assertEq(letsCommit.getOrganizerClaimableAmount(eventId, organizer), expectedClaimable);
    }

    function test_GetOrganizerVestedAmount() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 eventFeeWithDecimals = PRICE_AMOUNT * (10 ** tokenDecimals);
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Before enrollment
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), 0);

        // Move to sale period and enroll
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // After enrollment
        uint256 expectedVested = eventFeeWithDecimals - (eventFeeWithDecimals / 2);
        assertEq(letsCommit.getOrganizerVestedAmount(eventId, organizer), expectedVested);
    }

    function test_GetParticipantAttendance() public {
        uint256 eventId = createTestEvent();

        // Setup for enrollment
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 totalPayment = (COMMITMENT_AMOUNT + PRICE_AMOUNT) * (10 ** tokenDecimals);

        vm.prank(deployer);
        mIDRXToken.mint(alice, totalPayment);

        vm.prank(alice);
        mIDRXToken.approve(address(letsCommit), totalPayment);

        // Move to sale period and enroll
        vm.warp(block.timestamp + 1 days + 1 hours);

        vm.prank(alice);
        letsCommit.enrollEvent(eventId);

        // Check attendance (should be 0 initially since no attendance recorded)
        assertEq(letsCommit.getParticipantAttendance(eventId, alice, 0), 0);
        assertEq(letsCommit.getParticipantAttendance(eventId, alice, 1), 0);
    }

    function test_ViewFunctionsWithMultipleEvents() public {
        // Create first event
        uint256 event1Id = createTestEvent();

        // Create second event with different organizer
        LetsCommit.Session[] memory sessions = createMultipleSessions(1);
        uint256 startSaleDate = block.timestamp + 2 days;
        uint256 endSaleDate = block.timestamp + 8 days;

        vm.prank(alice);
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
            sessions
        );
        uint256 event2Id = 2;

        // Test that view functions return correct data for each event
        LetsCommit.Event memory event1Data = letsCommit.getEvent(event1Id);
        LetsCommit.Event memory event2Data = letsCommit.getEvent(event2Id);

        assertEq(event1Data.organizer, organizer);
        assertEq(event1Data.priceAmount, PRICE_AMOUNT);
        assertEq(event1Data.totalSession, 2);

        assertEq(event2Data.organizer, alice);
        assertEq(event2Data.priceAmount, PRICE_AMOUNT * 2);
        assertEq(event2Data.totalSession, 1);

        // Test organizer balances are separate
        assertEq(letsCommit.getOrganizerClaimableAmount(event1Id, organizer), 0);
        assertEq(letsCommit.getOrganizerClaimableAmount(event2Id, alice), 0);
        assertEq(letsCommit.getOrganizerClaimableAmount(event1Id, alice), 0); // Alice not organizer of event1
        assertEq(letsCommit.getOrganizerClaimableAmount(event2Id, organizer), 0); // Organizer not organizer of event2
    }

    function test_ViewFunctionsNonExistentEventRevert() public {
        createTestEvent();

        // All view functions should revert for non-existent events
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getEvent(999);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getSession(999, 0);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.isParticipantEnrolled(999, alice);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getParticipantCommitmentFee(999, alice);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getOrganizerClaimableAmount(999, organizer);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getOrganizerVestedAmount(999, organizer);

        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, 999));
        letsCommit.getParticipantAttendance(999, alice, 0);
    }
}
