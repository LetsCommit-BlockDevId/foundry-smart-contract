// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IEventIndexer} from "./IEventIndexer.sol";

/**
 * @title ILetsCommit
 * @dev Interface for the LetsCommit smart contract for managing events with commitment-based participation
 */
interface ILetsCommit is IEventIndexer {
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
    ) external returns (bool success);

    /**
     * @dev Sets the maximum number of sessions per event (admin only)
     * @param newMaxSessions The new maximum number of sessions
     */
    function setMaxSessionsPerEvent(uint8 newMaxSessions) external;

    /**
     * @dev Enrolls a participant in an event
     * @return success True if enrollment was successful
     */
    function enrollEvent() external returns (bool success);

    /**
     * @dev Records attendance for a session
     * @return success True if attendance recording was successful
     */
    function attendSession() external returns (bool success);

    /**
     * @dev Allows organizer to claim first portion of earnings
     * @return success True if claim was successful
     */
    function claimFirstPortion() external returns (bool success);

    /**
     * @dev Allows organizer to claim final portion of earnings
     * @return success True if claim was successful
     */
    function claimFinalPortion() external returns (bool success);

    /**
     * @dev Allows organizer to claim commitment fees from unattended participants
     * @return success True if claim was successful
     */
    function claimUnattendedFees() external returns (bool success);

    /**
     * @dev Gets event data
     * @param _eventId The ID of the event
     * @return Event data stored on-chain
     */
    function getEvent(uint256 _eventId) external view returns (Event memory);

    /**
     * @dev Gets session data
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return Session data stored on-chain
     */
    function getSession(uint256 _eventId, uint8 _sessionIndex) external view returns (Session memory);

    // ============================================================================
    // PUBLIC FUNCTIONS (Legacy - marked for refactoring)
    // ============================================================================

    /**
     * @dev Legacy function - should be refactored into separate functions
     */
    function claim() external returns (bool);

    /**
     * @dev Legacy function - should be refactored into separate functions
     */
    function enrollAndAttend() external returns (bool);

    // ============================================================================
    // STATE VARIABLE GETTERS
    // ============================================================================

    /// @dev Protocol admin getter
    function protocolAdmin() external view returns (address);

    /// @dev Maximum number of sessions allowed per event getter
    function maxSessionsPerEvent() external view returns (uint8);

    /// @dev Counter for event IDs getter
    function eventId() external view returns (uint256);

    /// @dev Counter for claim events getter (temporary)
    function eventIdClaim() external view returns (uint256);

    /// @dev Counter for enrollment events getter (temporary)
    function eventIdEnroll() external view returns (uint256);

    /// @dev Storage for events getter
    function events(uint256) external view returns (
        address organizer,
        uint256 priceAmount,
        uint256 commitmentAmount,
        uint8 totalSession,
        uint256 startSaleDate,
        uint256 endSaleDate,
        uint256 lastSessionEndTime
    );

    /// @dev Storage for sessions getter
    function sessions(uint256, uint8) external view returns (
        uint256 startSessionTime,
        uint256 endSessionTime
    );
}