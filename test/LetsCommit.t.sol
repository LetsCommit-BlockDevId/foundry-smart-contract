// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Import all individual test contracts
import "./LetsCommit.CreateEvent.t.sol";
import "./LetsCommit.Admin.t.sol";
import "./LetsCommit.EnrollEvent.t.sol";
import "./LetsCommit.Views.t.sol";

/**
 * @title LetsCommitTestSuite
 * @dev Main test file that imports all individual test contracts
 * 
 * Test Structure:
 * - LetsCommit.CreateEvent.t.sol: Tests for createEvent function and event creation logic
 * - LetsCommit.Admin.t.sol: Tests for admin functions like setMaxSessionsPerEvent
 * - LetsCommit.EnrollEvent.t.sol: Tests for enrollEvent function and enrollment logic
 * - LetsCommit.Views.t.sol: Tests for all view functions and data retrieval
 * 
 * Run all tests with: forge test
 * Run specific test file with: forge test --match-contract LetsCommitCreateEventTest
 */
