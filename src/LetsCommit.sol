// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IEventIndexer} from "./interfaces/IEventIndexer.sol";
import {mIDRX} from "./mIDRX.sol"; // Import mIDRX token contract if needed
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

    /// @dev mIDRX ERC20 token contract address
    mIDRX public mIDRXToken;

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

    /// @dev Storage for participants: eventId => participant address => Participant
    mapping(uint256 => mapping(address => Participant)) public participants;

    /// @dev Storage for organizer claimable amounts: organizer => eventId => claimable amount
    mapping(address => mapping(uint256 => uint256)) public organizerClaimableAmount;

    /// @dev Storage for tracking organizer claimed amounts: organizer => eventId => claimed amount
    mapping(address => mapping(uint256 => uint256)) public organizerClaimedAmount;

    /// @dev Storage for organizer vested amounts: organizer => eventId => vested amount
    mapping(address => mapping(uint256 => uint256)) public organizerVestedAmount;

    /// @dev Storage for session codes: eventId => sessionIndex => code (4 characters)
    mapping(uint256 => mapping(uint8 => string)) public sessionCodes;

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

    /// @dev Participant data structure for on-chain storage
    struct Participant {
        uint256 enrolledDate; // Timestamp when participant enrolled in the event
        uint256 commitmentFee; // Vested commitment fee for this participant in this event
        mapping(uint8 => uint256) attendance; // sessionIndex => attendance timestamp (0 if not attended)
    }

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

    /// @dev Error thrown when participant is already enrolled in the event
    error ParticipantAlreadyEnrolled();

    /// @dev Error thrown when event is not in sale period
    error EventNotInSalePeriod();

    /// @dev Error thrown when insufficient allowance for token transfer
    error InsufficientAllowance(uint256 required, uint256 available);

    /// @dev Error thrown when token transfer fails
    error TokenTransferFailed();

    /// @dev Error thrown when user has insufficient token balance
    error InsufficientBalance(uint256 required, uint256 available);

    /// @dev Error thrown when caller is not the organizer of the event
    error NotEventOrganizer();

    /// @dev Error thrown when organizer has no claimable amount for the event
    error NoClaimableAmount();

    /// @dev Error thrown when organizer has already claimed the first portion for this event
    error EventFeeAlreadyClaimed();

    /// @dev Error thrown when session index is invalid
    error InvalidSessionIndex();

    /// @dev Error thrown when not within session time period
    error NotWithinSessionTime();

    /// @dev Error thrown when session code is empty
    error SessionCodeEmpty();

    /// @dev Error thrown when session code is not exactly 4 characters
    error InvalidSessionCodeLength();

    /// @dev Error thrown when session code has already been set
    error SessionCodeAlreadySet();

    /// @dev Error thrown when organizer has no vested amount to release
    error NoVestedAmountToRelease();

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

    constructor(address _mIDRXToken) {
        protocolAdmin = msg.sender;
        mIDRXToken = mIDRX(_mIDRXToken);
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
            title, description, imageUri, priceAmount, commitmentAmount, startSaleDate, endSaleDate, tags, _sessions
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
     * @param _eventId The ID of the event to enroll in
     * @return success True if enrollment was successful
     */
    function enrollEvent(uint256 _eventId) external eventExists(_eventId) returns (bool success) {
        Event memory eventData = events[_eventId];

        // CHECKS: Validate all enrollment conditions

        // Check if participant is already enrolled
        if (participants[_eventId][msg.sender].enrolledDate > 0) {
            revert ParticipantAlreadyEnrolled();
        }

        // Check if event is in sale period
        if (block.timestamp < eventData.startSaleDate || block.timestamp > eventData.endSaleDate) {
            revert EventNotInSalePeriod();
        }

        // Get token decimals for proper calculation
        uint8 tokenDecimals = mIDRXToken.decimals();

        // Calculate total payment required (commitment fee + event fee) with proper decimals
        uint256 commitmentFeeWithDecimals = eventData.commitmentAmount * (10 ** tokenDecimals);
        uint256 eventFeeWithDecimals = eventData.priceAmount * (10 ** tokenDecimals);
        uint256 totalPayment = commitmentFeeWithDecimals + eventFeeWithDecimals;

        // Check if user has approved enough tokens
        uint256 allowance = mIDRXToken.allowance(msg.sender, address(this));
        if (allowance < totalPayment) {
            revert InsufficientAllowance(totalPayment, allowance);
        }

        // Check if user has sufficient balance
        uint256 userBalance = mIDRXToken.balanceOf(msg.sender);
        if (userBalance < totalPayment) {
            revert InsufficientBalance(totalPayment, userBalance);
        }

        // All checks passed, proceed with enrollment
        return _enrollEvent(_eventId, eventData, commitmentFeeWithDecimals, eventFeeWithDecimals, totalPayment);
    }

    /**
     * @dev Set a code to a session so that user can attend the session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session (0-based)
     * @param _code The session code to set (must be exactly 4 characters)
     * @return success True if session code was set successfully
     */
    function setSessionCode(uint256 _eventId, uint8 _sessionIndex, string calldata _code)
        external
        eventExists(_eventId)
        returns (bool success)
    {
        Event memory eventData = events[_eventId];

        // CHECKS: Validate all conditions

        // Check 1: msg.sender is organizer of that event
        if (msg.sender != eventData.organizer) {
            revert NotEventOrganizer();
        }

        // Check 2: Session index is valid
        if (_sessionIndex >= eventData.totalSession) {
            revert InvalidSessionIndex();
        }

        // Check 3: Currently within session time period
        Session memory sessionData = sessions[_eventId][_sessionIndex];
        if (block.timestamp < sessionData.startSessionTime || block.timestamp > sessionData.endSessionTime) {
            revert NotWithinSessionTime();
        }

        // Check 4: Code is exactly 4 characters
        if (bytes(_code).length != 4) {
            revert InvalidSessionCodeLength();
        }

        // Check 5: Session code hasn't been set before (check if string is empty)
        if (bytes(sessionCodes[_eventId][_sessionIndex]).length > 0) {
            revert SessionCodeAlreadySet();
        }

        // Calculate vested amount to release
        uint256 releasedAmount = _calculateVestedAmountPerSession(_eventId);

        // Check 6: Organizer has vested amount to release
        uint256 vestedAmount = organizerVestedAmount[msg.sender][_eventId];
        if (vestedAmount < releasedAmount) {
            revert NoVestedAmountToRelease();
        }

        // Calculate if there is some dust amount left after releasing, then send the remaining dust on the last claim
        if (vestedAmount > 0 && vestedAmount - releasedAmount < releasedAmount) {
            releasedAmount += (vestedAmount - releasedAmount);
        }

        // All checks passed, proceed with setting session code
        return _setSessionCode(_eventId, _sessionIndex, _code, releasedAmount);
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
     * @dev Allows organizer to claim first portion of earnings (50% of event fee).
     * Basically now organizer can claim anytime even during the sale period.
     * @param _eventId The ID of the event to claim earnings from
     * @return success True if claim was successful
     */
    function claimFirstPortion(uint256 _eventId) external eventExists(_eventId) returns (bool success) {
        return _claimOrganizerClaimableEventFee(_eventId);
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
        emit OrganizerFirstClaim({eventId: ++eventIdClaim, organizer: address(0x0), claimAmount: 10_000 / 2});

        emit OrganizerLastClaim({eventId: eventIdClaim, organizer: address(0x0), claimAmount: 10_000 / 2});

        return true;
    }

    /**
     * @dev Legacy function - should be refactored into separate functions
     * TODO: Remove this function and use individual functions above
     */
    function enrollAndAttend() public returns (bool) {
        emit EnrollEvent({eventId: ++eventIdEnroll, participant: address(0x1), debitAmount: 10_000});

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
            sessions[newEventId][i] =
                Session({startSessionTime: _sessions[i].startSessionTime, endSessionTime: _sessions[i].endSessionTime});
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

    /**
     * @dev Internal function to handle enrollment (EFFECTS & INTERACTIONS phase of CEI pattern)
     * @param _eventId The ID of the event
     * @param eventData The event data (passed to avoid re-reading from storage)
     * @param commitmentFeeWithDecimals The commitment fee amount with token decimals
     * @param eventFeeWithDecimals The event fee amount with token decimals
     * @param totalPayment The total payment amount to transfer
     * @return success True if enrollment was successful
     */
    function _enrollEvent(
        uint256 _eventId,
        Event memory eventData,
        uint256 commitmentFeeWithDecimals,
        uint256 eventFeeWithDecimals,
        uint256 totalPayment
    ) internal returns (bool success) {
        // INTERACTIONS: Transfer tokens first (before state changes)
        bool transferSuccess = mIDRXToken.transferFrom(msg.sender, address(this), totalPayment);
        if (!transferSuccess) {
            revert TokenTransferFailed();
        }

        // EFFECTS: Update contract state after successful transfer

        // Store participant's enrollment data
        participants[_eventId][msg.sender].enrolledDate = block.timestamp;
        participants[_eventId][msg.sender].commitmentFee = commitmentFeeWithDecimals;

        // Calculate organizer earnings distribution
        uint256 immediateClaimable = eventFeeWithDecimals / 2; // 50% immediately claimable
        uint256 vestedAmount = eventFeeWithDecimals - immediateClaimable; // Remaining 50% vested

        // Update organizer's claimable and vested amounts for this event
        organizerClaimableAmount[eventData.organizer][_eventId] += immediateClaimable;
        organizerVestedAmount[eventData.organizer][_eventId] += vestedAmount;

        // Emit enrollment event
        emit EnrollEvent({eventId: _eventId, participant: msg.sender, debitAmount: totalPayment});

        return true;
    }

    /**
     * @dev Internal function to handle organizer claiming their claimable event fee (50% of event fee)
     * @param _eventId The ID of the event to claim earnings from
     * @return success True if claim was successful
     */
    function _claimOrganizerClaimableEventFee(uint256 _eventId) internal returns (bool success) {
        Event memory eventData = events[_eventId];

        // CHECKS: Validate all claim conditions

        // Check 1: Event exists (already validated by eventExists modifier)

        // Check 2: msg.sender is organizer of that event id
        if (msg.sender != eventData.organizer) {
            revert NotEventOrganizer();
        }

        // Check 3: That event id's organizer's claimable vault is more than 0
        uint256 claimableAmount = organizerClaimableAmount[msg.sender][_eventId];
        if (claimableAmount == 0) {
            revert NoClaimableAmount();
        }

        // EFFECTS: Update contract state

        // Reset claimable amount to 0 (all tokens will be sent)
        organizerClaimableAmount[msg.sender][_eventId] = 0;

        // Track the claimed amount for this organizer and event because we want to enable multiple claims between the sale period
        organizerClaimedAmount[msg.sender][_eventId] += claimableAmount;

        // INTERACTIONS: Transfer tokens to organizer
        bool transferSuccess = mIDRXToken.transfer(msg.sender, claimableAmount);
        if (!transferSuccess) {
            revert TokenTransferFailed();
        }

        // Emit claim event
        emit OrganizerFirstClaim({eventId: _eventId, organizer: msg.sender, claimAmount: claimableAmount});

        return true;
    }

    /**
     * @dev Internal function to set session code and release vested amount (EFFECTS & INTERACTIONS phase)
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @param _code The session code to set
     * @param releasedAmount The amount to release to organizer
     * @return success True if session code was set successfully
     */
    function _setSessionCode(uint256 _eventId, uint8 _sessionIndex, string calldata _code, uint256 releasedAmount)
        internal
        returns (bool success)
    {
        // EFFECTS: Update contract state

        // Store the session code
        sessionCodes[_eventId][_sessionIndex] = _code;

        // Move vested amount to claimed amount
        organizerVestedAmount[msg.sender][_eventId] -= releasedAmount;
        // Track the claimed amount
        organizerClaimedAmount[msg.sender][_eventId] += releasedAmount;

        // INTERACTIONS: Transfer tokens to organizer
        bool transferSuccess = mIDRXToken.transfer(msg.sender, releasedAmount);
        if (!transferSuccess) {
            revert TokenTransferFailed();
        }

        // Emit event
        emit SetSessionCode({
            eventId: _eventId,
            session: _sessionIndex,
            organizer: msg.sender,
            releasedAmount: releasedAmount
        });

        return true;
    }

    /**
     * @dev Internal function to calculate vested amount per session
     * Formula: (Event Fee / 2) / Total Sessions
     * @param _eventId The ID of the event
     * @return amount The vested amount to release per session
     */
    function _calculateVestedAmountPerSession(uint256 _eventId) internal view returns (uint256 amount) {
        Event memory eventData = events[_eventId];

        // Get token decimals for proper calculation
        uint8 tokenDecimals = mIDRXToken.decimals();

        // Calculate event fee with decimals (50% of total event fee is vested)
        uint256 eventFeeWithDecimals = eventData.priceAmount * (10 ** tokenDecimals);
        uint256 totalVestedAmount = eventFeeWithDecimals / 2; // 50% is vested

        // Divide by total sessions to get amount per session
        return totalVestedAmount / eventData.totalSession;
    }

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
    function getSession(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (Session memory)
    {
        return sessions[_eventId][_sessionIndex];
    }

    /**
     * @dev Checks if a participant is enrolled in an event
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @return enrolled True if participant is enrolled
     */
    function isParticipantEnrolled(uint256 _eventId, address _participant)
        external
        view
        eventExists(_eventId)
        returns (bool enrolled)
    {
        return participants[_eventId][_participant].enrolledDate > 0;
    }

    /**
     * @dev Gets participant's commitment fee for an event
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @return commitmentFee The vested commitment fee amount
     */
    function getParticipantCommitmentFee(uint256 _eventId, address _participant)
        external
        view
        eventExists(_eventId)
        returns (uint256 commitmentFee)
    {
        return participants[_eventId][_participant].commitmentFee;
    }

    /**
     * @dev Gets organizer's claimable amount for an event
     * @param _eventId The ID of the event
     * @param _organizer The address of the organizer
     * @return claimableAmount The immediately claimable amount
     */
    function getOrganizerClaimableAmount(uint256 _eventId, address _organizer)
        external
        view
        eventExists(_eventId)
        returns (uint256 claimableAmount)
    {
        return organizerClaimableAmount[_organizer][_eventId];
    }

    /**
     * @dev Gets organizer's vested amount for an event
     * @param _eventId The ID of the event
     * @param _organizer The address of the organizer
     * @return vestedAmount The vested amount
     */
    function getOrganizerVestedAmount(uint256 _eventId, address _organizer)
        external
        view
        eventExists(_eventId)
        returns (uint256 vestedAmount)
    {
        return organizerVestedAmount[_organizer][_eventId];
    }

    /**
     * @dev Gets participant's attendance timestamp for a specific session
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @param _sessionIndex The index of the session
     * @return attendanceTimestamp The timestamp when participant attended (0 if not attended)
     */
    function getParticipantAttendance(uint256 _eventId, address _participant, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (uint256 attendanceTimestamp)
    {
        return participants[_eventId][_participant].attendance[_sessionIndex];
    }

    /**
     * @dev Checks if organizer has already claimed the first portion for an event
     * @param _eventId The ID of the event
     * @param _organizer The address of the organizer
     * @return claimed more than 0 if organizer has already claimed the first portion
     */
    function getOrganizerClaimedAmount(uint256 _eventId, address _organizer)
        external
        view
        eventExists(_eventId)
        returns (uint256 claimed)
    {
        return organizerClaimedAmount[_organizer][_eventId];
    }

    /**
     * @dev Calculates the vested amount that will be released per session for organizer
     * @param _eventId The ID of the event
     * @return amount The amount that will be released per session for organizer
     */
    function getOrganizerVestedAmountPerSession(uint256 _eventId)
        external
        view
        eventExists(_eventId)
        returns (uint256 amount)
    {
        return _calculateVestedAmountPerSession(_eventId);
    }

    /**
     * @dev Checks if session code has been set for a specific session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return hasCode True if session code has been set
     */
    function hasSessionCode(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (bool hasCode)
    {
        return bytes(sessionCodes[_eventId][_sessionIndex]).length > 0;
    }

    // ============================================================================
    // PRIVATE FUNCTIONS
    // ============================================================================

    // TODO: Add more private helper functions for complex logic
    // function _validateEventParameters(...) private pure returns (bool) {}
    // function _calculateClaimAmount(...) private view returns (uint256) {}
    // function _isValidAttendanceToken(...) private pure returns (bool) {}
}
