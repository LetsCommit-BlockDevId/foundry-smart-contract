// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract IEventSetupTest is Script {


    LetsCommit public c;
    address public mIDRXTokenAddress = makeAddr("mIDRXTokenAddress"); // FIXME: use existing CA or deploy it

    function run() public {

        vm.startBroadcast();

        c = new LetsCommit(mIDRXTokenAddress);


        /// @dev lines below are commented because it causes an error
        /// when running the script, and it seems like only for testing purposes.
        /*
        for (uint i = 0; i < 20; i++) {

            c.createEvent();
            c.claim();
            c.enrollAndAttend();

        }
        */

        vm.stopBroadcast();

    }
}