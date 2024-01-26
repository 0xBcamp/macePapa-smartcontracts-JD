// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {R8R} from "../src/R8R.sol";

contract CounterTest is Test {
    R8R public r8r;
    address public ai = 0x1234567891234567891234567891234567891234; // real AI address is passed to the constructor
    uint256 public gameEntryPriceInEth = 1;

    function setUp() public {
        r8r = new R8R(ai, gameEntryPriceInEth);
    }
}
