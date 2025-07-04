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

    /// @dev Total protocol TVL from unattended commitment fees (30% of claimed unattended fees)
    uint256 public protocolTVL;

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

    /// @dev Storage for tracking when organizer claimed unattended fees: eventId => sessionIndex => claim timestamp
    mapping(uint256 => mapping(uint8 => uint256)) public sessionUnattendedClaimTimestamp;

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
        uint256 enrolledCount; // Number of participants enrolled in this event
    }

    /// @dev Session data structure for on-chain storage
    struct Session {
        uint256 startSessionTime;
        uint256 endSessionTime;
        uint256 attendedCount; // Number of participants who attended this session
    }

    /// @dev Participant data structure for on-chain storage
    struct Participant {
        uint256 enrolledDate; // Timestamp when participant enrolled in the event
        uint256 commitmentFee; // Current vested commitment fee for this participant in this event (reduces with attendance)
        uint8 attendedSessionsCount; // Number of sessions this participant has attended
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

    /// @dev Error thrown when participant is not enrolled in the event
    error ParticipantNotEnrolled();

    /// @dev Error thrown when session code has not been set by organizer
    error SessionCodeNotSet();

    /// @dev Error thrown when provided session code doesn't match the stored code
    error InvalidSessionCode();

    /// @dev Error thrown when participant has already attended this session
    error ParticipantAlreadyAttended();

    /// @dev Error thrown when session has not ended yet
    error SessionNotEnded();

    /// @dev Error thrown when there are no unattended participants for the session
    error NoUnattendedParticipants();

    /// @dev Error thrown when organizer has already claimed unattended fees for this session
    error UnattendedFeesAlreadyClaimed();

    /// @dev Error thrown when there are no vested commitment fees to claim
    error NoVestedCommitmentFees();

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
        string calldata location,
        string calldata imageUri,
        uint256 priceAmount,
        uint256 commitmentAmount,
        uint8 maxParticipant,
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
            location,
            imageUri,
            priceAmount,
            commitmentAmount,
            maxParticipant,
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

        // Check 6: For events with commitment fees, organizer must have vested amount to release
        // For events with 0 commitment fee, allow setting code without vested amount requirement
        uint256 vestedAmount = organizerVestedAmount[msg.sender][_eventId];
        Event memory eventDataForCommitmentCheck = events[_eventId];

        if (eventDataForCommitmentCheck.commitmentAmount > 0 && eventDataForCommitmentCheck.enrolledCount > 0) {
            // Only check vested amount if event has commitment fees
            if (vestedAmount < releasedAmount) {
                revert NoVestedAmountToRelease();
            }

            // Calculate if there is some dust amount left after releasing, then send the remaining dust on the last claim
            if (vestedAmount > 0 && vestedAmount - releasedAmount < releasedAmount) {
                releasedAmount += (vestedAmount - releasedAmount);
            }
        } else {
            // For events with 0 commitment fee, set released amount to 0
            releasedAmount = 0;
        }

        // All checks passed, proceed with setting session code
        return _setSessionCode(_eventId, _sessionIndex, _code, releasedAmount);
    }

    /**
     * @dev Records attendance for a session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session (0-based)
     * @param _sessionCode The session code set by the organizer
     * @return success True if attendance recording was successful
     */
    function attendSession(uint256 _eventId, uint8 _sessionIndex, string calldata _sessionCode)
        external
        eventExists(_eventId)
        returns (bool success)
    {
        Event memory eventData = events[_eventId];

        // CHECKS: Validate all attendance conditions

        // Check 1: Participant is enrolled in the event
        if (participants[_eventId][msg.sender].enrolledDate == 0) {
            revert ParticipantNotEnrolled();
        }

        // Check 2: Session index is valid
        if (_sessionIndex >= eventData.totalSession) {
            revert InvalidSessionIndex();
        }

        // Check 3: Session code has been set by organizer
        string memory storedCode = sessionCodes[_eventId][_sessionIndex];
        if (bytes(storedCode).length == 0) {
            revert SessionCodeNotSet();
        }

        // Check 4: Provided session code matches the stored code
        if (keccak256(bytes(_sessionCode)) != keccak256(bytes(storedCode))) {
            revert InvalidSessionCode();
        }

        // Check 5: Currently within session time period
        Session memory sessionData = sessions[_eventId][_sessionIndex];
        if (block.timestamp < sessionData.startSessionTime || block.timestamp > sessionData.endSessionTime) {
            revert NotWithinSessionTime();
        }

        // Check 6: Participant has not already attended this session
        if (participants[_eventId][msg.sender].attendance[_sessionIndex] > 0) {
            revert ParticipantAlreadyAttended();
        }

        // All checks passed, proceed with attendance recording
        return _attendSession(_eventId, _sessionIndex);
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
     * @dev not implemented because we transfer the ERC20 token during setSessionCode
     * TODO: Add proper parameters and implementation
     */
    /*
    function claimFinalPortion() external returns (bool success) {
        // TODO: Implement proper claim logic
        emit OrganizerLastClaim({
            eventId: eventIdClaim,
            organizer: address(0x0), // TODO: Use msg.sender
            claimAmount: 10_000 / 2
        });

        return true;
    }
    */

    /**
     * @dev Allows organizer to claim commitment fees from unattended participants
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session (0-based)
     * @return success True if claim was successful
     */
    function claimUnattendedFees(uint256 _eventId, uint8 _sessionIndex)
        external
        eventExists(_eventId)
        returns (bool success)
    {
        Event memory eventData = events[_eventId];

        // CHECKS: Validate all claim conditions

        // Check 1: msg.sender is organizer of that event
        if (msg.sender != eventData.organizer) {
            revert NotEventOrganizer();
        }

        // Check 2: Session index is valid
        if (_sessionIndex >= eventData.totalSession) {
            revert InvalidSessionIndex();
        }

        // Check 3: Session has already ended
        Session memory sessionData = sessions[_eventId][_sessionIndex];
        if (block.timestamp <= sessionData.endSessionTime) {
            revert SessionNotEnded();
        }

        // Check 4: Organizer has set the code for that session
        if (bytes(sessionCodes[_eventId][_sessionIndex]).length == 0) {
            revert SessionCodeNotSet();
        }

        // Check 5: Organizer hasn't already claimed unattended fees for this session
        if (sessionUnattendedClaimTimestamp[_eventId][_sessionIndex] > 0) {
            revert UnattendedFeesAlreadyClaimed();
        }

        // Calculate unattended participants and their commitment fees
        (uint256 unattendedCount, uint256 totalUnattendedCommitmentFees) =
            _calculateUnattendedFeesForSession(_eventId, _sessionIndex);

        // Check 6: There are unattended participants
        if (unattendedCount == 0) {
            revert NoUnattendedParticipants();
        }

        // Check 7: There are vested commitment fees to claim
        if (totalUnattendedCommitmentFees == 0) {
            revert NoVestedCommitmentFees();
        }

        // All checks passed, proceed with claiming unattended fees
        return _claimUnattendedFees(_eventId, _sessionIndex, unattendedCount, totalUnattendedCommitmentFees);
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
        string calldata location,
        string calldata imageUri,
        uint256 priceAmount,
        uint256 commitmentAmount,
        uint8 maxParticipant,
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
            lastSessionEndTime: lastSessionEndTime,
            enrolledCount: 0
        });

        // Store sessions on-chain
        for (uint8 i = 0; i < totalSession; i++) {
            sessions[newEventId][i] = Session({
                startSessionTime: _sessions[i].startSessionTime,
                endSessionTime: _sessions[i].endSessionTime,
                attendedCount: 0
            });
        }

        // INTERACTIONS: Emit events
        emit CreateEvent({
            eventId: newEventId,
            organizer: msg.sender,
            priceAmount: priceAmount,
            commitmentAmount: commitmentAmount,
            totalSession: totalSession,
            maxParticipant: maxParticipant,
            startSaleDate: startSaleDate,
            endSaleDate: endSaleDate
        });

        emit CreateEventMetadata({
            eventId: newEventId,
            title: title,
            description: description,
            location: location,
            imageUri: imageUri,
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

        // Increment enrolled count for this event
        events[_eventId].enrolledCount++;

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

        // Only handle token transfers and storage mutations if there's an amount to release
        if (releasedAmount > 0) {
            // Move vested amount to claimed amount
            organizerVestedAmount[msg.sender][_eventId] -= releasedAmount;
            // Track the claimed amount
            organizerClaimedAmount[msg.sender][_eventId] += releasedAmount;

            // INTERACTIONS: Transfer tokens to organizer
            bool transferSuccess = mIDRXToken.transfer(msg.sender, releasedAmount);
            if (!transferSuccess) {
                revert TokenTransferFailed();
            }
        }

        // Emit event (always emit regardless of releasedAmount)
        emit SetSessionCode({
            eventId: _eventId,
            session: _sessionIndex,
            organizer: msg.sender,
            releasedAmount: releasedAmount
        });
        emit GenerateSessionToken(_eventId, _sessionIndex, _code);

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

    /**
     * @dev Internal function to handle session attendance (EFFECTS & INTERACTIONS phase)
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return success True if attendance was recorded successfully
     */
    function _attendSession(uint256 _eventId, uint8 _sessionIndex) internal returns (bool success) {
        // Get event data to know total sessions
        Event memory eventData = events[_eventId];

        // EFFECTS: Update contract state

        // Record attendance timestamp
        participants[_eventId][msg.sender].attendance[_sessionIndex] = block.timestamp;

        // Increment attended sessions counter for participant
        participants[_eventId][msg.sender].attendedSessionsCount++;

        // Increment attended count for this session
        sessions[_eventId][_sessionIndex].attendedCount++;

        // Calculate attendance reward: event commitment amount divided by total sessions
        // This means each session attendance returns 1/totalSessions of the event's commitment amount
        uint8 tokenDecimals = mIDRXToken.decimals();
        uint256 originalCommitmentFee = eventData.commitmentAmount * (10 ** tokenDecimals);
        uint256 attendanceReward = originalCommitmentFee / eventData.totalSession;

        // Handle any dust/remainder from division
        // If this is the last possible session for this participant, give them any remaining dust
        uint8 totalSessionsAttended = participants[_eventId][msg.sender].attendedSessionsCount;

        // If this is the last session and there's remaining dust, include it
        if (totalSessionsAttended == eventData.totalSession) {
            uint256 remainingDust = originalCommitmentFee - (attendanceReward * (totalSessionsAttended - 1));
            attendanceReward = remainingDust;
        }

        // Ensure we don't try to transfer more than what's available in the current commitment fee
        uint256 currentCommitmentFee = participants[_eventId][msg.sender].commitmentFee;
        if (attendanceReward > currentCommitmentFee) {
            attendanceReward = currentCommitmentFee;
        }

        // Update participant's current commitment fee (reduce by reward amount)
        participants[_eventId][msg.sender].commitmentFee -= attendanceReward;

        // INTERACTIONS: Transfer reward tokens to participant
        bool transferSuccess = mIDRXToken.transfer(msg.sender, attendanceReward);
        if (!transferSuccess) {
            revert TokenTransferFailed();
        }

        // Create attend token for event emission
        bytes memory attendToken = abi.encodePacked(block.timestamp, _sessionIndex);

        // Emit attendance event
        emit AttendEventSession({
            eventId: _eventId,
            session: _sessionIndex,
            participant: msg.sender,
            attendToken: attendToken
        });

        return true;
    }

    /**
     * @dev Internal function to count how many sessions a participant has attended for an event
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @return count The number of sessions attended
     */
    function _countParticipantAttendedSessions(uint256 _eventId, address _participant)
        internal
        view
        returns (uint8 count)
    {
        return participants[_eventId][_participant].attendedSessionsCount;
    }

    /**
     * @dev Internal function to calculate unattended participants and their commitment fees for a session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return unattendedCount The number of unattended participants
     * @return totalUnattendedCommitmentFees The total commitment fees from unattended participants
     */
    function _calculateUnattendedFeesForSession(uint256 _eventId, uint8 _sessionIndex)
        internal
        view
        returns (uint256 unattendedCount, uint256 totalUnattendedCommitmentFees)
    {
        Event memory eventData = events[_eventId];
        Session memory sessionData = sessions[_eventId][_sessionIndex];

        // Calculate unattended participants: enrolled - attended
        uint256 totalEnrolled = eventData.enrolledCount;
        uint256 attendedCount = sessionData.attendedCount;

        // Ensure we don't have negative numbers due to any edge cases
        if (attendedCount > totalEnrolled) {
            unattendedCount = 0;
        } else {
            unattendedCount = totalEnrolled - attendedCount;
        }

        // Calculate total unattended commitment fees
        if (unattendedCount > 0) {
            // Get token decimals for proper calculation
            uint8 tokenDecimals = mIDRXToken.decimals();
            uint256 originalCommitmentFee = eventData.commitmentAmount * (10 ** tokenDecimals);
            uint256 commitmentFeePerSession = originalCommitmentFee / eventData.totalSession;

            // Total fees = unattended count * fee per session
            totalUnattendedCommitmentFees = unattendedCount * commitmentFeePerSession;
        } else {
            totalUnattendedCommitmentFees = 0;
        }

        return (unattendedCount, totalUnattendedCommitmentFees);
    }

    /**
     * @dev Internal function to handle claiming unattended fees (EFFECTS & INTERACTIONS phase)
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @param unattendedCount The number of unattended participants
     * @param totalUnattendedCommitmentFees The total commitment fees from unattended participants
     * @return success True if claim was successful
     */
    function _claimUnattendedFees(
        uint256 _eventId,
        uint8 _sessionIndex,
        uint256 unattendedCount,
        uint256 totalUnattendedCommitmentFees
    ) internal returns (bool success) {
        // EFFECTS: Update contract state

        // Record the claim timestamp
        sessionUnattendedClaimTimestamp[_eventId][_sessionIndex] = block.timestamp;

        // Calculate distribution: 70% to organizer, 30% to protocol
        uint256 organizerShare = (totalUnattendedCommitmentFees * 70) / 100;
        uint256 protocolShare = totalUnattendedCommitmentFees - organizerShare;

        // Update protocol TVL
        protocolTVL += protocolShare;

        // INTERACTIONS: Transfer tokens to organizer
        bool transferSuccess = mIDRXToken.transfer(msg.sender, organizerShare);
        if (!transferSuccess) {
            revert TokenTransferFailed();
        }

        // Emit claim event
        emit OrganizerClaimUnattended({
            eventId: _eventId,
            session: _sessionIndex,
            unattendedPerson: uint8(unattendedCount),
            organizer: msg.sender,
            claimAmount: organizerShare
        });

        return true;
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
     * @dev Gets participant's current commitment fee for an event
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @return commitmentFee The current vested commitment fee amount (reduces with attendance)
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

    /**
     * @dev Checks if a participant has attended a specific session
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @param _sessionIndex The index of the session
     * @return attended True if participant has attended the session
     */
    function hasParticipantAttendedSession(uint256 _eventId, address _participant, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (bool attended)
    {
        return participants[_eventId][_participant].attendance[_sessionIndex] > 0;
    }

    /**
     * @dev Gets the total number of sessions a participant has attended for an event
     * @param _eventId The ID of the event
     * @param _participant The address of the participant
     * @return count The number of sessions attended
     */
    function getParticipantAttendedSessionsCount(uint256 _eventId, address _participant)
        external
        view
        eventExists(_eventId)
        returns (uint8 count)
    {
        return participants[_eventId][_participant].attendedSessionsCount;
    }

    /**
     * @dev Gets the timestamp when organizer claimed unattended fees for a session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return claimTimestamp The timestamp when unattended fees were claimed (0 if not claimed)
     */
    function getSessionUnattendedClaimTimestamp(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (uint256 claimTimestamp)
    {
        return sessionUnattendedClaimTimestamp[_eventId][_sessionIndex];
    }

    /**
     * @dev Checks if organizer has already claimed unattended fees for a session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return claimed True if unattended fees have been claimed
     */
    function hasClaimedUnattendedFees(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (bool claimed)
    {
        return sessionUnattendedClaimTimestamp[_eventId][_sessionIndex] > 0;
    }

    /**
     * @dev Gets the current protocol TVL from unattended commitment fees
     * @return tvl The total value locked in the protocol
     */
    function getProtocolTVL() external view returns (uint256 tvl) {
        return protocolTVL;
    }

    /**
     * @dev Gets the number of enrolled participants for an event
     * @param _eventId The ID of the event
     * @return count The number of enrolled participants
     */
    function getEnrolledParticipantsCount(uint256 _eventId)
        external
        view
        eventExists(_eventId)
        returns (uint256 count)
    {
        return events[_eventId].enrolledCount;
    }

    /**
     * @dev Preview unattended participants and fees for a session (view function)
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return unattendedCount The number of unattended participants
     * @return totalUnattendedCommitmentFees The total commitment fees from unattended participants
     * @return organizerShare The amount organizer would receive (70%)
     * @return protocolShare The amount protocol would receive (30%)
     */
    function previewUnattendedFeesForSession(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (
            uint256 unattendedCount,
            uint256 totalUnattendedCommitmentFees,
            uint256 organizerShare,
            uint256 protocolShare
        )
    {
        (unattendedCount, totalUnattendedCommitmentFees) = _calculateUnattendedFeesForSession(_eventId, _sessionIndex);
        organizerShare = (totalUnattendedCommitmentFees * 70) / 100;
        protocolShare = totalUnattendedCommitmentFees - organizerShare;

        return (unattendedCount, totalUnattendedCommitmentFees, organizerShare, protocolShare);
    }

    /**
     * @dev Gets the number of participants who attended a specific session
     * @param _eventId The ID of the event
     * @param _sessionIndex The index of the session
     * @return attendedCount The number of participants who attended the session
     */
    function getSessionAttendedCount(uint256 _eventId, uint8 _sessionIndex)
        external
        view
        eventExists(_eventId)
        returns (uint256 attendedCount)
    {
        return sessions[_eventId][_sessionIndex].attendedCount;
    }
}
