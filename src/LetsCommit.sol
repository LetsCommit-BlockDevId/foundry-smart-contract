// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IEventIndexer} from "./IEventIndexer.sol";

contract LetsCommit is IEventIndexer {

    uint256 public eventId = 0;

    uint256 public eventIdClaim = 0;
    uint256 public eventIdEnroll = 0;

    constructor(){

    }

    function emitCreateSession(uint8 i) internal returns (bool)  {

        emit CreateSession({
            eventId: eventId,
            session: i,
            title: string.concat("Session ", "1"),
            startSessionTime: block.timestamp + (1 days * i),
            endSessionTime: block.timestamp + (1 days * i) + (1 hours)
        });

        return true;
    }

    function createEvent() public returns (bool) {

        string[5] memory tags = ['satu', 'dua', '', '', ''];

        uint8 totalSession = 12;

        emit CreateEvent({
            eventId: ++eventId,
            title: "title",
            description: "description",
            imageUri: "imageUri",
            priceAmount: 10_000,
            commitmentAmount: 10_000,
            totalSession: totalSession,
            startSaleDate: block.timestamp,
            endSaleDate: block.timestamp + 7 days,
            organizer: address(0x0),
            tag: tags
        });

        for (uint8 i = 0; i < totalSession; i++) {
            (bool isSuccess) = emitCreateSession(i);
        }

        return true;
    }

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
            attendToken: (abi.encodePacked(block.timestamp, [1]))
        });

        emit OrganizerClaimUnattended({
            eventId: eventIdEnroll,
            session: 1,
            unattendedPerson: 3,
            organizer: address(0x0),
            claimAmount: 1_00
        });

        return true;
    }

}