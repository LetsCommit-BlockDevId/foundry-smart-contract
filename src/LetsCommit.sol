// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IEventIndexer} from "./interfaces/IEventIndexer.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title LetsCommit
 * @dev Smart contract for managing events with commitment-based participation
 */
contract LetsCommit is IEventIndexer {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @dev Protocol admin, we can use ownable pattern in the future
    address public protocolAdmin;

    /// @dev Maximum number of sessions allowed per event
    uint8 public maxSessionsPerEvent = 12;

    /// @dev Counter for event IDs
    uint256 public eventId;

    /// @dev Counter for claim events (temporary - should be removed in final implementation)
    uint256 public eventIdClaim;

    /// @dev Counter for enrollment events (temporary - should be removed in final implementation)
    uint256 public eventIdEnroll;

    // ============================================================================
    // STORAGE MAPPINGS
    // ============================================================================

    /// @dev Storage for events
    mapping(uint256 => Event) public events;
    
    /// @dev Storage for sessions: eventId => sessionIndex => Session
    mapping(uint256 => mapping(uint8 => Session)) public sessions;
    
    // TODO: Add storage for participants
    // mapping(uint256 => mapping(address => Participant)) public participants;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @dev Event data structure for on-chain storage
    struct Event {
        address organizer;
        uint256 priceAmount;
        uint256 commitmentAmount;
        uint8 totalSession;
        uint256 startSaleDate;
        uint256 endSaleDate;
        uint256 lastSessionEndTime; // End time of the last session
    }

    /// @dev Session data structure for on-chain storage
    struct Session {
        uint256 startSessionTime;
        uint256 endSessionTime;
    }

    // TODO: Define Participant struct
    // struct Participant {
    //     bool enrolled;
    //     uint256 debitAmount;
    //     mapping(uint8 => bool) attendance;
    // }

    // ============================================================================
    // EVENTS (Inherited from IEventIndexer)
    // ============================================================================

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @dev Error thrown when start sale date is in the past
    error StartSaleDateInPast();

    /// @dev Error thrown when end sale date is in the past
    error EndSaleDateInPast();

    /// @dev Error thrown when start sale date is after end sale date
    error InvalidSaleDateRange();

    /// @dev Error thrown when total sessions is zero
    error TotalSessionsZero();

    /// @dev Error thrown when total sessions exceeds maximum allowed
    error TotalSessionsExceedsMax(uint8 requested, uint8 max);

    /// @dev Error thrown when caller is not protocol admin
    error NotProtocolAdmin();

    /// @dev Error thrown when event does not exist
    error EventDoesNotExist(uint256 eventId);

    /// @dev Error thrown when new max sessions is zero
    error MaxSessionsZero();

    /// @dev Error thrown when last session end time is not after end sale date
    error LastSessionMustBeAfterSaleEnd();

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /// @dev Modifier to restrict access to protocol admin only
    modifier onlyProtocolAdmin() {
        if (msg.sender != protocolAdmin) revert NotProtocolAdmin();
        _;
    }

    /// @dev Modifier to check if event exists
    modifier eventExists(uint256 _eventId) {
        if (_eventId == 0 || _eventId > eventId) revert EventDoesNotExist(_eventId);
        _;
    }

    // TODO: Add modifiers for access control
    // modifier onlyOrganizer(uint256 _eventId) {
    //     require(events[_eventId].organizer == msg.sender, "Not the organizer");
    //     _;
    // }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor() {
        protocolAdmin = msg.sender;
    }

    // ============================================================================
    // EXTERNAL FUNCTIONS
    // ============================================================================

    /**
     * @dev Creates a new event with sessions
     * @param title The title of the event
     * @param description The description of the event
     * @param imageUri The image URI for the event
     * @param priceAmount The price amount for participating in the event
     * @param commitmentAmount The commitment amount participants must stake
     * @param startSaleDate The timestamp when sale starts
     * @param endSaleDate The timestamp when sale ends
     * @param tags Array of tags for the event
     * @param _sessions Array of session parameters
     * @return success True if event creation was successful
     */
    function createEvent(
        string calldata title,
        string calldata description,
        string calldata imageUri,
        uint256 priceAmount,
        uint256 commitmentAmount,
        uint256 startSaleDate,
        uint256 endSaleDate,
        string[5] calldata tags,
        Session[] calldata _sessions
    ) external returns (bool success) {
        // CHECKS: Validate all input parameters
        if (startSaleDate < block.timestamp) revert StartSaleDateInPast();
        if (endSaleDate < block.timestamp) revert EndSaleDateInPast();
        if (startSaleDate > endSaleDate) revert InvalidSaleDateRange();
        
        // Validate session count
        uint8 totalSession = uint8(_sessions.length);
        if (totalSession == 0) revert TotalSessionsZero();
        if (totalSession > maxSessionsPerEvent) revert TotalSessionsExceedsMax(totalSession, maxSessionsPerEvent);

        // Find the last session end time (assuming sessions are ordered)
        uint256 lastSessionEndTime = _sessions[totalSession - 1].endSessionTime;
        
        // Validate that last session ends after sale period
        if (lastSessionEndTime <= endSaleDate) revert LastSessionMustBeAfterSaleEnd();
        
        // EFFECTS & INTERACTIONS: Create the event
        return _createEvent(
            title,
            description,
            imageUri,
            priceAmount,
            commitmentAmount,
            startSaleDate,
            endSaleDate,
            tags,
            _sessions
        );
    }

    /**
     * @dev Sets the maximum number of sessions per event (admin only)
     * @param newMaxSessions The new maximum number of sessions
     */
    function setMaxSessionsPerEvent(uint8 newMaxSessions) external onlyProtocolAdmin {
        if (newMaxSessions == 0) revert MaxSessionsZero();
        maxSessionsPerEvent = newMaxSessions;
    }

    /**
     * @dev Enrolls a participant in an event
     * @return success True if enrollment was successful
     * TODO: Add proper parameters and implementation
     */
    function enrollEvent() external returns (bool success) {
        // TODO: Implement enrollment logic
        emit EnrollEvent({
            eventId: ++eventIdEnroll,
            participant: address(0x1), // TODO: Use msg.sender
            debitAmount: 10_000
        });

        return true;
    }

    /**
     * @dev Records attendance for a session
     * @return success True if attendance recording was successful
     * TODO: Add proper parameters and implementation
     */
    function attendSession() external returns (bool success) {
        // TODO: Implement attendance logic
        emit AttendEventSession({
            eventId: eventIdEnroll,
            session: 1,
            participant: address(0x1), // TODO: Use msg.sender
            attendToken: abi.encodePacked(block.timestamp, uint8(1))
        });

        return true;
    }

    /**
     * @dev Allows organizer to claim first portion of earnings
     * @return success True if claim was successful
     * TODO: Add proper parameters and implementation
     */
    function claimFirstPortion() external returns (bool success) {
        // TODO: Implement proper claim logic
        emit OrganizerFirstClaim({
            eventId: ++eventIdClaim,
            organizer: address(0x0), // TODO: Use msg.sender
            claimAmount: 10_000 / 2
        });

        return true;
    }

    /**
     * @dev Allows organizer to claim final portion of earnings
     * @return success True if claim was successful
     * TODO: Add proper parameters and implementation
     */
    function claimFinalPortion() external returns (bool success) {
        // TODO: Implement proper claim logic
        emit OrganizerLastClaim({
            eventId: eventIdClaim,
            organizer: address(0x0), // TODO: Use msg.sender
            claimAmount: 10_000 / 2
        });

        return true;
    }

    /**
     * @dev Allows organizer to claim commitment fees from unattended participants
     * @return success True if claim was successful
     * TODO: Add proper parameters and implementation
     */
    function claimUnattendedFees() external returns (bool success) {
        // TODO: Implement proper claim logic
        emit OrganizerClaimUnattended({
            eventId: eventIdEnroll,
            session: 1,
            unattendedPerson: 3,
            organizer: address(0x0), // TODO: Use msg.sender
            claimAmount: 100
        });

        return true;
    }

    // ============================================================================
    // PUBLIC FUNCTIONS (Legacy - TODO: Refactor or remove)
    // ============================================================================

    /**
     * @dev Legacy function - should be refactored into separate functions
     * TODO: Remove this function and use individual functions above
     */
    function claim() public returns (bool) {
        emit OrganizerFirstClaim({
            eventId: ++eventIdClaim,
            organizer: address(0x0),
            claimAmount: 10_000 / 2
        });

        emit OrganizerLastClaim({
            eventId: eventIdClaim,
            organizer: address(0x0),
            claimAmount: 10_000 / 2
        });

        return true;
    }

    /**
     * @dev Legacy function - should be refactored into separate functions
     * TODO: Remove this function and use individual functions above
     */
    function enrollAndAttend() public returns (bool) {
        emit EnrollEvent({
            eventId: ++eventIdEnroll,
            participant: address(0x1),
            debitAmount: 10_000
        });

        emit AttendEventSession({
            eventId: eventIdEnroll,
            session: 1,
            participant: address(0x1),
            attendToken: abi.encodePacked(block.timestamp, uint8(1))
        });

        emit OrganizerClaimUnattended({
            eventId: eventIdEnroll,
            session: 1,
            unattendedPerson: 3,
            organizer: address(0x0),
            claimAmount: 100
        });

        return true;
    }

    // ============================================================================
    // INTERNAL FUNCTIONS
    // ============================================================================

    /**
     * @dev Internal function to create event (EFFECTS & INTERACTIONS phase of CEI pattern)
     * @param title The title of the event
     * @param description The description of the event
     * @param imageUri The image URI for the event
     * @param priceAmount The price amount for participating in the event
     * @param commitmentAmount The commitment amount participants must stake
     * @param startSaleDate The timestamp when sale starts
     * @param endSaleDate The timestamp when sale ends
     * @param tags Array of tags for the event
     * @param _sessions Array of session parameters
     * @return success True if event creation was successful
     */
    function _createEvent(
        string calldata title,
        string calldata description,
        string calldata imageUri,
        uint256 priceAmount,
        uint256 commitmentAmount,
        uint256 startSaleDate,
        uint256 endSaleDate,
        string[5] calldata tags,
        Session[] calldata _sessions
    ) internal returns (bool success) {
        // EFFECTS: Update contract state
        uint8 totalSession = uint8(_sessions.length);
        uint256 lastSessionEndTime = _sessions[totalSession - 1].endSessionTime;
        
        // Increment event ID and store event data
        uint256 newEventId = ++eventId;
        
        // Store important data on-chain
        events[newEventId] = Event({
            organizer: msg.sender,
            priceAmount: priceAmount,
            commitmentAmount: commitmentAmount,
            totalSession: totalSession,
            startSaleDate: startSaleDate,
            endSaleDate: endSaleDate,
            lastSessionEndTime: lastSessionEndTime
        });

        // Store sessions on-chain
        for (uint8 i = 0; i < totalSession; i++) {
            sessions[newEventId][i] = Session({
                startSessionTime: _sessions[i].startSessionTime,
                endSessionTime: _sessions[i].endSessionTime
            });
        }

        // INTERACTIONS: Emit events
        emit CreateEvent({
            eventId: newEventId,
            title: title,
            description: description,
            imageUri: imageUri,
            priceAmount: priceAmount,
            commitmentAmount: commitmentAmount,
            totalSession: totalSession,
            startSaleDate: startSaleDate,
            endSaleDate: endSaleDate,
            organizer: msg.sender,
            tag: tags
        });

        // Emit session creation events
        for (uint8 i = 0; i < totalSession; i++) {
            emit CreateSession({
                eventId: newEventId,
                session: i,
                title: string.concat("Session ", Strings.toString(i + 1)),
                startSessionTime: _sessions[i].startSessionTime,
                endSessionTime: _sessions[i].endSessionTime
            });
        }

        return true;
    }

    // TODO: Add internal helper functions if needed

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Gets event data
     * @param _eventId The ID of the event
     * @return Event data stored on-chain
     */
    function getEvent(uint256 _eventId) external view eventExists(_eventId) returns (Event memory) {
        return events[_eventId];
    }

    /**
     * @dev Gets session data
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return Session data stored on-chain
     */
    function getSession(uint256 _eventId, uint8 _sessionIndex) external view eventExists(_eventId) returns (Session memory) {
        return sessions[_eventId][_sessionIndex];
    }

    // TODO: Add more view functions to read contract state
    // function getParticipant(uint256 _eventId, address _participant) external view returns (Participant memory) {}
    // function isParticipantEnrolled(uint256 _eventId, address _participant) external view returns (bool) {}
    // function hasAttended(uint256 _eventId, uint8 _session, address _participant) external view returns (bool) {}

    // ============================================================================
    // PRIVATE FUNCTIONS
    // ============================================================================

    // TODO: Add more private helper functions for complex logic
    // function _validateEventParameters(...) private pure returns (bool) {}
    // function _calculateClaimAmount(...) private view returns (uint256) {}
    // function _isValidAttendanceToken(...) private pure returns (bool) {}
}